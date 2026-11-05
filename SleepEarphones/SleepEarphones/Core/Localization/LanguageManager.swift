//
//  LanguageManager.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import Foundation
import UIKit

/// 语言管理器
///
/// ## 职责
/// 1. 读写当前 App 语言（持久化到 `UserDefaults`）
/// 2. 切换语言后**立即**生效（不需要重启 App）
/// 3. 提供 `applySavedLanguage()` 供 App 启动时调用
///
/// ## 调用方法
/// ```swift
/// // 1. App 启动时（AppDelegate.didFinishLaunchingWithOptions 中）
/// LanguageManager.shared.applySavedLanguage()
///
/// // 2. 读取当前语言
/// let current = LanguageManager.shared.current   // 如 .chinese / .english
///
/// // 3. 取翻译文案（**推荐用全局 `L()` 函数**）
/// let text = L("系统设置")
/// // 或直接调用：
/// let text2 = LanguageManager.shared.localized("系统设置")
///
/// // 4. 运行时切换语言（会自动重建整个 UI）
/// LanguageManager.shared.changeLanguage(to: .english)
/// ```
///
/// ### `.lproj` 目录约定
/// 项目里必须存在以下目录（Xcode 会自动生成）：
/// - `zh-Hans.lproj/Localizable.strings`
/// - `en.lproj/Localizable.strings`
/// - `fr.lproj/Localizable.strings`
/// - `ja.lproj/Localizable.strings`
/// - `de.lproj/Localizable.strings`
///
@MainActor
final class LanguageManager {

    // MARK: - Singleton

    static let shared = LanguageManager()
    private init() {}

    // MARK: - Constants

    /// 存储键：应用内的语言偏好
    private let appLanguageKey = "app.language"

    /// 存储键：Apple 系统的语言偏好
    private let appleLanguagesKey = "AppleLanguages"

    // MARK: - Bundle（运行时语言切换的核心）

    /// 当前使用的语言 Bundle
    private(set) var currentBundle: Bundle = .main

    // MARK: - Current

    /// 当前语言
    ///
    /// - Returns: 当前生效的 `AppLanguage`
    ///
    var current: AppLanguage {
        // 1. 应用内偏好优先
        if let raw = UserDefaults.standard.string(forKey: appLanguageKey),
           let lang = AppLanguage(rawValue: raw) {
            return lang
        }

        // 2. 系统语言（兼容 `en-US` → `en`）
        if let systemCode = Locale.preferredLanguages.first {
            // 完整 code（如 zh-Hans）
            if let lang = AppLanguage(rawValue: systemCode) {
                return lang
            }
            // 前缀（如 en-US → en）
            let prefix = systemCode.components(separatedBy: "-").first ?? ""
            if let lang = AppLanguage(rawValue: prefix) {
                return lang
            }
        }

        // 3. 兜底
        return .default
    }

    // MARK: - Apply（启动时调用）

    /// 应用保存的语言（App 启动时调用）
    ///
    /// ## 流程
    /// 1. 读取偏好（无偏好时用系统语言）
    /// 2. **清理非法值**（旧版本可能写入过已不支持的语言）
    /// 3. 写入 `AppleLanguages`（下次启动生效）
    /// 4. **加载对应 `.lproj` Bundle**（本次启动即可生效）
    ///
    func applySavedLanguage() {
        let language: AppLanguage

        if let saved = UserDefaults.standard.string(forKey: appLanguageKey) {
            if let lang = AppLanguage(rawValue: saved) {
                // 已有合法偏好
                language = lang
            } else {
                // ⚠️ 保存的是非法 rawValue——可能是旧版本支持过、
                //    当前版本已移除的语言（如旧版支持 `es`）。
                //    清理并回退到系统语言 / 默认值，避免每次启动都读到非法值。
                AppLog.app.warning(
                    "检测到非法语言偏好：\(saved, privacy: .public)，回退到系统语言"
                )
                language = current   // `current` 内部会走系统语言 → 默认值的降级链
            }
        } else {
            // 首次启动：用系统语言或默认值
            language = current
        }

        // 回写偏好（确保 `app.language` 与 `language` 一致）
        // 注意：即使已有合法偏好也要写——幂等操作，避免"读取时降级但未回写"的不一致。
        UserDefaults.standard.set(language.rawValue, forKey: appLanguageKey)

        applyToAppleLanguages(language)
        loadBundle(for: language)

        AppLog.app.debug("应用语言：\(language.rawValue, privacy: .public)")
    }

    // MARK: - Change（运行时切换）

    /// 切换语言（用户点击"确定"后调用）
    ///
    /// ## 流程时序（重要，顺序不可调整）
    /// ```
    /// 1. 写入 app.language（偏好持久化）
    /// 2. 写入 AppleLanguages（下次冷启动生效）
    /// 3. 加载 currentBundle（**本次运行立即生效**）
    ///    ↓
    ///    此时 currentBundle 已指向新语言
    ///    ↓
    /// 4. AppRouter.reloadRoot()（重建整个 UI）
    ///    ↓
    ///    reloadRoot 内的所有 L(...) 都读到新语言 ✅
    /// ```
    ///
    /// - Parameter language: 目标语言
    ///
    func changeLanguage(to language: AppLanguage) {
        AppLog.app.debug(
            "切换语言：\(self.current.rawValue, privacy: .public) → \(language.rawValue, privacy: .public)"
        )

        // 1. 写入应用偏好
        UserDefaults.standard.set(language.rawValue, forKey: appLanguageKey)

        // 2. 写入 AppleLanguages（下次冷启动生效）
        applyToAppleLanguages(language)

        // 3. ✅ 关键：重新加载 Bundle（运行时立即生效）
        //    必须在 reloadRoot 之前——保证重建 UI 时 L(...) 读到新语言
        loadBundle(for: language)

        // 4. 重建 UI（所有 L(...) 会立即返回新语言）
        AppRouter.shared.reloadRoot()
    }

    // MARK: - Translate

    /// 取本地化文案
    ///
    /// - Parameter key: 中文 key（也是 `Localizable.strings` 里的 key）
    /// - Returns: 翻译后的文案；找不到时返回 key 自身
    ///
    func localized(_ key: String) -> String {
        currentBundle.localizedString(
            forKey: key,
            value: key,
            table: nil
        )
    }

    // MARK: - Private

    /// 把语言写入 `AppleLanguages` 键
    ///
    /// - Parameter language: 目标语言
    ///
    private func applyToAppleLanguages(_ language: AppLanguage) {
        UserDefaults.standard.set([language.rawValue], forKey: appleLanguagesKey)
    }

    /// 加载指定语言的 `.lproj` Bundle
    /// 
    /// - Parameter language: 目标语言
    private func loadBundle(for language: AppLanguage) {
        guard let path = Bundle.main.path(
            forResource: language.rawValue,
            ofType: "lproj"
        ), let bundle = Bundle(path: path) else {
            // 检测当前 Bundle 是否已是目标语言——避免日志重复打印
            let currentLang = currentBundle.bundlePath
            AppLog.app.error(
                "找不到 \(language.rawValue, privacy: .public).lproj，保持当前 Bundle（\(currentLang, privacy: .public)）"
            )
            #if DEBUG
            assertionFailure(
                "\(language.rawValue).lproj is missing — check Localizable.xcstrings / .strings files"
            )
            #endif
            return
        }
        currentBundle = bundle
    }
}

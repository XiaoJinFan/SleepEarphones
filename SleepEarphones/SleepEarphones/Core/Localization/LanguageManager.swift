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
    ///
    /// - Important: `AppleLanguages` 是 iOS 保留键，不可改名。
    ///              写入后**下次冷启动**时 `Bundle.main` 会使用它。
    private let appleLanguagesKey = "AppleLanguages"

    // MARK: - Bundle（运行时语言切换的核心）

    /// 当前使用的语言 Bundle
    ///
    /// - 启动时从 `UserDefaults` 的偏好初始化
    /// - 切换语言时指向目标 `.lproj`
    /// - **所有 `L()` 调用都应从这里读翻译**（而不是 `Bundle.main`）
    private(set) var currentBundle: Bundle = .main

    // MARK: - Current

    /// 当前语言
    ///
    /// - Returns: 当前生效的 `AppLanguage`
    ///
    /// - Note: 读取优先级：
    ///   1. 应用内偏好（`app.language`，用户手动设置的）
    ///   2. 系统语言（若系统语言在支持列表里）
    ///   3. 默认语言（简体中文）
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
    /// 2. 写入 `AppleLanguages`（下次启动生效）
    /// 3. **加载对应 `.lproj` Bundle**（本次启动即可生效）
    ///
    /// - Important: `loadBundle(for:)` 必须执行——否则 `currentBundle`
    ///              会保持 `.main`，`L()` 读不到用户偏好的翻译。
    func applySavedLanguage() {
        let language: AppLanguage

        if let saved = UserDefaults.standard.string(forKey: appLanguageKey),
           let lang = AppLanguage(rawValue: saved) {
            // 已有偏好
            language = lang
        } else {
            // 首次启动：用系统语言或默认值
            language = current
            UserDefaults.standard.set(language.rawValue, forKey: appLanguageKey)
        }

        applyToAppleLanguages(language)
        loadBundle(for: language)

        AppLog.app.debug("应用语言：\(language.rawValue, privacy: .public)")
    }

    // MARK: - Change（运行时切换）

    /// 切换语言（用户点击"确定"后调用）
    ///
    /// ## 流程
    /// 1. 写入应用偏好
    /// 2. 写入 `AppleLanguages`（保证下次冷启动也用同一语言）
    /// 3. **重新加载 Bundle**（运行时立即生效）
    /// 4. 重建 UI 让所有 `L(...)` 调用重新取值
    ///
    /// - Parameter language: 目标语言
    ///
    /// - Note: 重建 UI 会**丢弃整个导航栈**，用户被带回 tabBar 首页。
    ///         这是预期行为——语言切换是全局性操作。
    func changeLanguage(to language: AppLanguage) {
        AppLog.app.debug(
            "切换语言：\(self.current.rawValue, privacy: .public) → \(language.rawValue, privacy: .public)"
        )

        // 1. 写入应用偏好
        UserDefaults.standard.set(language.rawValue, forKey: appLanguageKey)

        // 2. 写入 AppleLanguages（下次冷启动生效）
        applyToAppleLanguages(language)

        // 3. ✅ 关键：重新加载 Bundle（运行时立即生效）
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
    /// - Note: 从 `currentBundle` 读取，而非 `Bundle.main`——
    ///         这是运行时语言切换能立即生效的关键。
    ///
    /// - Important: **推荐全局使用 `L()` 函数**，而非直接调用本方法，
    ///              这样可以统一处理格式化参数。
    func localized(_ key: String) -> String {
        currentBundle.localizedString(forKey: key, value: key, table: nil)
    }

    // MARK: - Private

    /// 把语言写入 `AppleLanguages` 键
    ///
    /// - Parameter language: 目标语言
    ///
    /// - Note: 不调用已废弃的 `synchronize()`——
    ///         iOS 12+ 起 `UserDefaults` 会自动持久化。
    private func applyToAppleLanguages(_ language: AppLanguage) {
        UserDefaults.standard.set([language.rawValue], forKey: appleLanguagesKey)
    }

    /// 加载指定语言的 `.lproj` Bundle
    ///
    /// ## 实现
    /// 1. 从 `Bundle.main` 里找目标语言的 `.lproj` 路径
    /// 2. 用该路径构造一个新的 `Bundle` 实例
    /// 3. 赋值给 `currentBundle`
    ///
    /// ## 失败兜底
    /// 若 `.lproj` 不存在（比如语言资源未添加），保持 `currentBundle` 不变，
    /// 输出 error 日志便于定位。**不 crash**——App 仍可用默认语言。
    ///
    /// - Parameter language: 目标语言
    private func loadBundle(for language: AppLanguage) {
        guard let path = Bundle.main.path(
            forResource: language.rawValue,
            ofType: "lproj"
        ), let bundle = Bundle(path: path) else {
            AppLog.app.error(
                "找不到 \(language.rawValue, privacy: .public).lproj，保持当前 Bundle"
            )
            return
        }
        currentBundle = bundle
    }
}

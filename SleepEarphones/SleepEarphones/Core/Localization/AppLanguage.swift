//
//  AppLanguage.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import Foundation

/// 应用支持的语言
///
/// ## 调用方法
/// ```swift
/// // 1. 读取当前语言
/// let current = LanguageManager.shared.current
///
/// // 2. 遍历所有支持的语言（用于语言设置页）
/// AppLanguage.allCases.forEach { lang in
///     print(lang.displayName)   // "简体中文" / "English" / ...
/// }
///
/// // 3. 切换语言
/// LanguageManager.shared.changeLanguage(to: .english)
///
/// // 4. 从 rawValue 构造（如从 UserDefaults 读回）
/// let lang = AppLanguage(rawValue: "zh-Hans")
/// ```
///
/// ## 三方同步约束（重要，最容易出错）
/// `rawValue` 必须**同时**与以下三处保持一致，否则语言切换会失效：
///
/// | 位置 | 示例 |
/// |---|---|
/// | `rawValue`（本枚举） | `"zh-Hans"` |
/// | `.lproj` 目录名 | `zh-Hans.lproj/Localizable.strings` |
/// | `Info.plist` → `CFBundleLocalizations` | `["zh-Hans", "en", "fr", "ja", "de"]` |
///
/// **检查清单**（新增语言时）：
/// 1. 在本枚举增加 case（`rawValue` = ISO 639-1 / BCP 47 code）
/// 2. 在 Xcode 中创建对应 `.lproj/Localizable.strings`（Xcode 自动加入 build）
/// 3. 在 `Info.plist` 的 `CFBundleLocalizations` 中追加同值
/// 4. 在 `Info.plist` 的 `CFBundleDevelopmentRegion` 中保持默认语言（`zh-Hans`）
///
/// ## 与系统语言的对应
/// | rawValue | 显示名 | 说明 |
/// |---|---|---|
/// | `zh-Hans` | 简体中文 | 默认语言 |
/// | `en` | English | |
/// | `fr` | Français | |
/// | `ja` | 日本語 | |
/// | `de` | Deutsch | |
enum AppLanguage: String, CaseIterable {

    // MARK: - Cases

    /// 简体中文（默认）
    case chinese = "zh-Hans"

    /// 英语
    case english = "en"

    /// 法语
    case french = "fr"

    /// 日语
    case japanese = "ja"

    /// 德语
    case german = "de"

    // MARK: - Display

    /// 语言显示名（**用该语言自身**显示）
    ///
    /// - Returns: 该语言的原生写法（如 `"简体中文"` / `"English"`）
    ///
    var displayName: String {
        switch self {
        case .chinese:  return "简体中文"
        case .english:  return "English"
        case .french:   return "Français"
        case .japanese: return "日本語"
        case .german:   return "Deutsch"
        }
    }

    // MARK: - RTL

    /// 是否为从右到左（RTL）书写的语言
    ///
    /// - Returns: 当前支持的语言均非 RTL，始终返回 `false`
    ///
    var isRTL: Bool {
        // 当前支持的语言（zh-Hans / en / fr / ja / de）全部是 LTR
        switch self {
        case .chinese, .english, .french, .japanese, .german:
            return false
        }
    }

    // MARK: - Default

    /// 默认语言（简体中文）
    static let `default`: AppLanguage = .chinese
}

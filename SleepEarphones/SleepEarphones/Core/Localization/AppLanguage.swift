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
/// ## 与系统语言的对应
/// `rawValue` 必须与 `Localizable.strings` 目录名 / `Info.plist` 里
/// `CFBundleLocalizations` 保持一致，否则 `NSLocalizedString` 找不到资源。
///
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
    /// - Note: 无论当前 App 是什么语言，都用**该语言的原生写法**展示。
    ///         这是国际惯例——用户即使看不懂当前界面语言，
    ///         也能凭母语文字找到自己的语言。
    var displayName: String {
        switch self {
        case .chinese:  return "简体中文"
        case .english:  return "English"
        case .french:   return "Français"
        case .japanese: return "日本語"
        case .german:   return "Deutsch"
        }
    }

    // MARK: - Default

    /// 默认语言（简体中文）
    static let `default`: AppLanguage = .chinese
}

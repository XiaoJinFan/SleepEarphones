//
//  String+Localized.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import Foundation

/// 本地化便捷方法（**`@MainActor`**，供 UI 层使用）
///
/// ## 调用方法
/// ```swift
/// // 1. 无参数
/// label.text = L("系统设置")
///
/// // 2. 带格式化参数
/// label.text = L("服务器错误 (%lld)", statusCode)
/// label.text = L("欢迎，%@", userName)
///
/// // 3. 在任意 UI 组件中使用
/// title = L("我的资料")
/// button.setTitle(L("登录"), for: .normal)
/// ```
///
/// - Parameters:
///   - key: 中文 key（也是 `Localizable.strings` 里的 key）
///   - args: 格式化参数（可选）
/// - Returns: 翻译后的文案；找不到时返回 key 自身
@MainActor
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = LanguageManager.shared.localized(key)

    // 无参数时直接返回——避免 `String(format:)` 对文案中的 `%` 做意外解析
    // （如文案本身含 "100%" 会被视为无效格式符）
    guard !args.isEmpty else { return format }

    return String(format: format, arguments: args)
}

// MARK: - Nonisolated Localization

/// 本地化便捷方法（**`nonisolated`**，供任意线程使用）
///
/// ## 为什么需要 `LN(_:)`？
/// `L(_:)` 是 `@MainActor` 的——以下场景**无法调用**：
/// - `LocalizedError.errorDescription`（协议要求 `nonisolated`）
/// - `APIConfiguration.serverErrorMessage`
/// - `AccountInputValidator.FailureReason.message`
/// - `Decodable.init(from:)` 中的兜底文案
/// - 后台任务 / 网络回调
/// - **`nonisolated` 的 `UIViewController` 扩展方法**
///
/// ## 语言来源（**重要修复**）
/// 优先级：
/// 1. `app.language`（`LanguageManager` 写入的 App 内偏好，**运行时立即生效**）
/// 2. `AppleLanguages` 数组首项（系统语言，仅冷启动生效）
/// 3. `zh-Hans`（兜底）
///
/// - Important: **原实现用 `UserDefaults.string(forKey: "AppleLanguages")`
///   读取数组值——会返回 `nil`，导致永远 fallback 到 `zh-Hans`。**
///   必须用 `stringArray(forKey:)`。
///
/// - Parameter key: 中文 key
/// - Returns: 当前语言下的翻译；失败时返回 `key`
func LN(_ key: String) -> String {
    // 1. 解析当前语言（优先级：App 内偏好 → 系统语言 → 兜底）
    let preferred: String
    if let stored = UserDefaults.standard.string(forKey: "app.language"),
       AppLanguage(rawValue: stored) != nil {
        // ✅ 优先：LanguageManager 写入的 App 内偏好
        preferred = stored
    } else if let array = UserDefaults.standard.stringArray(forKey: "AppleLanguages"),
              let first = array.first,
              AppLanguage(rawValue: first) != nil {
        // ✅ 修复：用 stringArray 读数组
        preferred = first
    } else {
        preferred = "zh-Hans"
    }

    // 2. 找 lproj
    guard let path = Bundle.main.path(forResource: preferred, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        AppLog.cache.error("LN 找不到 \(preferred, privacy: .public).lproj")
        return key
    }

    // 3. 读翻译
    let translated = bundle.localizedString(forKey: key, value: key, table: nil)
    return translated.isEmpty ? key : translated
}

// ============================================================
// MARK: - 格式化参数陷阱清单（重要）
// ============================================================
//
// ## 1. 格式符与参数类型必须严格匹配
//
// | 格式符 | 期望类型 | 错误示例 |
// |---|---|---|
// | `%@` | `CVarArg`（String / NSNumber 等） | `L("欢迎 %@", 123)` — Int 不是 `%@` 的正确类型 |
// | `%lld` | `Int64` / `Int`（在 64 位平台等价） | `L("错误 %lld", 401)` — ✅ 正确 |
// | `%d` | `Int32` | `L("错误 %d", statusCode)` — 若 statusCode 是 `Int` 会截断 |
// | `%f` | `Double` / `Float` | `L("进度 %.1f", 0.5)` — ✅ 正确 |
// | `%%` | 无（输出 `%`） | `L("100%%")` — 输出 `"100%"` |
//
// ## 2. `%` 在文案中的转义
//
// 若文案本身含 `%`（如 "100%"），且**有参数**时，必须写成 `%%`：
// - ❌ `L("完成 100% (%lld 项)", count)` — `%` 会被当格式符解析，崩溃或输出错乱
// - ✅ `L("完成 100%% (%lld 项)", count)`
//
// 若无参数，`L` 内部有 `args.isEmpty` 短路，`%` 不会被解析——但**建议统一用 `%%`**
// 以避免后续加参数时遗漏。
//
// ## 3. 类型自动桥接
//
// `String(format:arguments:)` 的 `CVarArg` 协议自动桥接以下类型：
// - `Int` / `Int8` / `Int16` / `Int32` / `Int64`
// - `UInt` / `UInt8` / `UInt16` / `UInt32` / `UInt64`
// - `Float` / `Double` / `CGFloat`
// - `String` / `NSString` / `NSNumber`
// - `Bool`（桥接为 `Int`，`true` → `1`）
//
// 其他类型（如 `Date` / `URL` / 自定义 `Codable`）**不自动桥接**——
// 需先 `String(describing:)` 或 `.description` 转成 `String`。
//
// ## 4. 翻译文案中的格式符必须与原文一致
//
// 若原文是 `L("服务器错误 (%lld)", statusCode)`，
// `Localizable.strings` 中 `"服务器错误 (%lld)"` 对应的德语翻译
// 必须是 `"Serverfehler (%lld)"`（保留 `%lld`）——
// 若译错为 `"Serverfehler (%d)"`，在 `Int64` 平台上会截断状态码。
//
// 这是**最容易漏的本地化 bug**——建议翻译时对含格式符的 key 特殊标注。
//
// ============================================================

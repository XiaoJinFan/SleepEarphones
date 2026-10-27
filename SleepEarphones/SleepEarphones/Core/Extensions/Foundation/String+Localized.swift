//
//  String+Localized.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import Foundation

/// 本地化便捷方法
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
    guard !args.isEmpty else { return format }
    return String(format: format, arguments: args)
}

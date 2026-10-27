//
//  NetworkLogger.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/23.
//

import Foundation
import Alamofire

/// 网络请求 / 响应日志工具
///
/// ## 调用方法
/// ```swift
/// // 1. 记录请求发起
/// NetworkLogger.logRequest(api: api, requestID: "abc123", urlString: url)
///
/// // 2. 记录响应收到
/// NetworkLogger.logResponse(
///     requestID: "abc123",
///     statusCode: 200,
///     duration: 0.35,
///     result: .success(model)
/// )
/// ```
///
enum NetworkLogger {

    // MARK: - Limits

    /// 单行日志最大长度
    ///
    /// - Note: 超过后截断并加 `…(共 N 字符)`。
    ///         Xcode Console 对超长行有卡顿，OSLog 对单条日志也有体积限制。
    private static let maxLineLength = 500

    /// 响应数据最多打印的行数
    private static let maxDataLines = 50

    // MARK: - 脱敏字段

    /// 需要完全脱敏的参数字段名（**大小写不敏感**）
    ///
    /// - Note: 只要 key **包含**以下任一子串，就完全脱敏为 `***`。
    private static let maskedKeySubstrings = [
        "password",
        "token",
        "secret",
        "authorization",
        "credential"
    ]

    /// 需要**部分脱敏**的参数字段名（保留前 3 后 4）
    private static let partialMaskedKeySubstrings = [
        "mobile",
        "phone"
    ]

    // MARK: - 请求日志

    /// 格式化并输出"请求发起"日志
    ///
    /// - Parameters:
    ///   - api: 请求实例
    ///   - requestID: 请求 ID（用于关联请求 / 响应）
    ///   - urlString: 完整 URL（已由调用方格式化）
    static func logRequest(api: APIRequest, requestID: String, urlString: String) {
        // 1. 基本信息
        let method = api.method.rawValue
        var lines: [String] = [
            "┌─ 📤 REQUEST [\(requestID)]",
            "│ \(method) \(urlString)"
        ]

        // 2. 参数（脱敏）
        if let params = api.parameters, !params.isEmpty {
            lines.append("│ Parameters:")
            lines.append(contentsOf: formatParameters(params))
        } else {
            lines.append("│ Parameters: (empty)")
        }

        // 3. 请求头（仅打印非空的自定义头）
        if let headers = api.headers, !headers.isEmpty {
            lines.append("│ Headers:")
            for (key, value) in headers.dictionary {
                let displayValue = isSensitiveKey(key) ? "***" : value
                lines.append("│   \(key): \(displayValue)")
            }
        }

        lines.append("└─────────────────────────────")

        AppLog.network.debug("\(lines.joined(separator: "\n"), privacy: .public)")
    }

    // MARK: - 响应日志

    /// 格式化并输出"响应收到"日志
    ///
    /// - Parameters:
    ///   - requestID: 请求 ID
    ///   - statusCode: HTTP 状态码（若可用）
    ///   - duration: 请求耗时（秒）
    ///   - result: 解析结果（成功 / 失败）
    static func logResponse<T>(requestID: String, statusCode: Int?, duration: TimeInterval, result: Result<T, NetworkError>) {
        var lines: [String] = [
            "┌─ 📥 RESPONSE [\(requestID)]"
        ]

        // 1. 状态码 + 耗时
        let statusText = statusCode.map { "\($0)" } ?? "?"
        let durationText = String(format: "%.2fs", duration)
        lines.append("│ Status: \(statusText) (\(durationText))")

        // 2. 结果
        switch result {
        case .success(let data):
            lines.append("│ Result: ✅ SUCCESS")
            #if DEBUG
            lines.append("│ Data:")
            let dataLines = formatResponseData(data)
            lines.append(contentsOf: dataLines)
            #else
            lines.append("│ Data: <省略（Release 不打）>")
            #endif

        case .failure(let error):
            lines.append("│ Result: ❌ \(error.logCode)")
            lines.append("│ Message: \(error.errorDescription ?? "unknown")")
        }

        lines.append("└─────────────────────────────")

        // 失败用 error 级别，成功用 debug
        switch result {
        case .success:
            AppLog.network.debug("\(lines.joined(separator: "\n"), privacy: .public)")
        case .failure:
            AppLog.network.error("\(lines.joined(separator: "\n"), privacy: .public)")
        }
    }

    // MARK: - Private Helpers

    /// 格式化参数（脱敏 + 稳定排序 + 截断）
    ///
    /// - Parameter params: 原始参数字典
    /// - Returns: 格式化后的行数组
    private static func formatParameters(_ params: [String: Any]) -> [String] {
        params
            .sorted { $0.key < $1.key }   // 排序，输出稳定
            .prefix(maxDataLines)          // 参数过多也截断
            .map { key, value in
                truncateLine("│   \(key): \(formatValue(key: key, value: value))")
            }
    }

    /// 格式化单个参数值
    ///
    /// - Parameters:
    ///   - key: 参数名（用于判定是否脱敏）
    ///   - value: 参数值
    /// - Returns: 格式化后的字符串
    ///
    /// - Note:
    ///   - 完全脱敏：`password` / `token` 等 → `***`
    ///   - 部分脱敏：`mobile` / `phone` → `183****1021`
    ///   - 其他：原样（集合 / 字典递归）
    private static func formatValue(key: String, value: Any) -> String {
        // 1. 完全脱敏
        if isSensitiveKey(key) {
            return "***"
        }

        // 2. 部分脱敏（手机号）
        if isPartialMaskedKey(key), let string = value as? String, !string.isEmpty {
            return maskMobile(string)
        }

        // 3. 集合 / 字典：递归
        if let dict = value as? [String: Any] {
            let inner = dict
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \(formatValue(key: $0.key, value: $0.value))" }
                .joined(separator: ", ")
            return "{\(inner)}"
        }
        if let array = value as? [Any] {
            let inner = array
                .map { formatValue(key: key, value: $0) }
                .joined(separator: ", ")
            return "[\(inner)]"
        }

        // 4. 默认
        return "\(value)"
    }

    /// 判断是否是需要完全脱敏的 key
    ///
    /// - Parameter key: 参数名
    /// - Returns: 是否需要完全脱敏
    private static func isSensitiveKey(_ key: String) -> Bool {
        let lower = key.lowercased()
        return maskedKeySubstrings.contains { lower.contains($0) }
    }

    /// 判断是否是需要部分脱敏的 key
    ///
    /// - Parameter key: 参数名
    /// - Returns: 是否需要部分脱敏
    private static func isPartialMaskedKey(_ key: String) -> Bool {
        let lower = key.lowercased()
        return partialMaskedKeySubstrings.contains { lower.contains($0) }
    }

    /// 手机号脱敏（保留前 3 后 4）
    ///
    /// - Parameter mobile: 手机号字符串
    /// - Returns: 脱敏后的字符串
    ///
    /// - Note: 长度不足 7 位时返回 `***`，避免暴露完整内容。
    private static func maskMobile(_ mobile: String) -> String {
        guard mobile.count >= 7 else { return "***" }
        let prefix = mobile.prefix(3)
        let suffix = mobile.suffix(4)
        return "\(prefix)****\(suffix)"
    }

    /// 格式化响应数据
    ///
    /// - Parameter data: 解码后的响应数据
    /// - Returns: 格式化后的行数组
    ///
    /// - Note: `Decodable` 类型没有通用的"转字典"方法，
    ///         因此用 `Mirror` 反射遍历属性（DEBUG 用，性能可忽略）。
    ///         加了 `maxDataLines` 行数上限和单行 `truncateLine` 截断，
    ///         避免后端返回大数组时刷屏。
    private static func formatResponseData<T>(_ data: T) -> [String] {
        // 1. 简单类型：直接打
        if let string = data as? String {
            return [truncateLine("│   \"\(string)\"")]
        }
        if let array = data as? [Any] {
            if array.isEmpty {
                return ["│   [] (空数组)"]
            }
            let preview = array.prefix(maxDataLines).map { "\($0)" }.joined(separator: ", ")
            let suffix = array.count > maxDataLines
                ? "…(共 \(array.count) 项，仅显示前 \(maxDataLines) 项)"
                : ""
            return [truncateLine("│   [\(array.count) 项] \(preview)\(suffix)")]
        }

        // 2. 复杂类型：用 Mirror 反射
        let mirror = Mirror(reflecting: data)
        guard !mirror.children.isEmpty else {
            return [truncateLine("│   \(data)")]
        }

        // 限制反射行数
        return mirror.children
            .prefix(maxDataLines)
            .compactMap { child in
                guard let label = child.label else { return nil }
                return truncateLine("│   \(label): \(child.value)")
            }
    }

    /// 单行长度截断
    ///
    /// - Parameter line: 原始行
    /// - Returns: 超过 `maxLineLength` 时截断并加后缀
    private static func truncateLine(_ line: String) -> String {
        guard line.count > maxLineLength else { return line }
        let prefix = line.prefix(maxLineLength)
        return "\(prefix)…(共 \(line.count) 字符)"
    }
}

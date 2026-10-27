//
//  NetworkError.swift
//  Network
//
//  Created by 肖进凡 on 2026/9/11.
//

import Foundation

/// 网络层统一错误
///
/// ## 调用方法
/// ```swift
/// // 1. 在订阅中处理
/// .sink(receiveCompletion: { completion in
///     if case .failure(let error) = completion {
///         showAlert(error.errorDescription ?? "未知错误")
///         if error.isRetryable { scheduleRetry() }
///     }
/// })
///
/// // 2. 日志 / 埋点用短标识符
/// AppLog.network.error("失败：\(error.logCode, privacy: .public)")
///
/// // 3. 单测断言（只比较 case，忽略关联值）
/// XCTAssertEqual(receivedError, .timeout)
/// ```
/// 
public enum NetworkError: LocalizedError, @unchecked Sendable {

    // MARK: - Cases

    /// URL 构造失败（几乎不会发生，仅作兜底）
    case invalidURL

    /// 请求超时
    case timeout

    /// 无网络连接
    case noConnection

    /// 服务端返回的业务错误（HTTP 200 但 `code != 成功码`）
    case server(code: Int, message: String)

    /// HTTP 状态码错误（非 2xx）
    case httpError(statusCode: Int)

    /// `data` 字段为空（字段缺失 / null）
    ///
    /// - Note: 与 `.decoding` 区分——「数据为空」是正常的业务场景
    ///         （如列表接口无数据），而 `.decoding` 是真正的解析 bug。
    case emptyData

    /// 数据解码失败（`data` 字段存在但类型不匹配）
    case decoding(Error)

    /// 请求被取消（用户主动取消 / 页面销毁）
    case cancelled

    /// Token 失效 / 未登录
    case tokenExpired

    /// 其他底层错误（未分类的 Alamofire / URLError）
    case underlying(Error)

    // MARK: - LocalizedError

    /// 面向用户的中文错误描述
    ///
    /// - Returns: 可直接展示给用户的错误文案
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的请求地址"
        case .timeout:
            return "请求超时，请检查网络后重试"
        case .noConnection:
            return "网络连接已断开，请检查网络设置"
        case .server(_, let message):
            return message.isEmpty ? APIConfiguration.serverErrorMessage : message
        case .httpError(let statusCode):
            return "服务器错误 (\(statusCode))"
        case .emptyData:
            return "暂无数据"
        case .decoding:
            return "数据解析失败"
        case .cancelled:
            return "请求已取消"
        case .tokenExpired:
            return "登录已过期，请重新登录"
        case .underlying(let error):
            return error.localizedDescription
        }
    }

    // MARK: - Retry

    /// 是否可重试
    ///
    /// - 超时 / 无网络 / 5xx 服务端错误 / 429 限流：可重试
    /// - 业务失败 / 解码失败 / Token 失效：不可重试（重试也不会成功）
    /// - 用户取消：不可重试（是用户意图）
    public var isRetryable: Bool {
        switch self {
        case .timeout, .noConnection:
            return true
        case .httpError(let statusCode):
            return (500...599).contains(statusCode) || statusCode == 429
        case .invalidURL, .server, .emptyData, .decoding, .cancelled, .tokenExpired, .underlying:
            return false
        }
    }

    // MARK: - Logging

    /// 短标识符，用于日志 / 埋点
    ///
    /// - Returns: 简短字符串（如 `"timeout"` / `"server_401"`）
    ///
    /// - Note: 避免直接 `String(describing: error)` 打印整个 enum
    ///         （包含关联值时可能包含大量敏感信息）。
    public var logCode: String {
        switch self {
        case .invalidURL:                 return "invalid_url"
        case .timeout:                    return "timeout"
        case .noConnection:               return "no_connection"
        case .server(let code, _):        return "server_\(code)"
        case .httpError(let statusCode):  return "http_\(statusCode)"
        case .emptyData:                  return "empty_data"
        case .decoding:                   return "decoding"
        case .cancelled:                  return "cancelled"
        case .tokenExpired:               return "token_expired"
        case .underlying:                 return "underlying"
        }
    }
}

// MARK: - Equatable

/// 只比较 `case` 类型，忽略关联值中的 `Error` 内容
///
/// - Note: 用于单元测试里 `XCTAssertEqual` 直接比较 `NetworkError`。
extension NetworkError: Equatable {

    /// 比较两个错误是否相等
    ///
    /// - Parameters:
    ///   - lhs: 左值
    ///   - rhs: 右值
    /// - Returns: 是否相等
    /// 
    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.timeout, .timeout),
             (.noConnection, .noConnection),
             (.emptyData, .emptyData),
             (.cancelled, .cancelled),
             (.tokenExpired, .tokenExpired):
            return true

        case let (.server(lCode, lMsg), .server(rCode, rMsg)):
            return lCode == rCode && lMsg == rMsg

        case let (.httpError(lCode), .httpError(rCode)):
            return lCode == rCode

        case (.decoding, .decoding), (.underlying, .underlying):
            // 只比较 case，不比较具体 Error 内容
            return true

        default:
            return false
        }
    }
}

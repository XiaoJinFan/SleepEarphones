//
//  APIRequest.swift
//  Network
//
//  Created by 肖进凡 on 2026/9/11.
//

import Foundation
import Alamofire

/// 网络请求协议
///
/// ## 调用方法
/// ```swift
/// // 1. 定义接口
/// struct LoginAPI: APIRequest {
///     var path: String { APIEndpoint.login.rawValue }
///     var method: HTTPMethod { .post }
///     var parameters: [String: Any]? { ["mobile": "138...", "code": "1234"] }
///     var encoding: ParameterEncoding { JSONEncoding.default }
/// }
///
/// // 2. 调用（由 NetworkClient 内部自动调用 asURLRequest()）
/// client.request(LoginAPI(), as: LoginResult.self)
/// ```
///
public protocol APIRequest: URLRequestConvertible, Sendable {

    /// 基础 URL，默认走 `APIConfiguration.serverPrefix`
    var baseURL: String { get }

    /// 相对路径（如 `"5c78dbfd977cf"`）
    var path: String { get }

    /// HTTP 方法
    var method: HTTPMethod { get }

    /// 请求参数
    var parameters: [String: Any]? { get }

    /// 参数编码方式
    var encoding: ParameterEncoding { get }

    /// 请求头
    var headers: HTTPHeaders? { get }

    /// 超时时间（秒）
    var timeoutInterval: TimeInterval { get }
}

// MARK: - 默认实现

public extension APIRequest {

    /// 默认使用业务服务前缀：`https://admin.xing-man.com/api/m12323`
    var baseURL: String { APIConfiguration.serverPrefix }

    /// 默认 GET 请求
    var method: HTTPMethod { .get }

    /// 默认无参数
    var parameters: [String: Any]? { nil }

    /// 默认 query 编码（GET 友好）
    var encoding: ParameterEncoding { URLEncoding.default }

    /// 默认无自定义请求头
    var headers: HTTPHeaders? { nil }

    /// 默认 15 秒超时
    var timeoutInterval: TimeInterval { APIConfiguration.defaultTimeout }

    /// 完整 URL（**调试 / 日志用**）
    var urlString: String {
        URLBuilder.build(base: baseURL, path: path)?.absoluteString
            ?? "\(baseURL)/\(path)"
    }

    /// 合成 `URLRequest`
    ///
    /// - Returns: 完整的 URLRequest
    /// - Throws: `NetworkError.invalidURL`（当 base + path 无法构造合法 URL 时）
    ///
    func asURLRequest() throws -> URLRequest {
        guard let url = URLBuilder.build(base: baseURL, path: path) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeoutInterval

        // ✅ 正确合并：保留 URLSession 默认 header，追加自定义 header
        if let headers {
            var mergedHeaders = request.headers
            for header in headers {
                mergedHeaders.add(header)
            }
            request.headers = mergedHeaders
        }

        // 使用指定的编码方式对参数进行编码
        return try encoding.encode(request, with: parameters)
    }
}

// MARK: - URL 拼接工具

/// URL 拼接工具
///
/// - Note: 从 `private` 改为 `internal`，
///         让 `APIEndpoint` 也能复用同一份斜杠规范化逻辑，
///         避免两处各写一遍导致行为不一致。
enum URLBuilder {

    /// 安全拼接 `base + path`
    ///
    /// - Parameters:
    ///   - base: 基础 URL（如 `https://admin.xing-man.com/api/m12323`）
    ///   - path: 相对路径（如 `5c78dbfd977cf`，可带或不带前导 `/`）
    /// - Returns: 合法 `URL`；无法构造时返回 `nil`
    ///
    static func build(base: String, path: String) -> URL? {
        // 规范化：base 去尾斜杠，path 补前斜杠
        let trimmedBase = base.hasSuffix("/") ? String(base.dropLast()) : base
        let trimmedPath = path.hasPrefix("/") ? path : "/" + path

        // iOS 17+：一行搞定，自动编码
        if #available(iOS 17.0, *) {
            guard let components = URLComponents(
                string: trimmedBase + trimmedPath,
                encodingInvalidCharacters: true
            ), let url = components.url else {
                return nil
            }
            return url
        }

        // iOS 17 以下：手动对 path 做 percent-encode
        //
        // - Note: `urlPathAllowed` 不含 `%`，若 path 已编码会被二次编码。
        //         本项目 path 为 hash / 英文，不受影响。
        let encodedPath = trimmedPath.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? trimmedPath

        guard let components = URLComponents(string: trimmedBase + encodedPath),
              let url = components.url else {
            return nil
        }
        return url
    }
}

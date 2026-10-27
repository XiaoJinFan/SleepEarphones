//
//  NetworkClient.swift
//  Network
//
//  Created by 肖进凡 on 2026/9/11.
//

import Foundation
import Combine
import Alamofire

/// 网络客户端协议，便于在 ViewModel 中进行 Mock 测试
public protocol NetworkClientProtocol: Sendable {
    /// 发起网络请求
    ///
    /// - Parameters:
    ///   - api: 请求实例（遵循 `APIRequest`）
    ///   - type: 期望解码的目标类型
    /// - Returns: 解析后的 Publisher
    func request<T: Decodable & Sendable>(
        _ api: APIRequest,
        as type: T.Type
    ) -> AnyPublisher<T, NetworkError>
}

/// 网络客户端
///
/// ## 调用方法
/// ```swift
/// // 1. 默认实例（生产环境）
/// let client = NetworkClient()
///
/// // 2. 注入自定义 Session（如单测）
/// let client = NetworkClient(session: mockSession)
///
/// // 3. 发起请求
/// client.request(SomeAPI.foo, as: FooModel.self)
///     .sink(
///         receiveCompletion: { ... },
///         receiveValue: { model in ... }
///     )
///     .store(in: &cancellables)
/// ```
///
/// ## 关于日志与 `asURLRequest()`
/// 打日志时**只**使用 `api.urlString`（纯字符串拼接）——
/// **不要**用 `api.asURLRequest()`，否则对 `uploadAvatar` 这类
/// multipart 请求会重复构造几 MB 的 body（一次为日志、一次为请求）。
public final class NetworkClient: NetworkClientProtocol {

    // MARK: - Properties

    private let session: Session

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter session: 自定义 Alamofire Session；传 nil 时使用默认配置。
    ///                      单测可注入 MockSession 或自定义 Session。
    public init(session: Session? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.af.default
            configuration.timeoutIntervalForRequest  = APIConfiguration.defaultTimeout
            configuration.timeoutIntervalForResource = APIConfiguration.defaultTimeout * 2
            configuration.httpShouldSetCookies = false
            configuration.httpCookieAcceptPolicy = .never
            self.session = Session(configuration: configuration)
        }
    }

    // MARK: - Request

    /// 发起请求
    ///
    /// - Parameters:
    ///   - api: 请求实例
    ///   - type: 期望解码的目标类型
    /// - Returns: 解析后的 Publisher（主线程回调）
    public func request<T: Decodable & Sendable>(_ api: APIRequest, as type: T.Type) -> AnyPublisher<T, NetworkError> {

        // 用 RequestBox 在闭包外持有 DataRequest，便于取消时能访问
        let box = RequestBox()

        return Future<T, NetworkError> { [weak self] promise in
            // 用 weak self：NetworkClient 释放后立即返回取消
            guard let self else {
                promise(.failure(.cancelled))
                return
            }

            let requestID = String(UUID().uuidString.prefix(8))
            let urlString = Self.logDescription(for: api)
            let startTime = Date()

            NetworkLogger.logRequest(
                api: api,
                requestID: requestID,
                urlString: urlString
            )

            let dataRequest = self.session
                .request(api)
                .validate()

            // 把请求交给 box 管理；若此时订阅已被取消，box 会立即 cancel
            box.set(dataRequest)

            dataRequest.responseDecodable(of: APIResponse<T>.self) { response in
                let result = Self.handle(response: response, requestID: requestID)
                let duration = Date().timeIntervalSince(startTime)

                NetworkLogger.logResponse(
                    requestID: requestID,
                    statusCode: response.response?.statusCode,
                    duration: duration,
                    result: result
                )

                // 统一在主线程 resume promise：
                // - Combine 的订阅方多半是 @MainActor（ViewModel / VC）
                // - 切主让下游无需再 `receive(on: .main)`
                if Thread.isMainThread {
                    promise(result)
                } else {
                    DispatchQueue.main.async {
                        promise(result)
                    }
                }
            }
        }
        .handleEvents(receiveCancel: {
            // ✅ 核心：订阅取消时真正取消底层网络请求
            box.cancel()
        })
        .eraseToAnyPublisher()
    }

    // MARK: - Response Handling

    /// 把 Alamofire 的响应转换为业务层的 `Result<T, NetworkError>`
    ///
    /// - Parameters:
    ///   - response: Alamofire 响应
    ///   - requestID: 请求 ID（用于日志）
    /// - Returns: 业务层结果
    ///
    /// - Note: `nonisolated` 是显式冗余——本方法在当前 `NetworkClient`
    ///         （未标注 `@MainActor`）中本就无 actor 隔离。
    ///         保留是为了防御未来给类加 `@MainActor` 时被误破坏。
    private nonisolated static func handle<T: Decodable & Sendable>(response: DataResponse<APIResponse<T>, AFError>, requestID: String) -> Result<T, NetworkError> {

        switch response.result {
        case .success(let apiResponse):
            // 1. 优先检查 token 失效：即使 code 不在 successCodes 里
            //    只要命中 tokenErrorCode，都返回 tokenExpired
            if apiResponse.isTokenExpired {
                return .failure(.tokenExpired)
            }

            // 2. 业务码判定
            guard apiResponse.isSuccess else {
                let message = apiResponse.msg ?? APIConfiguration.serverErrorMessage
                return .failure(.server(code: apiResponse.code, message: message))
            }

            // 3. 区分「data 存在但解码失败」与「data 缺失」
            if let decodeError = apiResponse.decodeError {
                return .failure(.decoding(decodeError))
            }

            // 4. data 为 nil：空数据（非错误场景）
            guard let data = apiResponse.data else {
                return .failure(.emptyData)
            }

            return .success(data)

        case .failure(let error):
            return .failure(mapError(error))
        }
    }

    // MARK: - Error Mapping

    /// 把 Alamofire 的 `AFError` 映射到业务层的 `NetworkError`
    ///
    /// ## 映射优先级
    /// 1. **显式取消**：`AFError.explicitlyCancelled`
    /// 2. **底层 URLError**：超时 / 断网 / 取消
    /// 3. **底层 DecodingError**：数据格式不匹配
    /// 4. **HTTP 状态码**：401 → tokenExpired，其他 → httpError
    /// 5. **兜底**：`.underlying`
    ///
    /// - Parameter error: Alamofire 错误
    /// - Returns: 业务层错误
    ///
    /// - Note: `nonisolated` 同上——显式冗余，防御未来变更。
    private nonisolated static func mapError(_ error: AFError) -> NetworkError {

        // 1. 显式取消
        if error.isExplicitlyCancelledError {
            return .cancelled
        }

        // 2. 底层 URLError
        if let underlyingError = error.underlyingError {
            if let urlError = underlyingError as? URLError {
                switch urlError.code {
                case .timedOut:
                    return .timeout
                case .notConnectedToInternet,
                     .networkConnectionLost,
                     .dataNotAllowed,
                     .internationalRoamingOff:
                    return .noConnection
                case .cancelled:
                    return .cancelled
                default:
                    break
                }
            }
            // 3. 底层 DecodingError
            if let decodingError = underlyingError as? DecodingError {
                return .decoding(decodingError)
            }
        }

        // 4. HTTP 状态码
        if let responseCode = error.responseCode {
            if responseCode == APIConfiguration.tokenErrorCode {
                return .tokenExpired
            }
            return .httpError(statusCode: responseCode)
        }

        // 5. 兜底
        return .underlying(error)
    }

    // MARK: - Logging Helpers

    /// 生成用于日志的 URL 描述
    ///
    /// ## 为什么不用 `api.asURLRequest()`？
    /// - `UserProfileAPI.uploadAvatar` 的 `asURLRequest()` 会**构造
    ///   multipart body**（几 MB 的 JPEG 数据）
    /// - 而 `session.request(api)` 内部**已经**调用过一次 `asURLRequest()`
    /// - 若日志再用 `asURLRequest()`，同一份 body 会被构造**两次**——
    ///   白白浪费几百毫秒 CPU + 内存峰值
    ///
    /// ## 正确做法
    /// 用 `api.urlString`——`APIRequest` 协议扩展提供的计算属性，
    /// 只做 `URLBuilder.build(base:path:)` 的纯字符串拼接，
    /// **完全不触碰** `asURLRequest()`。
    ///
    /// - Debug：完整 URL（含 query）
    /// - Release：仅 host + path
    ///
    /// - Parameter api: 请求实例
    /// - Returns: 日志用的 URL 字符串
    ///
    /// - Note: `nonisolated` 同上——显式冗余，防御未来变更。
    private nonisolated static func logDescription(for api: APIRequest) -> String {
        // ✅ 核心：用 `api.urlString`（纯字符串拼接），不构造 URLRequest
        let rawURL = api.urlString

        #if DEBUG
        return rawURL
        #else
        guard let url = URL(string: rawURL),
              let host = url.host else {
            return api.path
        }
        return "\(host)\(url.path)"
        #endif
    }
}

// MARK: - RequestBox

/// 线程安全的 `DataRequest` 持有器
///
/// ## 职责
/// 在 `Future` 闭包外持有 `DataRequest`，让 `handleEvents(receiveCancel:)`
/// 能真正取消底层网络请求。
///
/// ## 为什么 `@unchecked Sendable`？
/// 内部所有可变状态（`request` / `cancelled`）都由 `NSLock` 保护——
/// 编译器无法自动验证，但人工保证线程安全。
private final class RequestBox: @unchecked Sendable {

    private let lock = NSLock()
    private var request: DataRequest?
    private var cancelled = false

    /// 存储请求；若已被取消则立即取消该请求
    ///
    /// - Parameter request: 待存储的 Alamofire 请求
    func set(_ request: DataRequest) {
        lock.lock()
        let shouldCancelImmediately = cancelled
        if !shouldCancelImmediately {
            self.request = request
        }
        lock.unlock()

        // `cancel` 在锁外调用——避免 Alamofire 内部的同步回调
        // 再次进入本类的其他方法导致死锁
        if shouldCancelImmediately {
            request.cancel()
        }
    }

    /// 标记为取消，并取消已持有的请求（如有）
    ///
    /// - Note: `pending?.cancel()` 同样在锁外调用（理由同上）。
    func cancel() {
        lock.lock()
        cancelled = true
        let pending = request
        request = nil
        lock.unlock()

        pending?.cancel()
    }
}

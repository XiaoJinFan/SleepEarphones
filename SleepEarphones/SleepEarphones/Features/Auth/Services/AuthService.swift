//
//  AuthService.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/17.
//

import Foundation
import Combine

// MARK: - 服务协议

/// 认证服务协议
///
/// ## 调用方法
/// ```swift
/// // 1. 生产环境（通常由 AuthRepository 内部持有）
/// let service = AuthService()
///
/// // 2. 单元测试（注入 Mock）
/// let service = AuthService(client: MockNetworkClient())
///
/// // 3. 调用
/// service.passwordLogin(account: "138...", accountType: .mobile, password: "abc123")
///     .sink(
///         receiveCompletion: { ... },
///         receiveValue: { result in ... }
///     )
///     .store(in: &cancellables)
/// ```
///
/// ## 与 `AuthRepository` 的区别
/// | 层 | 职责 |
/// |---|---|
/// | `AuthService` | 网络请求 + 参数组装 |
/// | `AuthRepository` | 网络请求 + **凭证持久化**（`AuthStore.save`） |
protocol AuthServiceProtocol: Sendable {

    /// 账号密码登录
    ///
    /// - Parameters:
    ///   - account: 账号（手机号 / 邮箱 / 用户名）
    ///   - accountType: 账号类型
    ///   - password: 密码
    /// - Returns: 登录结果 Publisher
    func passwordLogin(account: String, accountType: AccountType, password: String) -> AnyPublisher<LoginResult, NetworkError>

    /// 验证码登录
    ///
    /// - Parameters:
    ///   - account: 手机号 / 邮箱
    ///   - accountType: 账号类型
    ///   - code: 验证码
    /// - Returns: 登录结果 Publisher
    func codeLogin(account: String, accountType: AccountType, code: String) -> AnyPublisher<LoginResult, NetworkError>

    /// 发送短信 / 邮箱验证码
    ///
    /// - Parameters:
    ///   - account: 接收验证码的手机号 / 邮箱
    ///   - accountType: 账号类型
    ///   - scene: 业务场景
    /// - Returns: 发送结果（DEBUG 下含测试验证码）
    ///
    /// - Important: 调用成功会触发**服务端短信计数**，
    ///              前端应在按钮上加倒计时避免重复调用。
    func sendSmsCode(account: String, accountType: AccountType, scene: SmsScene) -> AnyPublisher<SmsCodeResult, NetworkError>

    /// 忘记密码 / 重置密码
    ///
    /// - Parameters:
    ///   - account: 账号
    ///   - accountType: 账号类型
    ///   - newPassword: 新密码
    ///   - code: 验证码（可为 nil）
    /// - Returns: 空响应 Publisher
    func forgetPassword(account: String, accountType: AccountType, newPassword: String, code: String?) -> AnyPublisher<EmptyResponse, NetworkError>

    /// 注册
    ///
    /// - Parameters:
    ///   - account: 手机号 / 邮箱
    ///   - accountType: 账号类型
    ///   - password: 密码
    ///   - code: 验证码（可为 nil）
    /// - Returns: 注册结果 Publisher
    ///
    /// - Note: 注册成功后后端会直接返回 token，
    ///         相当于同时完成登录，无需再次调用登录接口。
    func register(account: String, accountType: AccountType, password: String, code: String?) -> AnyPublisher<LoginResult, NetworkError>
}

// MARK: - 服务实现

/// 认证服务实现
///
/// ## 依赖注入
/// `client` 通过协议注入，默认使用 `NetworkClient()`：
/// - 生产环境：直接 `AuthService()` 使用默认 `NetworkClient`
/// - 单元测试：`AuthService(client: MockNetworkClient())`
///
/// ## 日志策略（重要）
/// ### 按操作性质分级
/// | 操作 | 级别 | 理由 |
/// |---|---|---|
/// | 密码 / 验证码登录 | `debug` | 常规操作，量多 |
/// | **发送验证码** | **`info`** | ⚠️ 有**成本**（短信计费）+ 有**风控意义** |
/// | 重置密码 | `debug` | 常规操作 |
/// | **注册** | **`info`** | ⚠️ **关键业务事件**（新用户增长指标） |
final class AuthService: AuthServiceProtocol {

    // MARK: - Properties

    private let client: NetworkClientProtocol

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter client: 网络客户端，默认 `NetworkClient()`
    init(client: NetworkClientProtocol = NetworkClient()) {
        self.client = client
    }

    // MARK: - 密码登录

    /// 密码登录
    ///
    /// - Parameters:
    ///   - account: 账号
    ///   - accountType: 账号类型
    ///   - password: 密码
    /// - Returns: 登录结果 Publisher
    func passwordLogin(account: String, accountType: AccountType, password: String) -> AnyPublisher<LoginResult, NetworkError> {
        AppLog.auth.debug(
            "密码登录：accountType=\(accountType.rawValue, privacy: .public) account=\(account, privacy: .private)"
        )

        return client.request(
            AuthAPI.passwordLogin(
                account: account,
                accountType: accountType,
                password: password
            ),
            as: LoginResult.self
        )
        .eraseToAnyPublisher()
    }

    // MARK: - 验证码登录

    /// 验证码登录
    ///
    /// - Parameters:
    ///   - account: 手机号 / 邮箱
    ///   - accountType: 账号类型
    ///   - code: 验证码
    /// - Returns: 登录结果 Publisher
    func codeLogin(account: String, accountType: AccountType, code: String) -> AnyPublisher<LoginResult, NetworkError> {
        AppLog.auth.debug(
            "验证码登录：accountType=\(accountType.rawValue, privacy: .public) account=\(account, privacy: .private)"
        )

        return client.request(
            AuthAPI.codeLogin(
                account: account,
                accountType: accountType,
                code: code
            ),
            as: LoginResult.self
        )
        .eraseToAnyPublisher()
    }

    // MARK: - 发送验证码

    /// 发送验证码
    ///
    /// - Parameters:
    ///   - account: 接收验证码的手机号 / 邮箱
    ///   - accountType: 账号类型
    ///   - scene: 业务场景
    /// - Returns: 发送结果 Publisher
    ///
    /// ## Privacy 说明
    /// - `scene`：`privacy: .public`——非敏感枚举（"注册"/"登录"等）
    /// - `accountType`：`privacy: .public`——非敏感
    /// - `account`：`privacy: .private`——用户隐私
    func sendSmsCode(account: String, accountType: AccountType, scene: SmsScene) -> AnyPublisher<SmsCodeResult, NetworkError> {
        // ⚠️ 用 info 级别——区别于其他接口的 debug（详见类注释"日志策略"）
        AppLog.auth.info(
            "📤 发送验证码：scene=\(scene.description, privacy: .public) accountType=\(accountType.rawValue, privacy: .public) account=\(account, privacy: .private)"
        )

        return client.request(
            AuthAPI.sendSmsCode(
                account: account,
                accountType: accountType,
                scene: scene
            ),
            as: SmsCodeResult.self
        )
        .eraseToAnyPublisher()
    }

    // MARK: - 忘记密码

    /// 忘记密码 / 重置密码
    ///
    /// - Parameters:
    ///   - account: 账号
    ///   - accountType: 账号类型
    ///   - newPassword: 新密码
    ///   - code: 验证码（可为 nil）
    /// - Returns: 空响应 Publisher
    func forgetPassword(account: String, accountType: AccountType, newPassword: String, code: String?) -> AnyPublisher<EmptyResponse, NetworkError> {
        AppLog.auth.debug(
            "重置密码：accountType=\(accountType.rawValue, privacy: .public) account=\(account, privacy: .private)"
        )

        return client.request(
            AuthAPI.forgetPassword(
                account: account,
                accountType: accountType,
                newPassword: newPassword,
                code: code
            ),
            as: EmptyResponse.self
        )
        .eraseToAnyPublisher()
    }

    // MARK: - 注册

    /// 注册
    ///
    /// - Parameters:
    ///   - account: 手机号 / 邮箱
    ///   - accountType: 账号类型
    ///   - password: 密码
    ///   - code: 验证码（可为 nil）
    /// - Returns: 注册结果 Publisher
    ///
    /// ## Privacy 说明
    /// - `accountType`：`privacy: .public`
    /// - `account`：`privacy: .private`
    func register(account: String, accountType: AccountType, password: String, code: String?) -> AnyPublisher<LoginResult, NetworkError> {
        // ⚠️ 用 info 级别——注册是关键业务事件（详见类注释"日志策略"）
        AppLog.auth.info(
            "🎉 用户注册：accountType=\(accountType.rawValue, privacy: .public) account=\(account, privacy: .private)"
        )

        return client.request(
            AuthAPI.register(
                account: account,
                accountType: accountType,
                password: password,
                code: code
            ),
            as: LoginResult.self
        )
        .eraseToAnyPublisher()
    }
}

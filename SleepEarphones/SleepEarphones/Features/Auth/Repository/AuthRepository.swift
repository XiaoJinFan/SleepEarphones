//
//  AuthRepository.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/17.
//

import Foundation
import Combine

// MARK: - 仓库协议

/// 认证仓库协议
///
/// ## 职责
/// - 调用 `AuthService` 完成网络请求
/// - **登录 / 注册成功后把凭证持久化到 `AuthStore`**
/// - 把 `EmptyResponse` 转成 `Void`，让上层只关心成功与否
///
/// ## 调用方法
/// ```swift
/// // 1. 生产环境（推荐）
/// let repo = AuthRepository()
///
/// // 2. 单元测试（注入 Mock）
/// let repo = AuthRepository(service: MockAuthService())
///
/// // 3. 调用登录（ViewModels 通过此协议使用）
/// repo.passwordLogin(account: "138...", accountType: .mobile, password: "abc123")
///     .sink(
///         receiveCompletion: { ... },
///         receiveValue: { result in /* 凭证已自动保存到 AuthStore */ }
///     )
///     .store(in: &cancellables)
/// ```
///
/// ## 与 `AuthService` 的区别
/// | 层 | 网络请求 | 凭证持久化 |
/// |---|---|---|
/// | `AuthService` | ✅ | ❌ |
/// | `AuthRepository` | 委托 Service | ✅ |
/// 
protocol AuthRepositoryProtocol: Sendable {

    // MARK: 登录

    /// 密码登录
    ///
    /// - Parameters:
    ///   - account: 账号（手机号 / 邮箱 / 用户名）
    ///   - accountType: 账号类型
    ///   - password: 密码
    /// - Returns: 登录结果 Publisher（成功后凭证已持久化）
    func passwordLogin(account: String, accountType: AccountType, password: String) -> AnyPublisher<LoginResult, NetworkError>

    /// 验证码登录
    ///
    /// - Parameters:
    ///   - account: 账号（手机号 / 邮箱）
    ///   - accountType: 账号类型
    ///   - code: 验证码
    /// - Returns: 登录结果 Publisher（成功后凭证已持久化）
    func codeLogin(account: String, accountType: AccountType, code: String) -> AnyPublisher<LoginResult, NetworkError>

    // MARK: 验证码

    /// 发送验证码
    ///
    /// - Parameters:
    ///   - account: 接收验证码的手机号 / 邮箱
    ///   - accountType: 账号类型
    ///   - scene: 业务场景
    /// - Returns: 发送结果（DEBUG 下含测试验证码）
    func sendSmsCode(account: String, accountType: AccountType, scene: SmsScene) -> AnyPublisher<SmsCodeResult, NetworkError>

    // MARK: 重置 / 注册

    /// 忘记密码 / 重置密码
    ///
    /// - Parameters:
    ///   - account: 账号
    ///   - accountType: 账号类型
    ///   - newPassword: 新密码
    ///   - code: 验证码
    /// - Returns: 成功时返回 `Void`
    ///
    /// - Note: 返回 `Void` 而非 `EmptyResponse`——
    ///         上层只关心成功 / 失败，不关心 `data` 内容。
    func forgetPassword(account: String, accountType: AccountType, newPassword: String, code: String?) -> AnyPublisher<Void, NetworkError>

    /// 注册（成功后同样会保存凭证，等同于登录）
    ///
    /// - Parameters:
    ///   - account: 账号
    ///   - accountType: 账号类型
    ///   - password: 密码
    ///   - code: 验证码
    /// - Returns: 注册结果 Publisher（成功后凭证已持久化）
    func register(account: String, accountType: AccountType, password: String, code: String?) -> AnyPublisher<LoginResult, NetworkError>
}

// MARK: - 仓库实现

/// 认证仓库实现
///
/// ## 数据流
/// ```
/// ViewModel
///   ↓ 调用 login / register
/// AuthRepository
///   ↓ 委托网络请求          ↓ 成功后保存凭证
/// AuthService         AuthStore
///   ↓
/// NetworkClient
/// ```
///
/// ## 凭证保存时机（重要）
/// 使用 `handleEvents(receiveOutput:)` 在**值传递给下游之前**保存凭证。
///
/// 因此当 ViewModel 收到 `.success(result)` 时，可以保证：
/// - ✅ Token 已写入 Keychain
/// - ✅ userId / nickname / avatar 已写入 UserDefaults
/// - ✅ 全局 `AuthStore.shared.isLoggedIn == true`
///
/// 调用方**无需**担心"登录成功但凭证还没保存"的竞态。
final class AuthRepository: AuthRepositoryProtocol {

    // MARK: - Properties

    private let service: AuthServiceProtocol
    private let store: AuthStore

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameters:
    ///   - service: 认证服务，默认 `AuthService()`
    ///   - store: 凭证存储，默认 `AuthStore.shared`（单例）
    init(service: AuthServiceProtocol = AuthService(), store: AuthStore = .shared) {
        self.service = service
        self.store = store
    }

    // MARK: - 密码登录

    /// 密码登录
    ///
    /// - Parameters:
    ///   - account: 账号
    ///   - accountType: 账号类型
    ///   - password: 密码
    /// - Returns: 登录结果 Publisher（凭证已持久化）
    func passwordLogin(account: String, accountType: AccountType, password: String) -> AnyPublisher<LoginResult, NetworkError> {
        service.passwordLogin(
            account: account,
            accountType: accountType,
            password: password
        )
        .saveCredentials(to: store)
        .eraseToAnyPublisher()
    }

    // MARK: - 验证码登录

    /// 验证码登录
    ///
    /// - Parameters:
    ///   - account: 账号
    ///   - accountType: 账号类型
    ///   - code: 验证码
    /// - Returns: 登录结果 Publisher（凭证已持久化）
    func codeLogin(account: String, accountType: AccountType, code: String) -> AnyPublisher<LoginResult, NetworkError> {
        service.codeLogin(
            account: account,
            accountType: accountType,
            code: code
        )
        .saveCredentials(to: store)
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
    /// - Note: 直接把 `SmsCodeResult` 向上传递（DEBUG 下含验证码）。
    ///         本方法**不涉及凭证**——直接透传。
    func sendSmsCode(account: String, accountType: AccountType, scene: SmsScene) -> AnyPublisher<SmsCodeResult, NetworkError> {
        service.sendSmsCode(
            account: account,
            accountType: accountType,
            scene: scene
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
    ///   - code: 验证码
    /// - Returns: 成功时返回 `Void`
    func forgetPassword(account: String, accountType: AccountType, newPassword: String, code: String?) -> AnyPublisher<Void, NetworkError> {
        service.forgetPassword(
            account: account,
            accountType: accountType,
            newPassword: newPassword,
            code: code
        )
        .map { _ in () }   // EmptyResponse → Void
        .eraseToAnyPublisher()
    }

    // MARK: - 注册

    /// 注册
    ///
    /// - Parameters:
    ///   - account: 账号
    ///   - accountType: 账号类型
    ///   - password: 密码
    ///   - code: 验证码
    /// - Returns: 注册结果 Publisher（凭证已持久化）
    func register(account: String, accountType: AccountType, password: String, code: String?) -> AnyPublisher<LoginResult, NetworkError> {
        service.register(
            account: account,
            accountType: accountType,
            password: password,
            code: code
        )
        .saveCredentials(to: store)
        .eraseToAnyPublisher()
    }
}

// MARK: - Publisher 便捷扩展

private extension Publisher
    where Output == LoginResult, Failure == NetworkError {

    /// 在值传递给下游之前把凭证保存到 `AuthStore`
    ///
    /// - Parameter store: 凭证存储
    /// - Returns: 保持原有 Output / Failure 的 Publisher
    ///
    /// - Note: **不捕获 `self`**——`store` 是 `let` 常量，
    ///         直接捕获即可，避免 `[weak self]` 在 repository 释放后
    ///         导致保存被静默跳过。
    func saveCredentials(to store: AuthStore) -> AnyPublisher<LoginResult, NetworkError> {
        handleEvents(receiveOutput: { result in
            store.save(result)
        })
        .eraseToAnyPublisher()
    }
}

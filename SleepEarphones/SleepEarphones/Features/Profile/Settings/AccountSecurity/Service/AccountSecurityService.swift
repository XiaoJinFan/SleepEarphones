//
//  AccountSecurityService.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/30.
//

import Foundation
import Combine

// MARK: - 服务协议

/// 账号与安全网络服务协议
///
/// ## 职责
/// - 只负责**网络请求**（调用 `NetworkClient`）
/// - 不做 UI 逻辑 / 不做本地存储
///
/// ## 调用方法
/// ```swift
/// // 1. 生产环境
/// let service = AccountSecurityService()
///
/// // 2. 单元测试（注入 Mock）
/// let service = AccountSecurityService(client: MockNetworkClient())
///
/// // 3. 调用
/// service.changePassword(oldPassword: "old", newPassword: "new")
///     .sink(
///         receiveCompletion: { ... },
///         receiveValue: { ... }
///     )
///     .store(in: &cancellables)
/// ```
protocol AccountSecurityServiceProtocol: Sendable {

    /// 修改密码
    ///
    /// - Parameters:
    ///   - oldPassword: 旧密码（明文，HTTPS 传输）
    ///   - newPassword: 新密码
    /// - Returns: 成功时返回 `Void`
    ///
    /// - Note: 后端 `user/edit_password` 接口——
    ///         不返回具体数据，用 `EmptyResponse` 宽容解码。
    func changePassword(oldPassword: String, newPassword: String) -> AnyPublisher<Void, NetworkError>

    /// 修改绑定手机号（已绑定过手机）
    ///
    /// - Parameters:
    ///   - newPhone: 新手机号
    ///   - newCode: 新手机收到的验证码
    ///               （旧手机已在 Step 1 验证通过，无需再传）
    /// - Returns: 成功时返回 `Void`
    func changePhone(newPhone: String, newCode: String) -> AnyPublisher<Void, NetworkError>

    /// 首次绑定手机号（此前未绑定）
    ///
    /// - Parameters:
    ///   - newPhone: 新手机号
    ///   - newCode: 新手机收到的验证码
    /// - Returns: 成功时返回 `Void`
    ///
    /// - Note: 与 `changePhone` 使用**同一后端接口**——
    ///         后端按当前用户绑定状态自动区分"首次绑定"或"修改"。
    func bindPhone(newPhone: String, newCode: String) -> AnyPublisher<Void, NetworkError>

    /// 修改绑定邮箱（已绑定过邮箱）
    ///
    /// - Parameters:
    ///   - newEmail: 新邮箱
    ///   - newCode: 新邮箱收到的验证码
    /// - Returns: 成功时返回 `Void`
    func changeEmail(newEmail: String, newCode: String) -> AnyPublisher<Void, NetworkError>

    /// 首次绑定邮箱
    ///
    /// - Parameters:
    ///   - newEmail: 新邮箱
    ///   - newCode: 新邮箱收到的验证码
    /// - Returns: 成功时返回 `Void`
    func bindEmail(newEmail: String, newCode: String) -> AnyPublisher<Void, NetworkError>

    /// 校验验证码（用于验证旧账号）
    ///
    /// - Parameters:
    ///   - account: 被验证的账号（旧手机号 / 旧邮箱）
    ///   - accountType: 账号类型
    ///   - code: 用户输入的验证码
    ///   - scene: 业务场景（改绑场景为 `.changePhone`）
    /// - Returns: 成功时返回 `Void`
    func checkCode(account: String, accountType: AccountType, code: String, scene: SmsScene) -> AnyPublisher<Void, NetworkError>

    /// 发送验证码
    ///
    /// - Parameters:
    ///   - account: 接收验证码的手机号 / 邮箱
    ///   - accountType: 账号类型
    ///   - scene: 业务场景
    ///   - userId: 用户 ID（**可选**）——
    ///             Step 1 验证旧账号时传 `nil`；
    ///             Step 2 绑定新账号时传当前登录用户 ID（后端据此识别用户）
    /// - Returns: 成功时返回 `Void`
    func sendCode(account: String, accountType: AccountType, scene: SmsScene, userId: String?) -> AnyPublisher<Void, NetworkError>
}

// MARK: - 服务实现

/// 账号与安全网络服务实现
final class AccountSecurityService: AccountSecurityServiceProtocol, Sendable {

    // MARK: - Properties

    private let client: NetworkClientProtocol

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter client: 网络客户端，默认 `NetworkClient()`
    ///
    /// - Note: 生产环境直接 `AccountSecurityService()`；
    ///         `init` 保留 `client` 参数主要用于单元测试注入。
    init(client: NetworkClientProtocol = NetworkClient()) {
        self.client = client
    }

    // MARK: - 修改密码

    /// 修改密码
    ///
    /// - Parameters:
    ///   - oldPassword: 旧密码
    ///   - newPassword: 新密码
    /// - Returns: 成功时返回 `Void`
    func changePassword(oldPassword: String, newPassword: String) -> AnyPublisher<Void, NetworkError> {
        AppLog.profile.debug("修改密码请求")

        return client.request(
            AccountSecurityAPI.changePassword(
                oldPassword: oldPassword,
                newPassword: newPassword
            ),
            as: EmptyResponse.self
        )
        .map { _ in () }    // EmptyResponse → Void
        .eraseToAnyPublisher()
    }

    // MARK: - 修改绑定手机号

    /// 修改绑定手机号（已绑定过手机）
    ///
    /// - Parameters:
    ///   - newPhone: 新手机号
    ///   - newCode: 新手机收到的验证码
    /// - Returns: 成功时返回 `Void`
    func changePhone(newPhone: String, newCode: String) -> AnyPublisher<Void, NetworkError> {
        AppLog.profile.debug(
            "修改绑定手机号：newPhone=\(newPhone, privacy: .private)"
        )

        return client.request(
            AccountSecurityAPI.changePhone(
                newPhone: newPhone,
                newCode: newCode
            ),
            as: EmptyResponse.self
        )
        .map { _ in () }
        .eraseToAnyPublisher()
    }

    // MARK: - 首次绑定手机号

    /// 首次绑定手机号
    ///
    /// - Parameters:
    ///   - newPhone: 新手机号
    ///   - newCode: 新手机收到的验证码
    /// - Returns: 成功时返回 `Void`
    func bindPhone(newPhone: String, newCode: String) -> AnyPublisher<Void, NetworkError> {
        AppLog.profile.debug(
            "绑定手机号：newPhone=\(newPhone, privacy: .private)"
        )

        return client.request(
            AccountSecurityAPI.bindPhone(
                newPhone: newPhone,
                newCode: newCode
            ),
            as: EmptyResponse.self
        )
        .map { _ in () }
        .eraseToAnyPublisher()
    }

    // MARK: - 修改绑定邮箱

    /// 修改绑定邮箱（已绑定过邮箱）
    ///
    /// - Parameters:
    ///   - newEmail: 新邮箱
    ///   - newCode: 新邮箱收到的验证码
    /// - Returns: 成功时返回 `Void`
    func changeEmail(newEmail: String, newCode: String) -> AnyPublisher<Void, NetworkError> {
        AppLog.profile.debug(
            "修改绑定邮箱：newEmail=\(newEmail, privacy: .private)"
        )

        return client.request(
            AccountSecurityAPI.changeEmail(
                newEmail: newEmail,
                newCode: newCode
            ),
            as: EmptyResponse.self
        )
        .map { _ in () }
        .eraseToAnyPublisher()
    }

    // MARK: - 首次绑定邮箱

    /// 首次绑定邮箱
    ///
    /// - Parameters:
    ///   - newEmail: 新邮箱
    ///   - newCode: 新邮箱收到的验证码
    /// - Returns: 成功时返回 `Void`
    func bindEmail(newEmail: String, newCode: String) -> AnyPublisher<Void, NetworkError> {
        AppLog.profile.debug(
            "绑定邮箱：newEmail=\(newEmail, privacy: .private)"
        )

        return client.request(
            AccountSecurityAPI.bindEmail(
                newEmail: newEmail,
                newCode: newCode
            ),
            as: EmptyResponse.self
        )
        .map { _ in () }
        .eraseToAnyPublisher()
    }

    // MARK: - 校验验证码

    /// 校验验证码（用于验证旧账号）
    ///
    /// - Parameters:
    ///   - account: 被验证的账号（旧手机号 / 旧邮箱）
    ///   - accountType: 账号类型
    ///   - code: 用户输入的验证码
    ///   - scene: 业务场景
    /// - Returns: 成功时返回 `Void`
    func checkCode(account: String, accountType: AccountType, code: String, scene: SmsScene) -> AnyPublisher<Void, NetworkError> {
        AppLog.profile.debug(
            "校验验证码：account=\(account, privacy: .private) scene=\(scene.description, privacy: .public)"
        )

        return client.request(
            AccountSecurityAPI.checkCode(
                account: account,
                accountType: accountType,
                code: code,
                scene: scene
            ),
            as: EmptyResponse.self
        )
        .map { _ in () }
        .eraseToAnyPublisher()
    }

    // MARK: - 发送验证码

    /// 发送验证码（手机 / 邮箱）
    ///
    /// - Parameters:
    ///   - account: 接收验证码的手机号 / 邮箱
    ///   - accountType: 账号类型
    ///   - scene: 业务场景
    ///   - userId: 用户 ID；Step 1 传 `nil`，Step 2 传当前登录用户 ID
    /// - Returns: 成功时返回 `Void`
    func sendCode(account: String, accountType: AccountType, scene: SmsScene, userId: String?) -> AnyPublisher<Void, NetworkError> {
        AppLog.profile.debug(
            "发送验证码：account=\(account, privacy: .private) scene=\(scene.description, privacy: .public) userId=\(userId ?? "nil", privacy: .private)"
        )

        return client.request(
            AccountSecurityAPI.sendCode(
                account: account,
                accountType: accountType,
                scene: scene,
                userId: userId
            ),
            as: SmsCodeResult.self
        )
        .map { _ in () }
        .eraseToAnyPublisher()
    }
}

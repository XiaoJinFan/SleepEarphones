//
//  RegisterViewModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/21.
//

import Foundation
import Combine

/// 注册页视图模型
///
/// ## 职责
/// - 校验账号 / 密码 / 验证码（`canSubmit`）
/// - 发送注册验证码（`sendRegisterCode`）
/// - 提交注册请求（`register`）
///
/// ## 调用方法
/// ```swift
/// let vm = RegisterViewModel()
///
/// // 订阅注册成功
/// vm.$registerSuccess
///     .filter { $0 }
///     .sink { _ in /* 弹 Toast + pop 回登录页 */ }
///     .store(in: &cancellables)
/// ```
@MainActor
final class RegisterViewModel: AuthFormViewModel {

    // MARK: - Output（子类扩展）

    /// 注册成功标志位
    @Published private(set) var registerSuccess: Bool = false

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter repository: 认证仓库，默认 `AuthRepository()`
    override init(repository: AuthRepositoryProtocol = AuthRepository()) {
        super.init(repository: repository)
    }

    // MARK: - 状态计算

    /// 是否可以提交
    ///
    /// - Returns: 账号 + 密码 + 验证码均合法时为 `true`
    override var canSubmit: Bool {
        guard !currentAccount.isEmptyOrBlank else { return false }
        guard AccountInputValidator.isStrongPassword(password) else { return false }
        guard AccountInputValidator.isValidCode(code) else { return false }
        return true
    }

    // MARK: - Input Actions

    /// 发送注册验证码（`scene` 固定为 `.register`）
    func sendRegisterCode() {
        sendSmsCode(scene: .register)
    }

    /// 提交注册
    func register() {
        let publisher = repository.register(
            account: currentAccount,
            accountType: accountType,
            password: password,
            code: code
        )
        
        submit(publisher, operationName: L("注册")) { [weak self] result in
            guard let self else {
                // 防御性分支——基类 `submit` 已保证 VM 存活才会调 `onSuccess`
                AppLog.auth.debug("注册成功回调时 VM 已释放，忽略")
                return
            }
            AppLog.auth.debug(
                "注册成功，userToken 是否非空：\(result.hasValidToken, privacy: .public)"
            )
            self.toastMessage = L("注册成功")
            self.registerSuccess = true
        }
    }

    // MARK: - State Reset

    /// 重置状态到初始值
    func resetState() {
        registerSuccess = false
    }
}

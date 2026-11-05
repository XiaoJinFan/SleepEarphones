//
//  ForgetPasswordViewModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/21.
//

import Foundation
import Combine

/// 找回密码视图模型
///
/// ## 职责
/// - 校验旧密码 / 新密码 / 验证码（`canSubmit`）
/// - 发送找回密码验证码（`sendForgetCode`）
/// - 提交重置密码请求（`resetPassword`）
///
/// ## 调用方法
/// ```swift
/// let vm = ForgetPasswordViewModel()
///
/// // 订阅重置成功
/// vm.$resetSuccess
///     .filter { $0 }
///     .sink { _ in /* 弹 Toast + pop 回登录页 */ }
///     .store(in: &cancellables)
/// ```
@MainActor
final class ForgetPasswordViewModel: AuthFormViewModel {

    // MARK: - Output（子类扩展）

    /// 重置成功标志位
    @Published private(set) var resetSuccess: Bool = false

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
        guard AccountInputValidator.isValidPassword(password) else { return false }
        guard AccountInputValidator.isValidCode(code) else { return false }
        return true
    }

    // MARK: - Input Actions

    /// 发送找回密码验证码（`scene` 固定为 `.forgetPassword`）
    func sendForgetCode() {
        sendSmsCode(scene: .forgetPassword)
    }

    /// 提交重置密码
    func resetPassword() {
        let publisher = repository.forgetPassword(
            account: currentAccount,
            accountType: accountType,
            newPassword: password,
            code: code
        )
        
        submit(publisher, operationName: L("重置")) { [weak self] _ in
            guard let self else {
                // 防御性分支——基类 `submit` 已保证 VM 存活才会调 `onSuccess`
                AppLog.auth.debug("重置成功回调时 VM 已释放，忽略")
                return
            }
            AppLog.auth.debug("重置密码成功")
            self.toastMessage = L("密码重置成功")
            self.resetSuccess = true
        }
    }

    // MARK: - State Reset

    /// 重置状态到初始值
    func resetState() {
        resetSuccess = false
    }
}

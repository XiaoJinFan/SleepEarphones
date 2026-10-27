//
//  ForgetPasswordViewModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/21.
//

import Foundation
import Combine

@MainActor
final class ForgetPasswordViewModel: AuthFormViewModel {

    // MARK: - Output（子类扩展）

    /// 重置成功标志位
    @Published private(set) var resetSuccess: Bool = false

    // MARK: - Init

    /// 初始化
    override init(repository: AuthRepositoryProtocol = AuthRepository()) {
        super.init(repository: repository)
    }

    // MARK: - 状态计算

    /// 是否可以提交
    ///
    /// - Returns: 账号 + 密码 + 验证码均合法时为 `true`
    ///
    /// ## 判断逻辑（三个条件同时满足）
    /// 1. 账号非空（**trim 首尾空白后**判断——纯空格视为空）
    /// 2. 密码长度合法（≥6 位，**宽松校验**）
    /// 3. 验证码长度合法
    ///
    /// - Important: 使用 `isEmptyOrBlank` 而非 `isEmpty`——
    ///              与基类 `AuthFormViewModel.canSubmit` 的判定口径保持一致，
    ///              避免用户输入纯空格时"看似通过了校验，请求却失败"。
    override var canSubmit: Bool {
        guard !currentAccount.isEmptyOrBlank else { return false }
        guard AccountInputValidator.isValidPassword(password) else { return false }
        guard AccountInputValidator.isValidCode(code) else { return false }
        return true
    }

    // MARK: - Input Actions

    /// 发送找回密码验证码（`scene` 固定为 `.forgetPassword`）
    ///
    /// - Note: 便利方法，避免调用方记 `scene` 参数。
    ///         与 `RegisterViewModel.sendRegisterCode` 风格一致。
    func sendForgetCode() {
        sendSmsCode(scene: .forgetPassword)
    }

    /// 提交重置密码
    ///
    /// ## 关于"重置成功后是否自动登录"
    /// **不自动登录**。原因：
    /// - 用户当前的意图是"找回密码"，不是"登录"
    /// - 重置成功后应返回登录页，让用户用新密码登录一次
    /// - 这样用户能确认"新密码确实有效"，避免记忆错误
    func resetPassword() {
        let publisher = repository.forgetPassword(
            account: currentAccount,
            accountType: accountType,
            newPassword: password,
            code: code
        )

        submit(publisher, operationName: "重置") { [weak self] _ in
            guard let self else {
                AppLog.auth.debug("重置成功回调时 VM 已释放，忽略")
                return
            }
            AppLog.auth.debug("重置密码成功")
            self.toastMessage = "密码重置成功"
            self.resetSuccess = true
        }
    }

    // MARK: - State Reset

    /// 重置状态到初始值
    ///
    /// ## 使用场景
    /// - 用户重置成功返回登录页后，若复用 VM 需手动复位
    /// - 单元测试间隔离
    ///
    /// - Note: **只重置本子类扩展的状态**（`resetSuccess`）。
    ///         基类状态由基类管理。
    ///         当前生产流程下重置成功后直接 pop，VM 会随 VC 一并释放，
    ///         **无需**调用本方法——此方法为未来扩展场景预留。
    func resetState() {
        resetSuccess = false
    }
}

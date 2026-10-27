//
//  RegisterViewModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/21.
//

import Foundation
import Combine

@MainActor
final class RegisterViewModel: AuthFormViewModel {

    // MARK: - Output（子类扩展）

    /// 注册成功标志位
    ///
    /// - Note:
    ///   - 用于驱动 UI（如 `RegistViewController` 订阅后自动 pop）
    ///   - 一旦置为 true 后**不会**自动重置；如需复用 VM，
    ///     调用 `resetState()` 恢复初始状态
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
    ///
    /// ## 判断逻辑（三个条件同时满足）
    /// 1. 账号非空（**trim 首尾空白后**判断——纯空格视为空）
    /// 2. 密码满足**严格**校验（6~12 位字母+数字）
    /// 3. 验证码长度合法
    ///
    /// - Important: 与登录页用**宽松**的 `isValidPassword` 不同，
    ///              注册页用**严格**的 `isStrongPassword`——
    ///              因为这是新密码的第一次设定，需要保证强度；
    ///              而登录页的密码可能是老用户的历史密码。
    ///
    /// - Note: `isEmptyOrBlank` 与基类 `AuthFormViewModel.canSubmit`
    ///         口径一致——避免"纯空格通过校验，请求失败"的问题。
    override var canSubmit: Bool {
        guard !currentAccount.isEmptyOrBlank else { return false }
        guard AccountInputValidator.isStrongPassword(password) else { return false }
        guard AccountInputValidator.isValidCode(code) else { return false }
        return true
    }

    // MARK: - Input Actions

    /// 发送注册验证码（`scene` 固定为 `.register`）
    ///
    /// - Note: 便利方法，避免调用方记 `scene` 参数。
    ///         与 `ForgetPasswordViewModel.sendForgetCode` 风格一致。
    func sendRegisterCode() {
        sendSmsCode(scene: .register)
    }

    /// 提交注册
    ///
    /// ## 关于注册即登录（时序说明）
    /// 后端注册接口成功后返回 token（同登录接口），
    /// `AuthRepository.register` 内部通过 `handleEvents(receiveOutput:)`
    /// 在值传递到下游之前**已调用 `AuthStore.save` 保存凭证**。
    ///
    /// 因此当本方法收到成功回调时，可以保证：
    /// - ✅ Token 已写入 Keychain
    /// - ✅ userId / nickname / avatar 已写入 UserDefaults
    /// - ✅ `AuthStore.shared.isLoggedIn == true`
    ///
    /// ## 关于本页不做跳转
    /// 注册页通常从登录页 push 进入——注册成功后**只置 `registerSuccess = true`**，
    /// 由 `RegistViewController` 订阅该标志后 pop 回登录页。
    /// 是否切根控制器（进入主界面）由登录页的 ViewModel 决定。
    func register() {
        let publisher = repository.register(
            account: currentAccount,
            accountType: accountType,
            password: password,
            code: code
        )

        submit(publisher, operationName: "注册") { [weak self] result in
            guard let self else {
                AppLog.auth.debug("注册成功回调时 VM 已释放，忽略")
                return
            }
            AppLog.auth.debug(
                "注册成功，userToken 是否非空：\(result.hasValidToken, privacy: .public)"
            )
            self.toastMessage = "注册成功"
            self.registerSuccess = true
        }
    }

    // MARK: - State Reset

    /// 重置状态到初始值
    ///
    /// ## 使用场景
    /// - 用户注册成功后返回登录页，若复用 VM 需手动复位
    /// - 单元测试间隔离
    ///
    /// - Note: **只重置本子类扩展的状态**（`registerSuccess`）。
    ///         基类状态由基类管理。
    ///         当前生产流程下注册成功后直接 pop，VM 会随 VC 一并释放，
    ///         **无需**调用本方法——此方法为未来扩展场景预留。
    func resetState() {
        registerSuccess = false
    }
}

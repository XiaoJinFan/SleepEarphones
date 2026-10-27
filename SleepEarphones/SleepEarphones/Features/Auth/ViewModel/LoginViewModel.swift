//
//  LoginViewModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/17.
//

import Foundation
import Combine

/// 登录页视图模型
///
/// ## 继承关系
/// ```
/// AuthFormViewModel（基类：账号输入 / 验证码 / 倒计时 / 通用提交）
///   └── LoginViewModel（子类：登录方式切换 + 提交登录）
/// ```
///
/// ## 两个切换维度（易混淆）
/// | 属性 | 类型 | 切换控件 | 作用 |
/// |---|---|---|---|
/// | `accountMode` | `LoginAccountMode` | `segmentControl` | 手机号 / 邮箱 |
/// | `loginMethod` | `LoginMethod` | `loginTypeBtn` | 验证码 / 密码 |
///
/// 两个维度**独立**，任意组合：
/// - 手机 + 验证码
/// - 手机 + 密码
/// - 邮箱 + 验证码
/// - 邮箱 + 密码
///
/// ## 调用方法
/// ```swift
/// // 1. 初始化（默认使用 AuthRepository）
/// let vm = LoginViewModel()
///
/// // 2. 绑定输入
/// vm.phone = "13800138000"
/// vm.code  = "1234"
///
/// // 3. 切换登录方式
/// vm.toggleLoginMethod()
///
/// // 4. 提交登录
/// vm.login()
///
/// // 5. 订阅结果
/// vm.$loginSuccess
///     .filter { $0 }
///     .sink { _ in /* 跳转主界面 */ }
/// ```
@MainActor
final class LoginViewModel: AuthFormViewModel {

    // MARK: - Input（子类扩展）

    /// 登录方式（验证码 / 密码）
    ///
    /// - Note: 与 `accountMode` 组合使用，可表达 4 种登录场景。
    @Published var loginMethod: LoginMethod = .code

    // MARK: - Output（子类扩展）

    /// 登录成功标志位
    ///
    /// - Note:
    ///   - 用于驱动 UI 跳转（`LoginViewController` 订阅后切根控制器）
    ///   - 一旦置为 true 后**不会**自动重置；如需复用 VM，
    ///     调用 `resetState()` 恢复初始状态
    @Published private(set) var loginSuccess: Bool = false

    // MARK: - 便捷判断

    /// 当前是否为验证码登录方式
    ///
    /// - Returns: `loginMethod == .code` 时为 `true`
    ///
    /// - Note: 视图层可据此控制 UI 显隐，避免直接 switch `loginMethod`。
    var isCodeLogin: Bool {
        loginMethod == .code
    }

    /// 当前是否为密码登录方式
    ///
    /// - Returns: `loginMethod == .password` 时为 `true`
    var isPasswordLogin: Bool {
        loginMethod == .password
    }

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
    /// - Returns: 账号 + 验证码/密码均合法时为 `true`
    ///
    /// ## 判断逻辑
    /// 1. 账号非空（**已 trim 首尾空白**）
    /// 2. 根据 `loginMethod` 分支：
    ///    - 验证码模式：验证码格式合法
    ///    - 密码模式：密码长度合法
    override var canSubmit: Bool {
        // 1. 账号非空（trim 首尾空白后判断）
        guard !currentAccount.isEmptyOrBlank else { return false }

        // 2. 依登录方式分支
        switch loginMethod {
        case .code:
            return AccountInputValidator.isValidCode(code)
        case .password:
            return AccountInputValidator.isValidPassword(password)
        }
    }

    // MARK: - Input Actions

    /// 切换登录方式（验证码 / 密码）
    ///
    /// ## 行为
    /// - 切换后**清空另一个方式的输入**（验证码 ⇄ 密码）
    /// - 清空错误信息（旧错误已不适用）
    func toggleLoginMethod() {
        loginMethod.toggle()

        AppLog.auth.debug("切换登录方式：→ \(self.loginMethod.description, privacy: .public)")

        // 切换后清空另一个方式的输入
        switch loginMethod {
        case .code:     password = ""
        case .password: code = ""
        }
        errorMessage = nil
    }

    /// 提交登录
    ///
    /// ## 流程
    /// 1. 根据 `loginMethod` 构造 Publisher
    /// 2. 调用基类 `submit(...)` 完成统一逻辑（防抖 + 令牌 + 加载态）
    /// 3. 成功后置 `loginSuccess = true`
    func login() {
        // 1. 根据登录方式选择 Publisher
        let publisher = makeLoginPublisher()

        // 2. 调用基类通用提交
        submit(publisher, operationName: "登录") { [weak self] result in
            guard let self else {
                // 防御性分支——基类的 `submit` 已保证 VM 存活才会调 `onSuccess`。
                AppLog.auth.debug("登录成功回调时 VM 已释放，忽略")
                return
            }

            AppLog.auth.debug(
                "登录成功，userToken 是否非空：\(result.hasValidToken, privacy: .public)"
            )

            // 先置成功标志（驱动 UI 切根控制器）
            self.loginSuccess = true

            // 再缓存登录方式（"账号与安全"页据此决定菜单顺序）
            AuthStore.shared.cachedLoginType = self.accountMode
        }
    }

    // MARK: - Private Helpers

    /// 依当前登录方式构造对应的请求 Publisher
    ///
    /// - Returns: 对应登录方式的请求 Publisher
    private func makeLoginPublisher() -> AnyPublisher<LoginResult, NetworkError> {
        switch loginMethod {
        case .code:
            return repository.codeLogin(
                account: currentAccount,
                accountType: accountType,
                code: code
            )
        case .password:
            return repository.passwordLogin(
                account: currentAccount,
                accountType: accountType,
                password: password
            )
        }
    }

    // MARK: - State Reset

    /// 重置状态到初始值
    ///
    /// ## 使用场景
    /// - 用户登录成功后返回登录页（如 Modal 场景）
    /// - 单元测试间隔离
    ///
    /// - Note: **只重置子类扩展的状态**（`loginSuccess` / `loginMethod`），
    ///         **不重置**基类状态（账号输入 / 加载态 / 倒计时）。
    func resetState() {
        loginSuccess = false
        loginMethod = .code
    }
}

//
//  AuthFormViewModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/21.
//

import Foundation
import Combine

/// 认证表单 ViewModel 基类
///
/// ## 职责
/// 承载登录 / 注册 / 找回密码三页**共享**的逻辑：
/// - 账号输入（手机 / 邮箱切换）
/// - 验证码倒计时
/// - 发送验证码
/// - **通用提交机制**（防抖 + 令牌 + 加载态）
/// - 错误 / Toast 状态
///
/// ## 调用方法
/// ```swift
/// // 子类继承后：
/// final class SomeViewModel: AuthFormViewModel {
///     override var canSubmit: Bool { ... }
///
///     func submitSomeAction() {
///         submit(publisher, operationName: L("操作名")) { result in
///             // 成功回调
///         }
///     }
/// }
/// ```
@MainActor
class AuthFormViewModel {

    // MARK: - Input（双向绑定）

    /// 手机号
    @Published var phone: String = ""

    /// 邮箱
    @Published var email: String = ""

    /// 验证码
    @Published var code: String = ""

    /// 密码（登录的密码 / 注册的密码 / 重置的密码，三页共用）
    @Published var password: String = ""

    /// 账号模式（手机 / 邮箱）
    @Published var accountMode: LoginAccountMode = .phone

    // MARK: - Output（单向订阅）

    /// 提交中（登录 / 注册 / 重置共用）
    @Published var isLoading: Bool = false

    /// 验证码发送中
    @Published var isSendingCode: Bool = false

    /// 倒计时剩余秒数（0 = 可再次发送）
    @Published private(set) var countdown: Int = 0

    /// 错误提示（用于 Alert）
    @Published var errorMessage: String?

    /// 轻提示（用于 Toast）
    @Published var toastMessage: String?

    // MARK: - Internal（子类可用）

    /// 认证仓库（子类提交时使用）
    let repository: AuthRepositoryProtocol

    /// 倒计时
    let countdownTimer = CountdownTimer()

    /// Combine 订阅容器（子类可复用）
    var cancellables = Set<AnyCancellable>()

    // MARK: - Private

    /// 当前进行中的验证码请求
    private var currentSmsRequest: AnyCancellable?

    /// 短信请求身份令牌
    private var smsRequestToken: UInt64 = 0

    /// 当前进行中的提交流程（登录 / 注册 / 重置）
    private var currentSubmitRequest: AnyCancellable?

    /// 提交请求身份令牌
    private var submitRequestToken: UInt64 = 0

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter repository: 认证仓库，默认 `AuthRepository()`
    init(repository: AuthRepositoryProtocol = AuthRepository()) {
        self.repository = repository

        // 桥接 CountdownTimer → 本 VM 的 countdown
        countdownTimer.$remaining
            .sink { [weak self] sec in
                self?.countdown = sec
            }
            .store(in: &cancellables)
    }

    // MARK: - 子类必须覆写

    /// 是否可以提交
    ///
    /// - Returns: 子类决定的可提交条件
    var canSubmit: Bool {
        assertionFailure("子类 \(type(of: self)) 必须覆写 canSubmit")
        return false
    }

    // MARK: - 状态计算

    /// 当前账号（根据 `accountMode` 返回 phone 或 email）
    ///
    /// - Returns: `accountMode == .phone` 时返回 `phone`；否则返回 `email`
    var currentAccount: String {
        switch accountMode {
        case .phone: return phone
        case .email: return email
        }
    }

    /// 当前账号类型（传给后端的 `account_type`）
    ///
    /// - Returns: `accountMode.accountType`
    var accountType: AccountType {
        accountMode.accountType
    }

    /// 是否可以发送验证码
    ///
    /// - Returns: 可发送时为 `true`
    var canSendCode: Bool {
        guard !countdownTimer.isRunning, !isSendingCode else { return false }
        return AccountInputValidator.isValidAccount(currentAccount, mode: accountMode)
    }

    // MARK: - Input Actions

    /// 切换账号模式（手机 / 邮箱）
    ///
    /// - Parameter mode: 目标模式
    func switchAccountMode(_ mode: LoginAccountMode) {
        guard mode != accountMode else { return }

        AppLog.auth.debug("切换账号模式：\(self.accountMode.rawValue) → \(mode.rawValue)")

        accountMode = mode
        code = ""
        errorMessage = nil
    }

    /// 发送验证码
    ///
    /// - Parameter scene: 短信业务场景（注册 / 登录 / 忘记密码等）
    func sendSmsCode(scene: SmsScene) {
        // 第一次 guard：静默防抖
        guard !isSendingCode, !countdownTimer.isRunning else {
            AppLog.auth.debug("发送验证码被拦截：已在发送中或倒计时中")
            return
        }

        // 第二次 guard：账号格式校验（会提示用户）
        guard canSendCode else {
            errorMessage = accountMode == .phone
                ? L("请输入正确的手机号")
                : L("请输入正确的邮箱")
            return
        }

        isSendingCode = true
        errorMessage = nil

        // 取消旧请求并递增令牌
        currentSmsRequest?.cancel()
        smsRequestToken &+= 1
        let token = smsRequestToken

        AppLog.auth.debug(
            "请求验证码：scene=\(scene.description, privacy: .public) token=\(token, privacy: .public)"
        )

        currentSmsRequest = repository.sendSmsCode(
            account: currentAccount,
            accountType: accountType,
            scene: scene
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                // 令牌校验：丢弃过期回调
                guard let self, self.smsRequestToken == token else {
                    AppLog.auth.debug("丢弃过期验证码回调 token=\(token, privacy: .public)")
                    return
                }
                self.isSendingCode = false
                self.currentSmsRequest = nil

                if case .failure(let error) = completion {
                    if case .cancelled = error { return }
                    self.errorMessage = error.errorDescription ?? L("验证码发送失败")
                }
            },
            receiveValue: { [weak self] result in
                // 令牌校验：丢弃过期回调
                guard let self, self.smsRequestToken == token else { return }
                self.handleSendCodeSuccess(result)
            }
        )
    }

    /// 验证码发送成功后的处理
    ///
    /// - Parameter result: 接口返回的 `SmsCodeResult`
    func handleSendCodeSuccess(_ result: SmsCodeResult) {
        toastMessage = L("验证码已发送")

        // 成功后才开始倒计时（失败可立即重试）
        countdownTimer.start(seconds: 60)

        #if DEBUG
        if shouldAutoFillCodeInDebug, let testCode = result.code {
            code = "\(testCode)"
            AppLog.auth.debug("🧪 测试模式：验证码已自动填充 \(testCode)")
        }
        #endif
    }

    // MARK: - Debug 行为开关

    /// DEBUG 下是否自动填充测试验证码
    ///
    /// - Returns: 默认 `true`；子类可覆写为 `false` 关闭
    var shouldAutoFillCodeInDebug: Bool {
        true
    }

    // MARK: - 通用提交（子类核心 API）

    /// 通用提交流程
    ///
    /// - Parameters:
    ///   - publisher: 请求 Publisher
    ///   - operationName: 操作名称（用于日志 / 错误提示，如 `L("登录")` / `L("注册")`）。
    ///                    **调用方应传入 `L(...)` 已本地化的字符串**
    ///   - onSuccess: 成功回调（在主线程执行，VC 存活时才会调用）
    func submit<T>(_ publisher: AnyPublisher<T, NetworkError>, operationName: String, onSuccess: @escaping (T) -> Void) {
        // 1. 防抖（静默——不提示用户"请勿重复点击"）
        guard !isLoading else {
            AppLog.auth.debug("\(operationName, privacy: .public)被拦截：已在加载中")
            return
        }

        // 2. 校验（提示用户——引导完善信息）
        guard canSubmit else {
            // 用格式化参数拼接——`Localizable.strings` 需包含 `"请完善%@信息"` 的翻译
            errorMessage = L("请完善%@信息", operationName)
            return
        }

        errorMessage = nil
        isLoading = true

        // 3. 取消旧请求 + 递增令牌
        currentSubmitRequest?.cancel()
        submitRequestToken &+= 1
        let token = submitRequestToken

        AppLog.auth.debug(
            "发起\(operationName, privacy: .public)：token=\(token, privacy: .public)"
        )

        // 4. 订阅
        currentSubmitRequest = publisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    // 令牌校验：丢弃过期回调
                    guard let self, self.submitRequestToken == token else {
                        AppLog.auth.debug(
                            "丢弃过期\(operationName, privacy: .public)回调 token=\(token, privacy: .public)"
                        )
                        return
                    }
                    self.isLoading = false
                    self.currentSubmitRequest = nil

                    if case .failure(let error) = completion {
                        if case .cancelled = error { return }
                        AppLog.auth.error(
                            "\(operationName, privacy: .public)失败：\(error.logCode, privacy: .public)"
                        )
                        // 兜底文案用格式化参数——`Localizable.strings` 需包含 `"%@失败"`
                        self.errorMessage = error.errorDescription
                            ?? L("%@失败", operationName)
                    }
                },
                receiveValue: { [weak self] value in
                    // 令牌校验：丢弃过期回调
                    guard let self, self.submitRequestToken == token else { return }
                    onSuccess(value)
                }
            )
    }

    // MARK: - 状态清理

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    /// 清除轻提示
    func clearToast() {
        toastMessage = nil
    }
}

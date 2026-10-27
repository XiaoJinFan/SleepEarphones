//
//  ChangeAccountViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/30.
//

import UIKit
import SnapKit
import Combine

/// 修改 / 绑定手机号或邮箱（通用页）
///
/// ## 四种模式
/// | Mode | 场景 | 流程 |
/// |---|---|---|
/// | `.changePhone` | 修改绑定手机号 | 验证旧手机 → 绑定新手机 |
/// | `.bindPhone`   | 首次绑定手机号 | 直接绑定新手机 |
/// | `.changeEmail` | 修改绑定邮箱 | 验证旧邮箱 → 绑定新邮箱 |
/// | `.bindEmail`   | 首次绑定邮箱 | 直接绑定新邮箱 |
///
/// ## 调用方法
/// ```swift
/// // 1. 修改绑定手机号（需要验证旧账号）
/// let vc = ChangeAccountViewController(mode: .changePhone)
/// navigationController?.pushViewController(vc, animated: true)
///
/// // 2. 首次绑定邮箱（跳过验证步骤）
/// let vc = ChangeAccountViewController(mode: .bindEmail)
/// navigationController?.pushViewController(vc, animated: true)
/// ```
@MainActor
final class ChangeAccountViewController: UIViewController {

    // MARK: - Mode

    /// 页面模式
    enum Mode {
        case changePhone
        case bindPhone
        case changeEmail
        case bindEmail

        /// 是否需要验证旧账号（Step 1）
        ///
        /// - Returns: `.change*` 返回 `true`；`.bind*` 返回 `false`
        var needsVerifyOld: Bool {
            switch self {
            case .changePhone, .changeEmail: return true
            case .bindPhone,   .bindEmail:   return false
            }
        }

        /// 账号类型（手机 / 邮箱）
        ///
        /// - Returns: `.phone` / `.email`
        var accountType: LoginAccountMode {
            switch self {
            case .changePhone, .bindPhone: return .phone
            case .changeEmail, .bindEmail: return .email
            }
        }

        /// 页面标题
        var title: String {
            switch self {
            case .changePhone: return "修改绑定手机号"
            case .bindPhone:   return "绑定新手机"
            case .changeEmail: return "修改绑定邮箱"
            case .bindEmail:   return "绑定新邮箱"
            }
        }

        /// 账号的中文显示名（用于 toast / hint 文案拼接）
        ///
        /// - Returns: `"手机号"` / `"邮箱"`
        var accountDisplayName: String {
            switch self {
            case .changePhone, .bindPhone: return "手机号"
            case .changeEmail, .bindEmail: return "邮箱"
            }
        }

        /// 新账号输入框的占位符
        ///
        /// - Returns: 如 `"请输入新的手机号"`
        var newAccountPlaceholder: String {
            switch self {
            case .changePhone, .bindPhone: return "请输入新的手机号"
            case .changeEmail, .bindEmail: return "请输入新的邮箱"
            }
        }

        /// Step 2 的顶部提示文案
        ///
        /// - Returns: 如 `"请输入新的手机号码："`
        var newStepHint: String {
            switch self {
            case .changePhone, .bindPhone: return "请输入新的手机号码："
            case .changeEmail, .bindEmail: return "请输入新的邮箱地址："
            }
        }
    }

    // MARK: - Steps

    /// 当前步骤
    private enum Step {
        /// Step 1：验证旧账号（仅 `change*` 需要）
        case verifyOld

        /// Step 2：绑定新账号
        case bindNew
    }

    // MARK: - Constants

    /// 等宽数字字体——**数字变化时宽度固定**，避免按钮内部抖动
    private static let countdownFont: UIFont = {
        let base = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        return UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: base)
    }()

    /// 倒计时按钮固定宽度
    private static let countdownButtonWidth: CGFloat = 100

    /// 验证码长度
    private static let codeLength = 4

    /// 倒计时总秒数
    private static let countdownSeconds = 60

    // MARK: - Properties

    private let mode: Mode
    private var currentStep: Step
    private let service: AccountSecurityServiceProtocol = AccountSecurityService()
    private var cancellables = Set<AnyCancellable>()

    /// Step 1（旧账号）的倒计时器
    private let oldCountdownTimer = CountdownTimer()

    /// Step 2（新账号）的倒计时器
    private let newCountdownTimer = CountdownTimer()

    // MARK: - UI

    /// 顶部提示文案
    private let hintLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Body.secondary
        l.textColor = AppColor.Text.secondary
        l.textAlignment = .left
        l.numberOfLines = 0
        return l
    }()

    // MARK: Step 1：旧账号验证

    /// 旧账号验证码输入框
    private lazy var oldCodeInput: CodeInputView = {
        CodeInputView(length: Self.codeLength)
    }()

    /// 旧账号"获取验证码"按钮
    ///
    /// - Note: 用 `.custom` + 等宽数字字体 + 固定宽度——
    ///         避免倒计时秒数变化时按钮内部宽度抖动。
    private lazy var oldGetCodeButton: UIButton = {
        let b = UIButton(type: .custom)
        b.setTitle("获取验证码", for: .normal)
        b.setTitleColor(AppColor.link, for: .normal)
        b.setTitleColor(AppColor.Text.tertiary, for: .disabled)
        b.titleLabel?.font = Self.countdownFont
        return b
    }()

    // MARK: Step 2：绑定新账号

    /// 新账号输入框
    private lazy var newAccountField: UITextField = {
        let tf = UITextField()
        tf.font = AppFont.Body.regular
        tf.textColor = AppColor.Text.primary
        tf.placeholder = mode.newAccountPlaceholder
        tf.clearButtonMode = .whileEditing
        tf.borderStyle = .roundedRect

        // 依账号类型配置键盘
        if mode.accountType == .phone {
            tf.keyboardType = .numberPad
            tf.textContentType = .telephoneNumber
        } else {
            tf.keyboardType = .emailAddress
            tf.textContentType = .emailAddress
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
        }
        return tf
    }()

    /// 新账号验证码输入框
    private lazy var newCodeField: UITextField = {
        let tf = UITextField()
        tf.font = AppFont.Body.regular
        tf.textColor = AppColor.Text.primary
        tf.placeholder = "请输入验证码"
        tf.keyboardType = .numberPad
        tf.textContentType = .oneTimeCode
        tf.clearButtonMode = .whileEditing
        tf.borderStyle = .roundedRect
        return tf
    }()

    /// 新账号"获取验证码"按钮（同 `oldGetCodeButton`）
    private lazy var newGetCodeButton: UIButton = {
        let b = UIButton(type: .custom)
        b.setTitle("获取验证码", for: .normal)
        b.setTitleColor(AppColor.link, for: .normal)
        b.setTitleColor(AppColor.Text.tertiary, for: .disabled)
        b.titleLabel?.font = Self.countdownFont
        return b
    }()

    // MARK: 用 stack 管理两组视图——isHidden 时自动塌陷

    /// Step 1 的组合栈（验证码输入框 + 获取按钮）
    private lazy var oldStepStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [oldCodeInput, oldGetCodeButton])
        s.axis = .vertical
        s.spacing = AppSpacing.lg
        s.alignment = .center
        return s
    }()

    /// Step 2 的验证码行（输入框 + 获取按钮，横向排列）
    private lazy var newCodeRowStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [newCodeField, newGetCodeButton])
        s.axis = .horizontal
        s.spacing = AppSpacing.sm
        s.alignment = .center
        return s
    }()

    /// Step 2 的组合栈（新账号 + 验证码行）
    private lazy var newStepStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [newAccountField, newCodeRowStack])
        s.axis = .vertical
        s.spacing = AppSpacing.lg
        s.alignment = .fill
        return s
    }()

    // MARK: 底部按钮

    /// 提交按钮（Step 1："下一步" / Step 2："完成"）
    private lazy var submitButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("下一步", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = AppFont.Button.primary
        b.backgroundColor = AppColor.Brand.primary
        b.layer.cornerRadius = AppSpacing.Corner.button
        b.clipsToBounds = true
        return b
    }()

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter mode: 页面模式（决定流程 / 标题 / 输入框配置）
    init(mode: Mode) {
        self.mode = mode
        // 依模式决定初始 Step：`change*` 从"验证旧账号"开始；`bind*` 直接进入"绑定新账号"
        self.currentStep = mode.needsVerifyOld ? .verifyOld : .bindNew
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        setupBinding()
        refreshUI()

        // `bind*` 模式：直接聚焦新账号输入框，减少一次点击
        if currentStep == .bindNew {
            newAccountField.becomeFirstResponder()
        }
    }

    // MARK: - Setup

    private func setupUI() {
        title = mode.title
        view.backgroundColor = AppColor.Background.primary
        navigationItem.backButtonDisplayMode = .minimal

        view.addSubview(hintLabel)
        view.addSubview(oldStepStack)
        view.addSubview(newStepStack)
        view.addSubview(submitButton)
    }

    private func setupConstraints() {
        hintLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(AppSpacing.lg)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
        }

        oldStepStack.snp.makeConstraints { make in
            make.top.equalTo(hintLabel.snp.bottom).offset(AppSpacing.xl)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
        }

        oldCodeInput.snp.makeConstraints { make in
            make.width.equalTo(CGFloat(Self.codeLength * 50 + (Self.codeLength - 1) * 12))
            make.height.equalTo(50)
        }

        // 给按钮固定宽度——标题变化不影响按钮宽度 → 不闪
        oldGetCodeButton.snp.makeConstraints { make in
            make.width.equalTo(Self.countdownButtonWidth)
            make.height.equalTo(30)
        }

        newStepStack.snp.makeConstraints { make in
            make.top.equalTo(hintLabel.snp.bottom).offset(AppSpacing.xl)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
        }

        newAccountField.snp.makeConstraints { make in
            make.height.equalTo(50)
        }
        newCodeField.snp.makeConstraints { make in
            make.height.equalTo(50)
        }

        newGetCodeButton.snp.makeConstraints { make in
            make.width.equalTo(Self.countdownButtonWidth)
            make.height.equalTo(30)
        }

        submitButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-AppSpacing.xxl)
            make.height.equalTo(46)
        }
    }

    private func setupActions() {
        oldGetCodeButton.addTarget(self, action: #selector(oldGetCodeTapped), for: .touchUpInside)
        newGetCodeButton.addTarget(self, action: #selector(newGetCodeTapped), for: .touchUpInside)
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)

        // 验证码输入完成不做自动提交——保持用户主动点击"下一步"的节奏，
        // 用户可核对后再提交，避免误操作。
    }

    /// 绑定两个倒计时器到按钮刷新
    private func setupBinding() {
        oldCountdownTimer.$remaining
            .receive(on: DispatchQueue.main)
            .sink { [weak self] seconds in
                guard let self else { return }
                self.refreshCountdownButton(self.oldGetCodeButton, seconds: seconds)
            }
            .store(in: &cancellables)

        newCountdownTimer.$remaining
            .receive(on: DispatchQueue.main)
            .sink { [weak self] seconds in
                guard let self else { return }
                self.refreshCountdownButton(self.newGetCodeButton, seconds: seconds)
            }
            .store(in: &cancellables)
    }

    // MARK: - UI Refresh

    /// 根据当前 Step 刷新 UI（提示文案 / 视图显隐 / 按钮标题）
    private func refreshUI() {
        switch currentStep {
        case .verifyOld:
            hintLabel.text = "为保障账号安全，请验证当前绑定的\(mode.accountDisplayName)："
            oldStepStack.isHidden = false
            newStepStack.isHidden = true
            submitButton.setTitle("下一步", for: .normal)
            oldCodeInput.clear()

        case .bindNew:
            hintLabel.text = mode.newStepHint
            oldStepStack.isHidden = true
            newStepStack.isHidden = false
            submitButton.setTitle("完成", for: .normal)
        }
    }

    /// 刷新倒计时按钮（标题 + 可用性）
    ///
    /// - Parameters:
    ///   - button: 目标按钮（`oldGetCodeButton` / `newGetCodeButton`）
    ///   - seconds: 剩余秒数（`0` 表示可再次点击）
    ///
    /// ## 优化要点
    /// - **只在状态真正变化时更新**——避免每秒重复 `setTitle` / `isEnabled`
    private func refreshCountdownButton(_ button: UIButton, seconds: Int) {
        let isCountingDown = seconds > 0
        let newTitle = isCountingDown ? "\(seconds) s" : "获取验证码"
        let shouldEnable = !isCountingDown

        if button.title(for: .normal) != newTitle {
            button.setTitle(newTitle, for: .normal)
        }
        if button.isEnabled != shouldEnable {
            button.isEnabled = shouldEnable
        }
    }

    // MARK: - Actions

    /// Step 1："获取验证码"（发送给旧账号）
    ///
    /// - Note: 用 `timer.isRunning` 替代缓存的秒数——语义等价且无需额外字段。
    @objc private func oldGetCodeTapped() {
        guard !oldCountdownTimer.isRunning else { return }

        guard let account = oldAccountString() else {
            showToast("未获取到当前绑定的\(mode.accountDisplayName)，请稍后重试")
            return
        }

        // Step 1 不带 userId
        sendVerifyCode(
            account: account,
            userId: nil,
            timer: oldCountdownTimer
        )
    }

    /// Step 2："获取验证码"（发送给新账号）
    @objc private func newGetCodeTapped() {
        guard !newCountdownTimer.isRunning else { return }

        let account = (newAccountField.text ?? "").trimmingCharacters(in: .whitespaces)
        guard !account.isEmpty else {
            showToast("请输入新\(mode.accountDisplayName)")
            return
        }

        guard isValidAccount(account) else {
            showToast("\(mode.accountDisplayName)格式不正确")
            return
        }

        // Step 2 带 userId（后端据此识别当前登录用户）
        let userIdString: String? = AuthStore.shared.userId > 0
            ? "\(AuthStore.shared.userId)"
            : nil

        sendVerifyCode(
            account: account,
            userId: userIdString,
            timer: newCountdownTimer
        )
    }

    /// 提交按钮点击（依 Step 分派）
    @objc private func submitTapped() {
        view.endEditing(true)
        switch currentStep {
        case .verifyOld: verifyOldCode()
        case .bindNew:   bindNewAccount()
        }
    }

    // MARK: - Send Verify Code（公共）

    /// 发送验证码（Step 1 / Step 2 共用）
    ///
    /// - Parameters:
    ///   - account: 接收验证码的手机号 / 邮箱
    ///   - userId: 用户 ID；`nil` 表示 Step 1（不带）
    ///   - timer: 成功后启动的倒计时器（旧账号 / 新账号各一个）
    private func sendVerifyCode(account: String, userId: String?, timer: CountdownTimer) {
        service.sendCode(
            account: account,
            accountType: mode.accountType.accountType,
            scene: .changePhone,
            userId: userId
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    if case .cancelled = error { return }
                    self?.showToast(error.errorDescription ?? "发送失败")
                }
            },
            receiveValue: { [weak self] _ in
                guard let self else { return }
                self.showToast("验证码已发送")
                timer.start(seconds: Self.countdownSeconds)
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - Step 1

    /// 校验旧账号验证码，通过后切换到 Step 2
    private func verifyOldCode() {
        let code = oldCodeInput.code
        guard code.count == Self.codeLength else {
            showToast("请输入 \(Self.codeLength) 位验证码")
            return
        }

        guard let account = oldAccountString() else {
            showToast("未获取到当前绑定的账号")
            return
        }

        submitButton.isEnabled = false
        submitButton.alpha = 0.6

        service.checkCode(
            account: account,
            accountType: mode.accountType.accountType,
            code: code,
            scene: .changePhone
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                guard let self else { return }
                self.submitButton.isEnabled = true
                self.submitButton.alpha = 1.0

                if case .failure(let error) = completion {
                    if case .cancelled = error { return }
                    self.showToast(error.errorDescription ?? "验证码错误")
                }
            },
            receiveValue: { [weak self] _ in
                guard let self else { return }
                AppLog.profile.debug("旧账号验证通过")

                // 旧账号验证通过 → 停止旧账号倒计时
                // （用户已无需再获取旧账号验证码）
                self.oldCountdownTimer.cancel()

                // 切换到 Step 2 时清空新账号相关字段，避免残留
                self.newAccountField.text = ""
                self.newCodeField.text = ""

                self.currentStep = .bindNew
                self.refreshUI()
                self.newAccountField.becomeFirstResponder()
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - Step 2

    /// 校验新账号 + 验证码，提交绑定请求
    private func bindNewAccount() {
        let newAccount = (newAccountField.text ?? "").trimmingCharacters(in: .whitespaces)
        let newCode = (newCodeField.text ?? "").trimmingCharacters(in: .whitespaces)

        guard !newAccount.isEmpty else {
            showToast("请输入新\(mode.accountDisplayName)")
            return
        }

        guard isValidAccount(newAccount) else {
            showToast("\(mode.accountDisplayName)格式不正确")
            return
        }

        guard newCode.count == Self.codeLength else {
            showToast("请输入 \(Self.codeLength) 位验证码")
            return
        }

        submitButton.isEnabled = false
        submitButton.alpha = 0.6

        // 依模式选择提交接口
        //
        // - Note: 后端 `edit_mobile` / `edit_email` 不区分"首次绑定"与"修改"，
        //         因此 `changePhone` / `bindPhone` 调用的是**同一后端接口**，
        //         只有前端 case 不同（语义 / 日志可区分）。
        let publisher: AnyPublisher<Void, NetworkError>
        switch mode {
        case .changePhone:
            publisher = service.changePhone(newPhone: newAccount, newCode: newCode)
        case .bindPhone:
            publisher = service.bindPhone(newPhone: newAccount, newCode: newCode)
        case .changeEmail:
            publisher = service.changeEmail(newEmail: newAccount, newCode: newCode)
        case .bindEmail:
            publisher = service.bindEmail(newEmail: newAccount, newCode: newCode)
        }

        publisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.submitButton.isEnabled = true
                    self.submitButton.alpha = 1.0

                    if case .failure(let error) = completion {
                        if case .cancelled = error { return }
                        AppLog.profile.error("绑定失败：\(error.logCode, privacy: .public)")
                        self.showToast(error.errorDescription ?? "操作失败")
                    }
                },
                receiveValue: { [weak self] _ in
                    guard let self else { return }
                    AppLog.profile.debug("绑定成功")
                    self.handleBindSuccess(newAccount: newAccount)
                }
            )
            .store(in: &cancellables)
    }

    /// 绑定成功后的统一处理
    ///
    /// - Parameter newAccount: 用户新输入的账号（手机号 / 邮箱）
    ///
    /// ## 行为
    /// 1. 显示 Toast
    /// 2. 更新 `AuthStore` 中的真实账号缓存
    /// 3. 停止新账号倒计时
    /// 4. 延时 pop 回上一页（**带栈顶检查**）
    private func handleBindSuccess(newAccount: String) {
        showToast(mode.accountType == .phone ? "手机号更新成功" : "邮箱更新成功")

        // 更新本地缓存——供后续"账号与安全"页发送验证码使用
        if mode.accountType == .phone {
            AuthStore.shared.updateRealAccount(realMobile: newAccount, realEmail: nil)
        } else {
            AuthStore.shared.updateRealAccount(realMobile: nil, realEmail: newAccount)
        }

        // 停止倒计时（页面即将销毁，但保险起见主动 cancel）
        newCountdownTimer.cancel()

        // 延时 pop 前**必须**检查当前 VC 仍是栈顶——
        // 若用户在 0.8s 延时期间手动返回，直接 `popViewController`
        // 会**误弹上一层 VC**（用户看到"连跳两级"的错乱）。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            guard self.navigationController?.viewControllers.last === self else {
                AppLog.profile.debug("延时 pop 时 VC 已不在栈顶，跳过")
                return
            }
            self.navigationController?.popViewController(animated: true)
        }
    }

    // MARK: - Helper

    /// 获取当前绑定的旧账号（手机号 / 邮箱）
    ///
    /// - Returns: 旧账号字符串；未缓存时返回 `nil`
    ///
    /// - Note: 数据来源为 `AuthStore.realMobile` / `realEmail`——
    ///         由 `UserProfileViewModel.refresh()` 从 `user/get_user_info`
    ///         拉取后写入。若用户进入本页过快（refresh 未完成），可能返回 nil，
    ///         此时提示用户"请稍后重试"。
    private func oldAccountString() -> String? {
        switch mode.accountType {
        case .phone: return AuthStore.shared.realMobile
        case .email: return AuthStore.shared.realEmail
        }
    }

    /// 校验账号格式（依类型分派）
    ///
    /// - Parameter account: 待校验账号
    /// - Returns: 格式是否合法
    private func isValidAccount(_ account: String) -> Bool {
        switch mode.accountType {
        case .phone: return AccountInputValidator.isValidPhone(account)
        case .email: return AccountInputValidator.isValidEmail(account)
        }
    }
}

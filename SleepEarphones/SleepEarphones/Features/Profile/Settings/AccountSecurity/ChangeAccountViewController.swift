//
//  ChangeAccountViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/30.
//

import UIKit
import SnapKit
import Combine


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

        /// 页面标题（**已本地化**）
        var title: String {
            switch self {
            case .changePhone: return LN("修改绑定手机号")
            case .bindPhone:   return LN("绑定新手机")
            case .changeEmail: return LN("修改绑定邮箱")
            case .bindEmail:   return LN("绑定新邮箱")
            }
        }

        /// 账号的中文显示名（用于 toast / hint 文案拼接，**已本地化**）
        ///
        /// - Returns: `"手机号"` / `"邮箱"`
        ///
        /// - Note: `"邮箱"` 需要单独的 key——`Localizable.json` 中
        ///         目前有 `"邮箱号"` / `"邮箱账号"`，需补充 `"邮箱"`
        var accountDisplayName: String {
            switch self {
            case .changePhone, .bindPhone: return LN("手机号")
            case .changeEmail, .bindEmail: return LN("邮箱")
            }
        }

        /// 新账号输入框的占位符（**已本地化**）
        ///
        /// - Returns: 如 `"请输入新的手机号"`
        var newAccountPlaceholder: String {
            switch self {
            case .changePhone, .bindPhone: return LN("请输入新的手机号")
            case .changeEmail, .bindEmail: return LN("请输入新的邮箱")
            }
        }

        /// Step 2 的顶部提示文案（**已本地化**）
        ///
        /// - Returns: 如 `"请输入新的手机号码："`
        var newStepHint: String {
            switch self {
            case .changePhone, .bindPhone: return LN("请输入新的手机号码：")
            case .changeEmail, .bindEmail: return LN("请输入新的邮箱地址：")
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

    /// 验证码长度（业务约束：4 位）
    private static let codeLength = 4

    /// 倒计时总秒数
    private static let countdownSeconds = 60

    /// 绑定成功后的延时 pop（秒）
    private static let successPopDelay: TimeInterval = 0.8

    // MARK: - Layout

    private enum Layout {
        static let hintTopInset: CGFloat = AppSpacing.lg
        static let horizontalInset: CGFloat = AppSpacing.lg
        static let hintToStackSpacing: CGFloat = AppSpacing.xl
        static let stackSpacing: CGFloat = AppSpacing.lg
        static let textFieldHeight: CGFloat = 50
        static let countdownButtonHeight: CGFloat = 30
        static let submitBottomInset: CGFloat = AppSpacing.xxl
        static let submitHeight: CGFloat = 46
        static let oldCodeFieldHeight: CGFloat = 50
        static let oldCodeFieldWidth: CGFloat = 236
    }

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

    /// 旧账号验证码输入框（4 位方框样式）
    private lazy var oldCodeInput: CodeInputView = {
        CodeInputView(length: Self.codeLength)
    }()

    /// 旧账号"获取验证码"按钮
    private lazy var oldGetCodeButton: UIButton = {
        let b = UIButton(type: .custom)
        // **标题已本地化**
        b.setTitle(L("获取验证码"), for: .normal)
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
        // **占位符来自 Mode（已本地化）**
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

    /// 新账号验证码输入框（普通样式）
    private lazy var newCodeField: UITextField = {
        let tf = UITextField()
        tf.font = AppFont.Body.regular
        tf.textColor = AppColor.Text.primary
        // **占位符已本地化**
        tf.placeholder = L("请输入验证码")
        tf.keyboardType = .numberPad
        tf.textContentType = .oneTimeCode
        tf.clearButtonMode = .whileEditing
        tf.borderStyle = .roundedRect
        return tf
    }()

    /// 新账号"获取验证码"按钮（同 `oldGetCodeButton`）
    private lazy var newGetCodeButton: UIButton = {
        let b = UIButton(type: .custom)
        // **标题已本地化**
        b.setTitle(L("获取验证码"), for: .normal)
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
        s.spacing = Layout.stackSpacing
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
        s.spacing = Layout.stackSpacing
        s.alignment = .fill
        return s
    }()

    // MARK: 底部按钮

    /// 提交按钮（Step 1：`"下一步"` / Step 2：`"完成"`）
    private lazy var submitButton: UIButton = {
        let b = UIButton(type: .system)
        // 初始标题（**已本地化**）——`refreshUI` 会动态覆盖
        b.setTitle(L("下一步"), for: .normal)
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
        // **导航标题来自 Mode（已本地化）**
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
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
                .offset(Layout.hintTopInset)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        oldStepStack.snp.makeConstraints { make in
            make.top.equalTo(hintLabel.snp.bottom)
                .offset(Layout.hintToStackSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        oldCodeInput.snp.makeConstraints { make in
            make.width.equalTo(Layout.oldCodeFieldWidth)
            make.height.equalTo(Layout.oldCodeFieldHeight)
        }

        // 给按钮固定宽度——标题变化不影响按钮宽度 → 不闪
        oldGetCodeButton.snp.makeConstraints { make in
            make.width.equalTo(Self.countdownButtonWidth)
            make.height.equalTo(Layout.countdownButtonHeight)
        }

        newStepStack.snp.makeConstraints { make in
            make.top.equalTo(hintLabel.snp.bottom)
                .offset(Layout.hintToStackSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        newAccountField.snp.makeConstraints { make in
            make.height.equalTo(Layout.textFieldHeight)
        }
        newCodeField.snp.makeConstraints { make in
            make.height.equalTo(Layout.textFieldHeight)
        }

        newGetCodeButton.snp.makeConstraints { make in
            make.width.equalTo(Self.countdownButtonWidth)
            make.height.equalTo(Layout.countdownButtonHeight)
        }

        submitButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
                .offset(-Layout.submitBottomInset)
            make.height.equalTo(Layout.submitHeight)
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
            // **Hint 用 `%@` 格式化**——`mode.accountDisplayName` 已本地化
            hintLabel.text = L("请验证当前绑定的%@：", mode.accountDisplayName)
            oldStepStack.isHidden = false
            newStepStack.isHidden = true
            submitButton.setTitle(L("下一步"), for: .normal)
            oldCodeInput.clear()

        case .bindNew:
            // **Hint 来自 Mode（已本地化）**
            hintLabel.text = mode.newStepHint
            oldStepStack.isHidden = true
            newStepStack.isHidden = false
            submitButton.setTitle(L("完成"), for: .normal)
        }
    }

    /// 刷新倒计时按钮（标题 + 可用性）
    ///
    /// - Parameters:
    ///   - button: 目标按钮（`oldGetCodeButton` / `newGetCodeButton`）
    ///   - seconds: 剩余秒数（`0` 表示可再次点击）
    private func refreshCountdownButton(_ button: UIButton, seconds: Int) {
        let isCountingDown = seconds > 0
        // **标题已本地化**
        let newTitle = isCountingDown ? L("%lld s", seconds) : L("获取验证码")
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
    @objc private func oldGetCodeTapped() {
        guard !oldCountdownTimer.isRunning else { return }

        guard let account = oldAccountString() else {
            // **提示已本地化**
            showToast(L("未获取到当前绑定的%@，请稍后重试", mode.accountDisplayName))
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
            // **提示已本地化**
            showToast(L("请输入新%@", mode.accountDisplayName))
            return
        }

        guard isValidAccount(account) else {
            // **提示已本地化**
            showToast(L("%@格式不正确", mode.accountDisplayName))
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
            scene: .changePhone,   // 见方法注释的"关于 scene 参数"
            userId: userId
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    if case .cancelled = error { return }
                    // `error.errorDescription` 已本地化（来自 `NetworkError`）
                    self?.showToast(error.errorDescription ?? L("发送失败"))
                }
            },
            receiveValue: { [weak self] _ in
                guard let self else { return }
                // **提示已本地化**
                self.showToast(L("验证码已发送"))
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
            // **提示已本地化**
            showToast(L("请输入 %lld 位验证码", Self.codeLength))
            return
        }

        guard let account = oldAccountString() else {
            showToast(L("未获取到当前绑定的账号"))
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
                    // `error.errorDescription` 已本地化（来自 `NetworkError`）
                    self.showToast(error.errorDescription ?? L("验证码错误"))
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
            showToast(L("请输入新%@", mode.accountDisplayName))
            return
        }

        guard isValidAccount(newAccount) else {
            showToast(L("%@格式不正确", mode.accountDisplayName))
            return
        }

        guard newCode.count == Self.codeLength else {
            showToast(L("请输入 %lld 位验证码", Self.codeLength))
            return
        }

        submitButton.isEnabled = false
        submitButton.alpha = 0.6

        // 依模式选择提交接口
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
                        // `error.errorDescription` 已本地化
                        self.showToast(error.errorDescription ?? L("操作失败"))
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
    private func handleBindSuccess(newAccount: String) {
        // **提示已本地化**
        showToast(
            mode.accountType == .phone
                ? L("手机号更新成功")
                : L("邮箱更新成功")
        )

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
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.successPopDelay) { [weak self] in
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

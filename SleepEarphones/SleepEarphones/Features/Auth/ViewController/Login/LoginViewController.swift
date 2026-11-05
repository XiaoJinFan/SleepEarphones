//
//  LoginViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/16.
//

import UIKit
import Combine

/// 登录页
///
/// ## 职责
/// - 手机号 / 邮箱登录（`segmentControl` 切换）
/// - 验证码 / 密码登录方式切换（`loginTypeBtn`）
/// - 三方登录入口（游客 / 微信 / Apple）
/// - 隐私协议勾选（未勾选时拦截登录）
/// - 注册 / 找回密码入口
///
/// ## 导航栏控制
/// - **作为 Tab 根之外的 push 页**：隐藏导航栏（本页是沉浸式设计，无返回按钮）
/// - **push 到注册 / 找回密码后**：显示导航栏（让这两页有返回按钮）
/// - **pop 回登录页后**：再次隐藏导航栏（`viewWillAppear` 中恢复）
@MainActor
final class LoginViewController: UIViewController {

    // MARK: - IBOutlet

    /// 登录类型选择---手机号/邮箱
    @IBOutlet weak var segmentControl: UISegmentedControl!

    /// 承载「手机/邮箱」+「验证码/密码」四个输入区的垂直 stackView
    @IBOutlet weak var containerStack: UIStackView!

    /// 手机登录
    @IBOutlet weak var phoneLoginView: UIView!
    @IBOutlet weak var phoneTextField: UITextField!

    /// 邮箱登录
    @IBOutlet weak var emailLoginView: UIView!
    @IBOutlet weak var emailTextField: UITextField!

    /// 登录方式：验证码
    @IBOutlet weak var codeView: UIView!
    @IBOutlet weak var codeTextField: UITextField!
    @IBOutlet weak var getCodeBtn: UIButton!

    /// 登录方式：密码
    @IBOutlet weak var passwordView: UIView!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var passwordVisibleBtn: UIButton!

    /// 切换登录方式：验证码/密码
    @IBOutlet weak var loginTypeBtn: UIButton!

    /// 登录按钮
    @IBOutlet weak var loginBtn: UIButton!

    /// 注册按钮
    @IBOutlet weak var registerBtn: UIButton!

    /// 忘记密码按钮
    @IBOutlet weak var forgetPwdBtn: UIButton!

    /// 三方登录：游客登录
    @IBOutlet weak var guestLoginBtn: UIButton!

    /// 三方登录：微信登录
    @IBOutlet weak var weChatLoginBtn: UIButton!

    /// 三方登录：Apple登录
    @IBOutlet weak var appleLoginBtn: UIButton!

    /// 隐私协议同意框
    @IBOutlet weak var agreePrivacyBtn: UIButton!

    /// 隐私协议文本内容
    @IBOutlet weak var privacyTextView: UITextView!

    // MARK: - Constants

    /// Storyboard 名称与 VC 标识符
    private enum StoryboardIDs {
        static let register       = "RegistViewController"
        static let forgetPassword = "ForgetPassWordController"
    }

    // MARK: - Properties

    private let viewModel = LoginViewModel()
    private var cancellables = Set<AnyCancellable>()

    /// 协议链接点击处理器
    private let agreementHandler = AgreementTextViewHandler()

    /// 隐私协议是否已同意
    private var isPrivacyAgreed = false {
        didSet {
            guard isPrivacyAgreed != oldValue else { return }
            refreshAuthPrivacyButton(isAgreed: isPrivacyAgreed)
        }
    }

    /// 登录成功回调（由外部注入时优先，否则走 AppRouter）
    var onLoginSuccess: (() -> Void)?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureAuthPrivacyTextView(delegate: agreementHandler)
        bindTextFields()
        bindViewModel()
    }

    /// 登录页隐藏导航栏
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 恢复导航栏，让 push 的注册 / 找回密码页有返回按钮
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Setup

    /// 配置 UI
    private func setupUI() {
        // MARK: Segment 标题（覆盖 storyboard 中的 "手机号码登录" / "邮箱账号登录"）
        segmentControl.setTitle(LoginAccountMode.phone.title, forSegmentAt: 0)
        segmentControl.setTitle(LoginAccountMode.email.title, forSegmentAt: 1)

        // MARK: 输入框占位符（覆盖 storyboard 中的硬编码）
        phoneTextField.placeholder = LoginAccountMode.phone.placeholder
        emailTextField.placeholder = LoginAccountMode.email.placeholder
        codeTextField.placeholder = L("请输入验证码")
        passwordTextField.placeholder = L("请输入密码(6~12位字母+数字)")

        // MARK: 按钮标题（覆盖 storyboard 中的硬编码）
        loginBtn.setTitle(L("登录"), for: .normal)
        registerBtn.setTitle(L("注册账号"), for: .normal)
        forgetPwdBtn.setTitle(L("找回密码"), for: .normal)
        getCodeBtn.setTitle(L("获取验证码"), for: .normal)

        // MARK: 三方登录按钮（覆盖 storyboard 中的硬编码）
        updateThirdPartyButtonTitle(guestLoginBtn, title: L("游客登录"))
        updateThirdPartyButtonTitle(weChatLoginBtn, title: L("微信登录"))
        updateThirdPartyButtonTitle(appleLoginBtn, title: L("苹果登录"))

        // MARK: 键盘配置（用扩展统一）
        applyAuthKeyboard(to: phoneTextField, mode: .phone)
        applyAuthKeyboard(to: emailTextField, mode: .email)
        codeTextField.keyboardType = .numberPad

        loginBtn.layer.cornerRadius = AppSpacing.Corner.card

        // 密码默认隐藏
        passwordTextField.isSecureTextEntry = true
        passwordVisibleBtn.setImage(AppImage.System.eyeSlashFill, for: .normal)

        // segmentControl 默认选中手机号
        segmentControl.selectedSegmentIndex = LoginAccountMode.phone.rawValue

        // 隐私协议默认未勾选
        refreshAuthPrivacyButton(isAgreed: false)

        // 登录方式按钮标题（初值，由 VM 的 switchButtonTitle 驱动）
        loginTypeBtn.setTitle(viewModel.loginMethod.switchButtonTitle, for: .normal)

        // 让重叠的手机/邮箱、验证码/密码视图先同步一次初始状态
        syncUIWithViewModel(animated: false)
    }

    /// 更新三方登录按钮的标题（保留 storyboard 中的图片配置）
    ///
    /// - Parameters:
    ///   - button: 三方登录按钮
    ///   - title: 已本地化的标题
    private func updateThirdPartyButtonTitle(_ button: UIButton, title: String) {
        guard var config = button.configuration else {
            // 兜底：若按钮没有 Configuration（极端情况），用传统方式设置
            button.setTitle(title, for: .normal)
            return
        }
        var attr = AttributedString(title)
        // 保留原字体（若 storyboard 已设置 pointSize，则读取之）
        attr.font = config.attributedTitle?.font ?? UIFont.systemFont(ofSize: 15)
        config.attributedTitle = attr
        button.configuration = config
    }

    private func bindTextFields() {
        phoneTextField.addTarget(self, action: #selector(phoneChanged), for: .editingChanged)
        emailTextField.addTarget(self, action: #selector(emailChanged), for: .editingChanged)
        passwordTextField.addTarget(self, action: #selector(passwordChanged), for: .editingChanged)
        codeTextField.addTarget(self, action: #selector(codeChanged), for: .editingChanged)
    }

    // MARK: - Binding

    private func bindViewModel() {
        // 账号模式 / 登录方式变化 → 刷新 UI
        viewModel.$accountMode
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                AppLog.auth.debug("accountMode 变化 → 刷新 UI")
                self?.syncUIWithViewModel(animated: true)
            }
            .store(in: &cancellables)

        // MARK: 登录方式变化（按钮标题 + 视图显隐）
        viewModel.$loginMethod
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] method in
                guard let self else { return }
                AppLog.auth.debug("loginMethod 变化 → \(method.description, privacy: .public)")
                // `switchButtonTitle` 已本地化——VM 层通过 `L(...)` 返回
                self.loginTypeBtn.setTitle(method.switchButtonTitle, for: .normal)
                self.syncUIWithViewModel(animated: true)
            }
            .store(in: &cancellables)

        // MARK: 提交中：禁用登录按钮
        viewModel.$isLoading
            .sink { [weak self] isLoading in
                guard let self else { return }
                self.loginBtn.isEnabled = !isLoading
                self.loginBtn.alpha = isLoading ? 0.6 : 1.0
            }
            .store(in: &cancellables)

        // MARK: 验证码按钮
        viewModel.$isSendingCode
            .combineLatest(viewModel.$countdown)
            .sink { [weak self] isSending, sec in
                self?.refreshAuthGetCodeButton(isSending: isSending, countdown: sec)
            }
            .store(in: &cancellables)

        // MARK: 错误提示
        viewModel.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] msg in
                self?.showAlert(msg)
                self?.viewModel.clearError()
            }
            .store(in: &cancellables)

        // MARK: 轻提示
        viewModel.$toastMessage
            .compactMap { $0 }
            .sink { [weak self] msg in
                self?.showToast(msg)
                self?.viewModel.clearToast()
            }
            .store(in: &cancellables)

        // MARK: 登录成功
        viewModel.$loginSuccess
            .filter { $0 }
            .sink { [weak self] _ in
                self?.handleLoginSuccess()
            }
            .store(in: &cancellables)
    }

    // MARK: - UI 同步

    /// 根据 ViewModel 状态刷新 UI 可见性
    ///
    /// ## 两个维度独立
    /// - `accountMode`（手机 / 邮箱）控制 `phoneLoginView` / `emailLoginView` 显隐
    /// - `loginMethod`（验证码 / 密码）控制 `codeView` / `passwordView` 显隐
    ///
    /// - Parameter animated: 是否使用淡入淡出过渡（初次同步传 `false`）
    private func syncUIWithViewModel(animated: Bool) {
        let isPhone    = (viewModel.accountMode == .phone)
        let isCodeMode = (viewModel.loginMethod == .code)

        // segment 状态同步（用扩展）
        syncAuthSegment(segmentControl, with: viewModel)

        let changes = {
            self.phoneLoginView.isHidden  = !isPhone
            self.emailLoginView.isHidden  = isPhone
            self.codeView.isHidden        = !isCodeMode
            self.passwordView.isHidden    = isCodeMode
        }

        guard animated, let hostView = containerStack else {
            changes()
            return
        }

        UIView.transition(
            with: hostView,
            duration: AppSpacing.Animation.quick,
            options: [.transitionCrossDissolve, .allowUserInteraction, .beginFromCurrentState],
            animations: changes
        )
    }

    // MARK: - TextField 事件

    @objc private func phoneChanged()    { viewModel.phone = phoneTextField.text ?? "" }
    @objc private func emailChanged()    { viewModel.email = emailTextField.text ?? "" }
    @objc private func passwordChanged() { viewModel.password = passwordTextField.text ?? "" }
    @objc private func codeChanged()     { viewModel.code = codeTextField.text ?? "" }

    // MARK: - IBActions

    /// segmentControl 切换：手机号 / 邮箱
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        let mode = LoginAccountMode(rawValue: sender.selectedSegmentIndex) ?? .phone
        viewModel.switchAccountMode(mode)
    }

    /// 切换验证码登录 / 密码登录
    @IBAction func loginTypeTapped(_ sender: UIButton) {
        view.endEditing(true)
        viewModel.toggleLoginMethod()
    }

    /// 获取验证码
    @IBAction func getCodeTapped(_ sender: UIButton) {
        view.endEditing(true)
        viewModel.sendSmsCode(scene: .smsLogin)
    }

    /// 密码可见性切换（用扩展）
    @IBAction func togglePasswordVisibility(_ sender: UIButton) {
        toggleAuthPasswordVisibility()
    }

    /// 点击登录
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        view.endEditing(true)
        guard isPrivacyAgreed else {
            showToast(L("请先阅读并同意《用户注册协议》与《隐私政策》"))
            return
        }
        viewModel.login()
    }

    /// 跳注册
    @IBAction func registerAccountEvent(_ sender: UIButton) {
        let sb = UIStoryboard(name: StoryboardIDs.register, bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: StoryboardIDs.register)
        navigationController?.pushViewController(vc, animated: true)
        AppLog.auth.debug("跳转注册页")
    }

    /// 跳忘记密码
    @IBAction func forgetPasswordEvent(_ sender: UIButton) {
        let sb = UIStoryboard(name: StoryboardIDs.forgetPassword, bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: StoryboardIDs.forgetPassword)
        navigationController?.pushViewController(vc, animated: true)
        AppLog.auth.debug("跳转忘记密码页")
    }

    /// 隐私协议勾选
    @IBAction func agreePrivacyTapped(_ sender: UIButton) {
        isPrivacyAgreed.toggle()
    }

    // MARK: - 登录成功

    /// 处理登录成功
    private func handleLoginSuccess() {
        AppLog.auth.debug("登录成功，处理导航")
        view.endEditing(true)
        if let onLoginSuccess {
            onLoginSuccess()
        } else {
            AppRouter.shared.switchToMain(animated: true)
        }
    }
}

// MARK: - AuthFormViewControllerProtocol

extension LoginViewController: AuthFormViewControllerProtocol {

    var authPrivacyTextView: UITextView! { privacyTextView }
    var authPrivacyButton: UIButton! { agreePrivacyBtn }
    var authGetCodeButton: UIButton! { getCodeBtn }
    var authPasswordTextField: UITextField! { passwordTextField }
    var authPasswordVisibilityButton: UIButton! { passwordVisibleBtn }
}

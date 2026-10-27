//
//  ForgetPassWordController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/16.
//

import UIKit
import Combine

/// 找回密码页
@MainActor
final class ForgetPassWordController: UIViewController {

    // MARK: - IBOutlet

    /// 找回密码类型选择---手机号/邮箱
    @IBOutlet weak var segmentControl: UISegmentedControl!

    /// 承载四个输入区的垂直 stackView
    @IBOutlet weak var forgetContainerStack: UIStackView!

    /// 手机号找回密码
    @IBOutlet weak var phoneForgetView: UIView!
    @IBOutlet weak var phoneTextField: UITextField!

    /// 邮箱号找回密码
    @IBOutlet weak var emailForgetView: UIView!
    @IBOutlet weak var emailTextField: UITextField!

    /// 找回密码：验证码校验
    @IBOutlet weak var codeView: UIView!
    @IBOutlet weak var codeTextField: UITextField!
    @IBOutlet weak var getCodeBtn: UIButton!

    /// 找回密码：重设密码
    @IBOutlet weak var passwordView: UIView!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var passwordVisibleBtn: UIButton!

    /// 找回密码按钮
    @IBOutlet weak var forgetPwdBtn: UIButton!

    /// 隐私协议同意框
    @IBOutlet weak var agreePrivacyBtn: UIButton!

    /// 隐私协议文本内容
    @IBOutlet weak var privacyTextView: UITextView!

    // MARK: - Properties

    private let viewModel = ForgetPasswordViewModel()
    private var cancellables = Set<AnyCancellable>()

    /// 协议链接点击处理器
    ///
    /// - Note: 与登录 / 注册页共用 `AgreementTextViewHandler`——
    ///         它已处理 iOS 17 前后的回调差异，本页无需重复实现。
    private let agreementHandler = AgreementTextViewHandler()

    /// 隐私协议是否已同意
    private var isPrivacyAgreed = false {
        didSet {
            guard isPrivacyAgreed != oldValue else { return }
            refreshAuthPrivacyButton(isAgreed: isPrivacyAgreed)
        }
    }

    // MARK: - Init

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        // 保持与 App 内其他详情页一致——从任何入口 push 都自动隐藏 tabBar
        self.hidesBottomBarWhenPushed = true
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureAuthPrivacyTextView(delegate: agreementHandler)
        bindTextFields()
        bindViewModel()
        syncUIWithViewModel(animated: false)
    }

    // MARK: - Setup

    private func setupUI() {
        title = "找回密码"

        // 用扩展统一配置键盘
        applyAuthKeyboard(to: phoneTextField, mode: .phone)
        applyAuthKeyboard(to: emailTextField, mode: .email)
        codeTextField.keyboardType = .numberPad

        // 密码默认隐藏
        passwordTextField.isSecureTextEntry = true
        passwordVisibleBtn.setImage(AppImage.System.eyeSlashFill, for: .normal)

        // segmentControl 默认选中手机号
        segmentControl.selectedSegmentIndex = LoginAccountMode.phone.rawValue

        // 隐私协议默认未勾选
        refreshAuthPrivacyButton(isAgreed: false)
    }

    private func bindTextFields() {
        phoneTextField.addTarget(self, action: #selector(phoneChanged), for: .editingChanged)
        emailTextField.addTarget(self, action: #selector(emailChanged), for: .editingChanged)
        codeTextField.addTarget(self, action: #selector(codeChanged), for: .editingChanged)
        passwordTextField.addTarget(self, action: #selector(passwordChanged), for: .editingChanged)
    }

    // MARK: - Binding

    private func bindViewModel() {
        // 账号模式变化 → 切换视图
        viewModel.$accountMode
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                AppLog.auth.debug("accountMode 变化 → 刷新 UI")
                self?.syncUIWithViewModel(animated: true)
            }
            .store(in: &cancellables)
        
        // 验证码按钮
        viewModel.$isSendingCode
            .combineLatest(viewModel.$countdown)
            .sink { [weak self] isSending, sec in
                self?.refreshAuthGetCodeButton(isSending: isSending, countdown: sec)
            }
            .store(in: &cancellables)
        
        // 提交中：禁用重置按钮
        viewModel.$isLoading
            .sink { [weak self] isLoading in
                guard let self else { return }
                self.forgetPwdBtn.isEnabled = !isLoading
                self.forgetPwdBtn.alpha = isLoading ? 0.6 : 1.0
            }
            .store(in: &cancellables)
        
        // 错误提示
        viewModel.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] msg in
                self?.showAlert(msg)
                self?.viewModel.clearError()
            }
            .store(in: &cancellables)

        // 轻提示
        viewModel.$toastMessage
            .compactMap { $0 }
            .sink { [weak self] msg in
                self?.showToast(msg)
                self?.viewModel.clearToast()
            }
            .store(in: &cancellables)
        
        // 重置成功 → 延时返回登录页
        viewModel.$resetSuccess
            .filter { $0 }
            .sink { [weak self] _ in
                AppLog.auth.debug("重置密码成功，1.2s 后返回登录页")
                self?.popAfterDelay(seconds: 1.2)
            }
            .store(in: &cancellables)
    }

    // MARK: - UI 同步

    private func syncUIWithViewModel(animated: Bool) {
        let isPhone = (viewModel.accountMode == .phone)

        syncAuthSegment(segmentControl, with: viewModel)

        let changes = {
            self.phoneForgetView.isHidden = !isPhone
            self.emailForgetView.isHidden = isPhone
        }

        guard animated, let hostView = forgetContainerStack else {
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
    @objc private func codeChanged()     { viewModel.code = codeTextField.text ?? "" }
    @objc private func passwordChanged() { viewModel.password = passwordTextField.text ?? "" }

    // MARK: - IBActions

    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        viewModel.switchAccountMode(
            LoginAccountMode(rawValue: sender.selectedSegmentIndex) ?? .phone
        )
        
        codeTextField.text = ""
    }

    @IBAction func getCodeTapped(_ sender: UIButton) {
        view.endEditing(true)
        viewModel.sendForgetCode()
    }

    @IBAction func togglePasswordVisibility(_ sender: UIButton) {
        toggleAuthPasswordVisibility()
    }

    @IBAction func submitButtonTapped(_ sender: UIButton) {
        view.endEditing(true)

        guard isPrivacyAgreed else {
            showToast("请先阅读并同意《用户注册协议》与《隐私政策》")
            return
        }
        viewModel.resetPassword()
    }

    @IBAction func agreePrivacyTapped(_ sender: UIButton) {
        isPrivacyAgreed.toggle()
    }

    // MARK: - Navigation Helper

    /// 延时后 pop 回上一页
    ///
    /// - Parameter seconds: 延时秒数（用于让 Toast 展示完后才 pop）
    ///
    private func popAfterDelay(seconds: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self else { return }
            // 仅在当前 VC 仍是栈顶时才 pop
            guard self.navigationController?.viewControllers.last === self else {
                AppLog.auth.debug("延时 pop 时 VC 已不在栈顶，跳过")
                return
            }
            self.navigationController?.popViewController(animated: true)
        }
    }
}

// MARK: - AuthFormViewControllerProtocol

extension ForgetPassWordController: AuthFormViewControllerProtocol {

    var authPrivacyTextView: UITextView! { privacyTextView }
    var authPrivacyButton: UIButton! { agreePrivacyBtn }
    var authGetCodeButton: UIButton! { getCodeBtn }
    var authPasswordTextField: UITextField! { passwordTextField }
    var authPasswordVisibilityButton: UIButton! { passwordVisibleBtn }
}

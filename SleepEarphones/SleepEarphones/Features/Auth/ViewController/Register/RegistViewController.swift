//
//  RegistViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/16.
//

import UIKit
import Combine

/// 注册页
@MainActor
final class RegistViewController: UIViewController {

    // MARK: - IBOutlet

    /// 注册类型选择---手机号/邮箱
    @IBOutlet weak var segmentControl: UISegmentedControl!

    /// 承载四个输入区的垂直 stackView
    @IBOutlet weak var registerContainerStack: UIStackView!

    /// 注册类型：手机号
    @IBOutlet weak var phoneRegisterView: UIView!
    @IBOutlet weak var phoneTextField: UITextField!

    /// 注册类型：邮箱
    @IBOutlet weak var emailRegisterView: UIView!
    @IBOutlet weak var emailTextField: UITextField!

    /// 注册校验：验证码
    @IBOutlet weak var codeView: UIView!
    @IBOutlet weak var codeTextField: UITextField!
    @IBOutlet weak var getCodeBtn: UIButton!

    /// 注册校验：密码
    @IBOutlet weak var passwordView: UIView!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var passwordVisibleBtn: UIButton!

    /// 注册按钮
    @IBOutlet weak var registerBtn: UIButton!

    /// 去登录按钮
    @IBOutlet weak var gotoLoginBtn: UIButton!

    /// 隐私协议同意框
    @IBOutlet weak var agreePrivacyBtn: UIButton!

    /// 隐私协议文本内容
    @IBOutlet weak var privacyTextView: UITextView!

    // MARK: - Properties

    private let viewModel = RegisterViewModel()
    private var cancellables = Set<AnyCancellable>()

    /// 协议链接点击处理器
    ///
    /// - Note: 与登录 / 找回密码页共用 `AgreementTextViewHandler`——
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
        title = "注册账号"

        // 用扩展统一配置键盘
        applyAuthKeyboard(to: phoneTextField, mode: .phone)
        applyAuthKeyboard(to: emailTextField, mode: .email)
        codeTextField.keyboardType = .numberPad
        
        
        registerBtn.layer.cornerRadius = AppSpacing.Corner.card

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
        
        // 提交中：禁用注册按钮
        viewModel.$isLoading
            .sink { [weak self] isLoading in
                guard let self else { return }
                self.registerBtn.isEnabled = !isLoading
                self.registerBtn.alpha = isLoading ? 0.6 : 1.0
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

        // 注册成功 → 延时返回登录页
        viewModel.$registerSuccess
            .filter { $0 }
            .sink { [weak self] _ in
                AppLog.auth.debug("注册成功，1.2s 后返回登录页")
                self?.popAfterDelay(seconds: 1.2)
            }
            .store(in: &cancellables)
    }

    // MARK: - UI 同步

    private func syncUIWithViewModel(animated: Bool) {
        let isPhone = (viewModel.accountMode == .phone)

        syncAuthSegment(segmentControl, with: viewModel)

        let changes = {
            self.phoneRegisterView.isHidden = !isPhone
            self.emailRegisterView.isHidden = isPhone
        }

        guard animated, let hostView = registerContainerStack else {
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
        viewModel.sendRegisterCode()
    }

    @IBAction func togglePasswordVisibility(_ sender: UIButton) {
        toggleAuthPasswordVisibility()
    }

    @IBAction func registerButtonTapped(_ sender: UIButton) {
        view.endEditing(true)

        guard isPrivacyAgreed else {
            showToast("请先阅读并同意《用户注册协议》与《隐私政策》")
            return
        }
        viewModel.register()
    }

    /// 点击"已有账号，前去登录"
    @IBAction func gotoLoginTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
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

extension RegistViewController: AuthFormViewControllerProtocol {

    var authPrivacyTextView: UITextView! { privacyTextView }
    var authPrivacyButton: UIButton! { agreePrivacyBtn }
    var authGetCodeButton: UIButton! { getCodeBtn }
    var authPasswordTextField: UITextField! { passwordTextField }
    var authPasswordVisibilityButton: UIButton! { passwordVisibleBtn }
}

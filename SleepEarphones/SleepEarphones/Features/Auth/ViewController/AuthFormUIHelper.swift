//
//  AuthFormUIHelper.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import UIKit

// MARK: - 协议

/// 认证表单页协议
///
/// ## 用途
/// 三页（登录 / 注册 / 找回密码）都有相同的 UI 交互：
/// - 隐私协议勾选
/// - 验证码按钮倒计时
/// - 密码可见性切换
/// 
@MainActor
protocol AuthFormViewControllerProtocol: UIViewController {

    /// 隐私协议文本视图（含可点击链接）
    var authPrivacyTextView: UITextView! { get }

    /// 隐私协议勾选按钮
    var authPrivacyButton: UIButton! { get }

    /// 验证码"获取"按钮
    var authGetCodeButton: UIButton! { get }

    /// 密码输入框
    var authPasswordTextField: UITextField! { get }

    /// 密码可见性切换按钮
    var authPasswordVisibilityButton: UIButton! { get }
}

// MARK: - 协议默认实现

extension AuthFormViewControllerProtocol {

    // MARK: - 隐私协议文本

    /// 配置隐私协议文本（含"用户协议"、"隐私政策"两个可点击链接）
    ///
    /// - Parameter delegate: `UITextViewDelegate`，处理链接点击
    ///
    /// ## 使用示例
    /// ```swift
    /// private let agreementHandler = AgreementTextViewHandler()
    ///
    /// override func viewDidLoad() {
    ///     super.viewDidLoad()
    ///     configureAuthPrivacyTextView(delegate: agreementHandler)
    /// }
    /// ```
    ///
    /// - Note: 三页共用同一段文案。若未来需要多语言，
    ///         把 `text` / `link.text` 换成 `L(...)` 即可。
    func configureAuthPrivacyTextView(delegate: UITextViewDelegate) {
        let text = "已阅读并同意《用户注册协议》与《隐私政策》"

        authPrivacyTextView.setAgreementText(
            text,
            links: [
                AgreementLink(
                    text: "《用户注册协议》",
                    url: AgreementLinks.userAgreement
                ),
                AgreementLink(
                    text: "《隐私政策》",
                    url: AgreementLinks.privacyPolicy
                )
            ]
        )
        authPrivacyTextView.delegate = delegate
    }

    // MARK: - 隐私勾选按钮

    /// 刷新隐私勾选按钮的视觉
    ///
    /// - Parameter isAgreed: 是否已勾选
    ///
    /// - Note: 用 `AppImage.System.checkmarkCircleFill`（已勾选）
    ///         与 `AppImage.System.circle`（未勾选）切换，
    ///         颜色分别走 `.success` 与 `.secondary`。
    func refreshAuthPrivacyButton(isAgreed: Bool) {
        let icon = isAgreed
            ? AppImage.System.checkmarkCircleFill
            : AppImage.System.circle
        let color = isAgreed
            ? AppColor.Semantic.success
            : AppColor.Text.secondary

        authPrivacyButton.setImage(icon, for: .normal)
        authPrivacyButton.tintColor = color
    }

    // MARK: - 验证码按钮

    /// 刷新验证码按钮的标题 / 可用性
    ///
    /// ## 状态优先级
    /// 1. 发送中 → "发送中…" + 禁用
    /// 2. 倒计时中 → "N s" + 禁用
    /// 3. 空闲 → "获取验证码" + 可用
    ///
    /// - Parameters:
    ///   - isSending: 是否正在发送
    ///   - countdown: 倒计时剩余秒数
    ///
    /// - Note: `alpha` 变化用 `UIView.animate` 过渡，
    ///         避免从可用→禁用时"啪"一下变灰。
    func refreshAuthGetCodeButton(isSending: Bool, countdown: Int) {
        let canTap = !isSending && countdown == 0

        authGetCodeButton.isEnabled = canTap

        let targetAlpha: CGFloat = canTap ? 1.0 : 0.6
        if abs(authGetCodeButton.alpha - targetAlpha) > 0.01 {
            UIView.animate(withDuration: AppSpacing.Animation.quick) {
                self.authGetCodeButton.alpha = targetAlpha
            }
        }

        if isSending {
            authGetCodeButton.setTitle("发送中…", for: .normal)
        } else if countdown > 0 {
            authGetCodeButton.setTitle("\(countdown) s", for: .normal)
        } else {
            authGetCodeButton.setTitle("获取验证码", for: .normal)
        }
    }

    // MARK: - 密码可见性

    /// 切换密码可见性并更新按钮图标
    ///
    /// ## 状态
    /// - `isSecureTextEntry == true` → 显示"闭眼"图标（`eye.slash.fill`）
    /// - `isSecureTextEntry == false` → 显示"开眼"图标（`eye.fill`）
    ///
    /// - Note: 图标语义遵循"**显示当前状态**"而非"**点击后的动作**"。
    ///         闭眼 = 密码隐藏中，开眼 = 密码可见中。
    func toggleAuthPasswordVisibility() {
        authPasswordTextField.isSecureTextEntry.toggle()
        let icon = authPasswordTextField.isSecureTextEntry
            ? AppImage.System.eyeSlashFill
            : AppImage.System.eyeFill
        authPasswordVisibilityButton.setImage(icon, for: .normal)
    }

    // MARK: - 账号模式同步

    /// 同步 segmentControl 与 ViewModel 的账号模式
    ///
    /// - Parameters:
    ///   - segment: 分段控件
    ///   - viewModel: 表单 VM
    ///
    /// - Note: 在 `syncUIWithViewModel` 里调用，保证 segment 状态与 VM 一致。
    ///         典型场景：VM 内部切换了 `accountMode`（如程序化切换），
    ///         UI 需要跟随更新；反之 UI 手动切换时，VM 也要被更新。
    func syncAuthSegment(_ segment: UISegmentedControl, with viewModel: AuthFormViewModel) {
        if segment.selectedSegmentIndex != viewModel.accountMode.rawValue {
            segment.selectedSegmentIndex = viewModel.accountMode.rawValue
        }
    }

    // MARK: - 账号输入框配置

    /// 应用账号模式对应的键盘与输入特性
    ///
    /// - Parameters:
    ///   - textField: 目标输入框
    ///   - mode: 账号模式
    ///
    /// ## 配置项
    /// - `keyboardType`：数字键盘 / 邮箱键盘
    /// - `textContentType`：系统自动填充识别（`.telephoneNumber` / `.emailAddress`）
    /// - `autocapitalizationType`：`.none`（避免邮箱首字母大写）
    /// - `autocorrectionType`：`.no`（精确字符串，禁止纠错）
    /// - `returnKeyType`：`.done`（键盘右下角显示"完成"）
    /// - `enablesReturnKeyAutomatically`：输入为空时禁用"完成"键
    func applyAuthKeyboard(to textField: UITextField, mode: LoginAccountMode) {
        textField.keyboardType = mode.keyboardType
        textField.textContentType = mode.textContentType
        textField.autocapitalizationType = mode.autocapitalizationType
        textField.autocorrectionType = mode.autocorrectionType
        textField.returnKeyType = .done
        textField.enablesReturnKeyAutomatically = true
    }
}

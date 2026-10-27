//
//  ChangePasswordViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/30.
//

import UIKit
import SnapKit
import Combine

/// 修改密码页（两步）
///
/// ## 职责
/// - **Step 1**：输入旧密码 → 点击"下一步"
/// - **Step 2**：输入新密码 + 确认新密码 → 点击"完成" → 提交接口
/// - 接口返回"旧密码错误"时自动回退到 Step 1
///
/// ## UI 实现说明
/// 用 `UIStackView` 管理三个字段——切换 Step 时 `isHidden` 会自动塌陷空间，
/// 避免"隐藏字段仍占位"的视觉问题。
///
/// ## 调用方法
/// ```swift
/// // 从"账号与安全"页 push
/// let vc = ChangePasswordViewController()
/// navigationController?.pushViewController(vc, animated: true)
/// ```
@MainActor
final class ChangePasswordViewController: UIViewController {

    // MARK: - Steps

    /// 当前步骤
    private enum Step {
        /// 验证旧密码
        case verifyOldPassword

        /// 设置新密码
        case setNewPassword
    }

    // MARK: - Properties

    /// 当前步骤（初始为验证旧密码）
    private var currentStep: Step = .verifyOldPassword

    /// 账号安全服务
    private let service: AccountSecurityServiceProtocol = AccountSecurityService()

    /// Step 1 通过后暂存的旧密码
    ///
    /// - Note: Step 2 提交时需要一并传给后端校验，因此需在 Step 1 → Step 2
    ///         切换时缓存。
    private var oldPassword: String = ""

    /// Combine 订阅容器
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI

    /// 顶部提示文案（随 Step 变化）
    private let hintLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Body.secondary
        l.textColor = AppColor.Text.secondary
        l.textAlignment = .left
        l.numberOfLines = 0
        return l
    }()

    /// 旧密码输入框（Step 1）
    private let oldPasswordField: UITextField = {
        let tf = UITextField()
        tf.font = AppFont.Body.regular
        tf.textColor = AppColor.Text.primary
        tf.placeholder = "请输入旧密码"
        tf.isSecureTextEntry = true
        tf.clearButtonMode = .whileEditing
        tf.textContentType = .password
        tf.borderStyle = .roundedRect
        return tf
    }()

    /// 新密码输入框（Step 2）
    private let newPasswordField: UITextField = {
        let tf = UITextField()
        tf.font = AppFont.Body.regular
        tf.textColor = AppColor.Text.primary
        tf.placeholder = "请输入新密码（6~12 位字母+数字）"
        tf.isSecureTextEntry = true
        tf.clearButtonMode = .whileEditing
        tf.textContentType = .newPassword
        tf.borderStyle = .roundedRect
        return tf
    }()

    /// 确认新密码输入框（Step 2）
    private let confirmPasswordField: UITextField = {
        let tf = UITextField()
        tf.font = AppFont.Body.regular
        tf.textColor = AppColor.Text.primary
        tf.placeholder = "请再次输入新密码"
        tf.isSecureTextEntry = true
        tf.clearButtonMode = .whileEditing
        tf.textContentType = .newPassword
        tf.borderStyle = .roundedRect
        return tf
    }()

    /// 三个字段的组合栈——`isHidden` 时自动塌陷空间
    private lazy var fieldStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [
            oldPasswordField,
            newPasswordField,
            confirmPasswordField
        ])
        s.axis = .vertical
        s.spacing = AppSpacing.lg
        s.alignment = .fill
        return s
    }()

    /// 提交按钮（Step 1："下一步" / Step 2："完成"）
    private let submitButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("下一步", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = AppFont.Button.primary
        b.backgroundColor = AppColor.Brand.primary
        b.layer.cornerRadius = AppSpacing.Corner.button
        b.clipsToBounds = true
        return b
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        refreshUI()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "修改密码"
        view.backgroundColor = AppColor.Background.primary
        navigationItem.backButtonDisplayMode = .minimal

        view.addSubview(hintLabel)
        view.addSubview(fieldStack)
        view.addSubview(submitButton)
    }

    private func setupConstraints() {
        hintLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(AppSpacing.lg)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
        }

        fieldStack.snp.makeConstraints { make in
            make.top.equalTo(hintLabel.snp.bottom).offset(AppSpacing.xl)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
        }

        // 每个 textField 固定高度
        [oldPasswordField, newPasswordField, confirmPasswordField].forEach { tf in
            tf.snp.makeConstraints { make in
                make.height.equalTo(50)
            }
        }

        submitButton.snp.makeConstraints { make in
            make.top.equalTo(fieldStack.snp.bottom).offset(AppSpacing.xxl)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
            make.height.equalTo(46)
        }
    }

    private func setupActions() {
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
    }

    // MARK: - UI Refresh

    /// 根据当前 Step 刷新 UI（提示文案 / 字段显隐 / 按钮标题）
    private func refreshUI() {
        switch currentStep {
        case .verifyOldPassword:
            hintLabel.text = "请输入当前密码以验证身份："
            oldPasswordField.isHidden = false
            newPasswordField.isHidden = true
            confirmPasswordField.isHidden = true
            submitButton.setTitle("下一步", for: .normal)

        case .setNewPassword:
            hintLabel.text = "请设置新密码（6~12 位字母+数字）："
            oldPasswordField.isHidden = true
            newPasswordField.isHidden = false
            confirmPasswordField.isHidden = false
            submitButton.setTitle("完成", for: .normal)
        }
    }

    // MARK: - Actions

    /// 提交按钮点击（依 Step 分派）
    @objc private func submitTapped() {
        view.endEditing(true)

        switch currentStep {
        case .verifyOldPassword:
            handleVerifyOldPassword()
        case .setNewPassword:
            handleSetNewPassword()
        }
    }

    /// Step 1：校验旧密码非空并进入 Step 2
    private func handleVerifyOldPassword() {
        let old = oldPasswordField.text ?? ""
        guard !old.isEmpty else {
            showToast("请输入旧密码")
            return
        }
        oldPassword = old
        currentStep = .setNewPassword
        refreshUI()
        newPasswordField.becomeFirstResponder()
    }

    /// Step 2：校验新密码格式 / 一致性并提交
    private func handleSetNewPassword() {
        let newPwd = newPasswordField.text ?? ""
        let confirmPwd = confirmPasswordField.text ?? ""

        // 1. 新密码强度校验
        guard AccountInputValidator.isStrongPassword(newPwd) else {
            showToast("新密码需为 6~12 位字母+数字")
            return
        }
        // 2. 两次输入一致性校验
        guard newPwd == confirmPwd else {
            showToast("两次输入的新密码不一致")
            return
        }

        submitChange(newPassword: newPwd)
    }

    /// 提交修改密码请求
    ///
    /// - Parameter newPassword: 已验证的新密码
    ///
    /// ## 失败处理
    /// - 若错误信息包含"旧密码" / "原密码"关键字，自动回退到 Step 1
    /// - 其他错误仅弹 Alert
    private func submitChange(newPassword: String) {
        submitButton.isEnabled = false
        submitButton.alpha = 0.6

        service.changePassword(oldPassword: oldPassword, newPassword: newPassword)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.submitButton.isEnabled = true
                    self.submitButton.alpha = 1.0

                    if case .failure(let error) = completion {
                        if case .cancelled = error { return }
                        AppLog.profile.error("修改密码失败：\(error.logCode, privacy: .public)")
                        let message = error.errorDescription ?? "修改失败"
                        self.showAlert(message)

                        // 若失败提示"旧密码错误"，回退到 Step 1（用户不用手动重走）
                        if message.contains("旧密码") || message.contains("原密码") {
                            self.currentStep = .verifyOldPassword
                            self.refreshUI()
                            self.oldPasswordField.text = ""
                        }
                    }
                },
                receiveValue: { [weak self] _ in
                    guard let self else { return }
                    AppLog.profile.debug("修改密码成功")
                    self.showToast("密码修改成功")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            )
            .store(in: &cancellables)
    }
}

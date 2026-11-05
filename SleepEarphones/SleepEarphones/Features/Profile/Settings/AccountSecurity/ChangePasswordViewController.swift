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

    // MARK: - Constants

    private enum Layout {
        /// 输入框高度
        static let textFieldHeight: CGFloat = 50
        /// 提交按钮高度
        static let submitButtonHeight: CGFloat = 46
        /// Hint 顶部间距
        static let hintTopInset: CGFloat = AppSpacing.lg
        /// Hint 水平 inset
        static let horizontalInset: CGFloat = AppSpacing.lg
        /// Hint 到字段栈的间距
        static let hintToStackSpacing: CGFloat = AppSpacing.xl
        /// 字段之间的间距
        static let fieldSpacing: CGFloat = AppSpacing.lg
        /// 字段栈到提交按钮的间距
        static let stackToButtonSpacing: CGFloat = AppSpacing.xxl
        /// 修改密码成功后的延时 pop（秒）
        static let successPopDelay: TimeInterval = 0.8
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
        // **placeholder 已本地化**
        tf.placeholder = L("请输入旧密码")
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
        // **placeholder 已本地化**
        tf.placeholder = L("请输入新密码（6~12 位字母+数字）")
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
        // **placeholder 已本地化**
        tf.placeholder = L("请再次输入新密码")
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
        s.spacing = Layout.fieldSpacing
        s.alignment = .fill
        return s
    }()

    /// 提交按钮（Step 1：`"下一步"` / Step 2：`"完成"`）
    private let submitButton: UIButton = {
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
        // **导航标题已本地化**
        title = L("修改密码")
        view.backgroundColor = AppColor.Background.primary
        navigationItem.backButtonDisplayMode = .minimal

        view.addSubview(hintLabel)
        view.addSubview(fieldStack)
        view.addSubview(submitButton)
    }

    private func setupConstraints() {
        hintLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
                .offset(Layout.hintTopInset)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        fieldStack.snp.makeConstraints { make in
            make.top.equalTo(hintLabel.snp.bottom).offset(Layout.hintToStackSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        // 每个 textField 固定高度
        [oldPasswordField, newPasswordField, confirmPasswordField].forEach { tf in
            tf.snp.makeConstraints { make in
                make.height.equalTo(Layout.textFieldHeight)
            }
        }

        submitButton.snp.makeConstraints { make in
            make.top.equalTo(fieldStack.snp.bottom).offset(Layout.stackToButtonSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.height.equalTo(Layout.submitButtonHeight)
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
            // **Hint 与按钮标题已本地化**
            hintLabel.text = L("请输入当前密码以验证身份：")
            oldPasswordField.isHidden = false
            newPasswordField.isHidden = true
            confirmPasswordField.isHidden = true
            submitButton.setTitle(L("下一步"), for: .normal)

        case .setNewPassword:
            hintLabel.text = L("请设置新密码（6~12 位字母+数字）：")
            oldPasswordField.isHidden = true
            newPasswordField.isHidden = false
            confirmPasswordField.isHidden = false
            submitButton.setTitle(L("完成"), for: .normal)
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
            showToast(L("请输入旧密码"))
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
            showToast(L("新密码需为 6~12 位字母+数字"))
            return
        }
        // 2. 两次输入一致性校验
        guard newPwd == confirmPwd else {
            showToast(L("两次输入的新密码不一致"))
            return
        }

        submitChange(newPassword: newPwd)
    }

    /// 提交修改密码请求
    ///
    /// - Parameter newPassword: 已验证的新密码
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
                        let message = error.errorDescription ?? L("修改失败")
                        self.showAlert(message)

                        // 若判定为"旧密码错误"，回退到 Step 1
                        if self.isOldPasswordError(message) {
                            self.currentStep = .verifyOldPassword
                            self.refreshUI()
                            self.oldPasswordField.text = ""
                        }
                    }
                },
                receiveValue: { [weak self] _ in
                    guard let self else { return }
                    AppLog.profile.debug("修改密码成功")
                    self.showToast(L("密码修改成功"))
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + Layout.successPopDelay
                    ) { [weak self] in
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Helpers

    /// 判断错误消息是否为"旧密码错误"
    ///
    /// - Parameter message: 后端返回的错误消息（**可能已本地化**）
    /// - Returns: 是否命中"旧密码错误"关键字
    private func isOldPasswordError(_ message: String) -> Bool {
        let lower = message.lowercased()

        // 中文关键字
        let chineseKeywords = ["旧密码", "原密码"]
        if chineseKeywords.contains(where: { lower.contains($0) }) {
            return true
        }

        // 英文关键字（后端可能返回英文消息）
        let englishKeywords = ["old password", "current password"]
        if englishKeywords.contains(where: { lower.contains($0) }) {
            return true
        }

        return false
    }
}

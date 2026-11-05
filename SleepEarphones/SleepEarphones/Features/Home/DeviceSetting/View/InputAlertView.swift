//
//  InputAlertView.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/30.
//

import UIKit
import SnapKit

/// 通用输入弹窗
///
/// ## 调用方法
/// ```swift
/// let alert = InputAlertView(
///     title: L("修改昵称"),
///     placeholder: L("请输入新昵称"),
///     currentText: "sam"
/// )
///
/// alert.onConfirm = { newName in
///     saveName(newName)
/// }
/// alert.onCancel = {
///     log("用户取消")
/// }
/// alert.show()
/// ```
@MainActor
final class InputAlertView: UIView {

    // MARK: - Constants

    private enum Layout {
        /// 弹窗容器宽度
        static let containerWidth: CGFloat = 290

        /// 容器圆角
        static let containerCornerRadius: CGFloat = AppSpacing.Corner.card

        /// 容器内边距
        static let containerPadding: CGFloat = AppSpacing.xl

        /// 标题顶部间距
        static let titleTopInset: CGFloat = AppSpacing.xl

        /// 输入框高度
        static let textFieldHeight: CGFloat = 40

        /// 输入框左右内边距
        static let textFieldPadding: CGFloat = AppSpacing.sm

        /// 输入框与标题的间距
        static let textFieldTopSpacing: CGFloat = AppSpacing.lg

        /// 输入框与分割线的间距
        static let textFieldBottomSpacing: CGFloat = AppSpacing.xl

        /// 分割线高度
        static let separatorHeight: CGFloat = AppSpacing.Border.hairline

        /// 按钮高度
        static let buttonHeight: CGFloat = 50

        /// 遮罩颜色（40% 透明黑）
        static let maskColor = UIColor.black.withAlphaComponent(0.4)
    }

    // MARK: - Callbacks

    /// 点击"确定"的回调（已过滤空白字符）
    var onConfirm: ((String) -> Void)?

    /// 点击"取消"或遮罩时的回调
    var onCancel: (() -> Void)?

    // MARK: - UI

    private let dimmingView = UIView()
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let textField = UITextField()
    private let separatorH = UIView()
    private let separatorV = UIView()
    private let cancelButton = UIButton(type: .system)
    private let confirmButton = UIButton(type: .system)

    // MARK: - State

    /// 是否正在 hide 动画中
    private var isDismissing = false

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameters:
    ///   - title: 弹窗标题（**调用方应传入 `L(...)` 已本地化的字符串**）
    ///   - placeholder: 输入框占位符（**调用方应传入 `L(...)`**）
    ///   - currentText: 输入框初始文本（如当前昵称）——**不参与国际化**
    init(title: String, placeholder: String, currentText: String? = nil) {
        super.init(frame: .zero)
        setupUI(title: title, placeholder: placeholder, currentText: currentText)
        setupConstraints()
        setupActions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI(title: String, placeholder: String, currentText: String?) {
        // 遮罩层
        dimmingView.backgroundColor = Layout.maskColor
        addSubview(dimmingView)

        // 白色卡片
        containerView.backgroundColor = AppColor.Background.card
        containerView.layer.cornerRadius = Layout.containerCornerRadius
        containerView.clipsToBounds = true
        addSubview(containerView)

        // 标题
        titleLabel.text = title
        titleLabel.font = AppFont.Title.section
        titleLabel.textColor = AppColor.Text.primary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        containerView.addSubview(titleLabel)

        // 输入框
        textField.text = currentText
        textField.placeholder = placeholder
        textField.font = AppFont.Body.secondary
        textField.textColor = AppColor.Text.primary
        textField.layer.borderWidth = AppSpacing.Border.standard
        textField.layer.borderColor = AppColor.separator.cgColor
        textField.layer.cornerRadius = AppSpacing.Corner.small

        // 设置左侧内边距（UIView + frame 固定宽度）
        let paddingView = UIView(frame: CGRect(
            x: 0, y: 0,
            width: Layout.textFieldPadding,
            height: Layout.textFieldHeight
        ))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        textField.clearButtonMode = .whileEditing
        containerView.addSubview(textField)

        // 分割线
        separatorH.backgroundColor = AppColor.separator
        containerView.addSubview(separatorH)

        separatorV.backgroundColor = AppColor.separator
        containerView.addSubview(separatorV)

        // 取消按钮（灰色）
        cancelButton.setTitle(L("取消"), for: .normal)
        cancelButton.setTitleColor(AppColor.Text.secondary, for: .normal)
        cancelButton.titleLabel?.font = AppFont.Button.secondary
        containerView.addSubview(cancelButton)

        // 确定按钮（蓝色）
        confirmButton.setTitle(L("确定"), for: .normal)
        confirmButton.setTitleColor(AppColor.Brand.primary, for: .normal)
        confirmButton.titleLabel?.font = AppFont.Button.secondary
        containerView.addSubview(confirmButton)
    }

    private func setupConstraints() {
        dimmingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(Layout.containerWidth)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.titleTopInset)
            make.leading.trailing.equalToSuperview().inset(Layout.containerPadding)
        }

        textField.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Layout.textFieldTopSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.containerPadding)
            make.height.equalTo(Layout.textFieldHeight)
        }

        separatorH.snp.makeConstraints { make in
            make.top.equalTo(textField.snp.bottom).offset(Layout.textFieldBottomSpacing)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Layout.separatorHeight)
        }

        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(separatorH.snp.bottom)
            make.leading.equalToSuperview()
            make.width.equalToSuperview().dividedBy(2)
            make.height.equalTo(Layout.buttonHeight)
            make.bottom.equalToSuperview()
        }

        separatorV.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(separatorH.snp.bottom)
            make.bottom.equalToSuperview()
            make.width.equalTo(Layout.separatorHeight)
        }

        confirmButton.snp.makeConstraints { make in
            make.top.equalTo(separatorH.snp.bottom)
            make.trailing.equalToSuperview()
            make.width.equalToSuperview().dividedBy(2)
            make.height.equalTo(Layout.buttonHeight)
        }
    }

    private func setupActions() {
        // 遮罩点击
        let tap = UITapGestureRecognizer(target: self, action: #selector(cancelTapped))
        dimmingView.addGestureRecognizer(tap)

        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
    }

    // MARK: - Actions

    /// 点击"取消"或遮罩
    @objc private func cancelTapped() {
        guard !isDismissing else { return }
        isDismissing = true

        hide { [weak self] in
            self?.onCancel?()
        }
    }

    /// 点击"确定"
    @objc private func confirmTapped() {
        // 拦截空字符串 / 纯空格
        let text = textField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            // 轻震动反馈（iOS 10+）
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)

            // 恢复焦点 + 选中文本
            textField.becomeFirstResponder()
            textField.selectAll(nil)
            return
        }

        guard !isDismissing else { return }
        isDismissing = true

        hide { [weak self] in
            self?.onConfirm?(text)
        }
    }

    // MARK: - Show / Hide

    /// 展示弹窗
    func show() {
        guard let window = keyWindow else {
            AppLog.ui.error("InputAlertView 无法展示：找不到 keyWindow")
            return
        }

        window.addSubview(self)
        self.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        self.alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)

        // 延迟弹起键盘
        //
        // - Note: 0.1s 足够入场动画启动，但不至于让用户感觉"键盘反应慢"。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.textField.becomeFirstResponder()
        }

        UIView.animate(
            withDuration: AppSpacing.Animation.standard,
            delay: 0,
            options: .curveEaseOut
        ) {
            self.alpha = 1
            self.containerView.transform = .identity
        }
    }

    /// 隐藏弹窗
    ///
    /// - Parameter completion: 动画完成后的回调
    private func hide(completion: (() -> Void)? = nil) {
        self.endEditing(true)
        UIView.animate(
            withDuration: AppSpacing.Animation.quick,
            animations: {
                self.alpha = 0
                self.containerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }
        ) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }

    // MARK: - Private Helpers

    /// 当前 keyWindow
    private var keyWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        // 1. 优先取前台活跃场景的 key window
        if let activeWindow = scenes
            .first(where: { $0.activationState == .foregroundActive })?
            .windows
            .first(where: { $0.isKeyWindow }) {
            return activeWindow
        }

        // 2. 兜底：任意场景的 key window
        return scenes
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

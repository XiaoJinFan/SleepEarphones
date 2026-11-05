//
//  CustomAlertView.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/30.
//

import UIKit
import SnapKit

/// 自定义遮罩弹窗
///
/// ## 调用方法
/// ```swift
/// let alert = CustomAlertView(
///     title: L("音量提醒"),
///     message: L("即将播放高分贝音频。为了您的安全和舒适，请确保已取下耳机"),
///     confirmTitle: L("继续"),
///     cancelTitle: L("取消")
/// )
///
/// alert.onConfirm = { startPlaying() }
/// alert.onCancel = { log("用户取消") }
/// alert.show()
/// ```
@MainActor
final class CustomAlertView: UIView {

    // MARK: - Constants

    private enum Layout {
        /// 弹窗容器宽度
        static let containerWidth: CGFloat = 300

        /// 容器圆角
        static let containerCornerRadius: CGFloat = AppSpacing.Corner.card

        /// 容器内边距
        static let containerPadding: CGFloat = AppSpacing.lg

        /// 标题顶部间距
        static let titleTopInset: CGFloat = AppSpacing.xl

        /// 正文与标题的间距
        static let messageTopSpacing: CGFloat = AppSpacing.md

        /// 按钮顶部间距
        static let buttonTopSpacing: CGFloat = 30

        /// 按钮高度
        static let buttonHeight: CGFloat = 44

        /// 按钮之间的间距
        static let buttonSpacing: CGFloat = AppSpacing.sm

        /// 按钮底部间距
        static let buttonBottomInset: CGFloat = AppSpacing.lg

        /// 遮罩颜色（40% 透明黑）
        static let maskColor = UIColor.black.withAlphaComponent(0.4)
    }

    // MARK: - Callbacks

    /// 点击"取消"或遮罩时的回调
    var onCancel: (() -> Void)?

    /// 点击"继续"时的回调
    var onConfirm: (() -> Void)?

    // MARK: - UI

    private let dimmingView = UIView()
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let confirmButton = UIButton(type: .system)

    // MARK: - State

    /// 是否正在 hide 动画中
    private var isDismissing = false

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameters:
    ///   - title: 标题（**调用方应传入 `L(...)` 已本地化的字符串**）
    ///   - message: 正文（**调用方应传入 `L(...)`**）
    ///   - confirmTitle: 确认按钮标题（**调用方应传入 `L(...)`**）
    ///   - cancelTitle: 取消按钮标题（**调用方应传入 `L(...)`**）
    init(title: String, message: String, confirmTitle: String, cancelTitle: String) {
        super.init(frame: .zero)
        setupUI(
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            cancelTitle: cancelTitle
        )
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI(title: String, message: String, confirmTitle: String, cancelTitle: String) {
        // 遮罩层
        dimmingView.backgroundColor = Layout.maskColor
        let tap = UITapGestureRecognizer(target: self, action: #selector(cancelTapped))
        dimmingView.addGestureRecognizer(tap)
        addSubview(dimmingView)

        // 白色卡片
        containerView.backgroundColor = AppColor.Background.card
        containerView.layer.cornerRadius = Layout.containerCornerRadius
        addSubview(containerView)

        // 标题
        titleLabel.text = title
        titleLabel.font = AppFont.Title.section
        titleLabel.textColor = AppColor.Text.primary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        containerView.addSubview(titleLabel)

        // 内容
        messageLabel.text = message
        messageLabel.font = AppFont.Body.secondary
        messageLabel.textColor = AppColor.Text.primary
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        containerView.addSubview(messageLabel)

        // 取消按钮（浅灰色）
        var cancelConfig = UIButton.Configuration.filled()
        cancelConfig.baseBackgroundColor = AppColor.Background.secondary
        cancelConfig.baseForegroundColor = AppColor.Text.primary
        cancelConfig.cornerStyle = .capsule
        var cancelAttr = AttributedString(cancelTitle)
        cancelAttr.font = AppFont.Button.secondary
        cancelConfig.attributedTitle = cancelAttr
        cancelButton.configuration = cancelConfig
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        containerView.addSubview(cancelButton)

        // 继续按钮（主题蓝）
        var confirmConfig = UIButton.Configuration.filled()
        confirmConfig.baseBackgroundColor = AppColor.Brand.primary
        confirmConfig.baseForegroundColor = .white
        confirmConfig.cornerStyle = .capsule
        var confirmAttr = AttributedString(confirmTitle)
        confirmAttr.font = AppFont.Button.secondary
        confirmConfig.attributedTitle = confirmAttr
        confirmButton.configuration = confirmConfig
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
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

        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Layout.messageTopSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.containerPadding)
        }

        // 取消按钮在左，确认按钮在右（iOS HIG 推荐顺序）
        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(messageLabel.snp.bottom).offset(Layout.buttonTopSpacing)
            make.leading.equalToSuperview().offset(Layout.containerPadding)
            make.height.equalTo(Layout.buttonHeight)
            make.bottom.equalToSuperview().offset(-Layout.buttonBottomInset)
        }

        confirmButton.snp.makeConstraints { make in
            make.top.equalTo(cancelButton)
            make.leading.equalTo(cancelButton.snp.trailing).offset(Layout.buttonSpacing)
            make.trailing.equalToSuperview().offset(-Layout.containerPadding)
            make.width.equalTo(cancelButton)
            make.height.equalTo(cancelButton)
        }
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

    /// 点击"继续"
    @objc private func confirmTapped() {
        guard !isDismissing else { return }
        isDismissing = true

        hide { [weak self] in
            self?.onConfirm?()
        }
    }

    // MARK: - Show / Hide

    /// 展示弹窗
    func show() {
        guard let window = keyWindow else {
            AppLog.ui.error("CustomAlertView 无法展示：找不到 keyWindow")
            return
        }

        window.addSubview(self)
        self.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 入场动画
        self.alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
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
    /// - Parameter completion: 动画完成后的回调（在 `removeFromSuperview` 之后执行）
    private func hide(completion: (() -> Void)? = nil) {
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

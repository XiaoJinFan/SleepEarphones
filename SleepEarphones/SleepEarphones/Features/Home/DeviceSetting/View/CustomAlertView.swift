//
//  CustomAlertView.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/30.
//

import UIKit
import SnapKit

/// 自定义遮罩弹窗
@MainActor
final class CustomAlertView: UIView {
    
    // MARK: - Callbacks
    var onCancel: (() -> Void)?
    var onConfirm: (() -> Void)?
    
    // MARK: - UI
    private let dimmingView = UIView()
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let confirmButton = UIButton(type: .system)
    
    // MARK: - Init
    init(title: String, message: String, confirmTitle: String, cancelTitle: String) {
        super.init(frame: .zero)
        setupUI(title: title, message: message, confirmTitle: confirmTitle, cancelTitle: cancelTitle)
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI(title: String, message: String, confirmTitle: String, cancelTitle: String) {
        // 遮罩层
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        let tap = UITapGestureRecognizer(target: self, action: #selector(cancelTapped))
        dimmingView.addGestureRecognizer(tap)
        addSubview(dimmingView)
        
        // 白色卡片
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 16
        addSubview(containerView)
        
        // 标题
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = AppColor.Text.primary
        titleLabel.textAlignment = .center
        containerView.addSubview(titleLabel)
        
        // 内容
        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 15, weight: .regular)
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
        cancelAttr.font = .systemFont(ofSize: 16, weight: .medium)
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
        confirmAttr.font = .systemFont(ofSize: 16, weight: .medium)
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
            make.width.equalTo(300)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        // 取消按钮在左，继续按钮在右
        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(messageLabel.snp.bottom).offset(30)
            make.leading.equalToSuperview().offset(20)
            make.height.equalTo(44)
            make.bottom.equalToSuperview().offset(-20)
        }
        
        confirmButton.snp.makeConstraints { make in
            make.top.equalTo(cancelButton)
            make.leading.equalTo(cancelButton.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-20)
            make.width.equalTo(cancelButton)
            make.height.equalTo(cancelButton)
        }
    }
    
    // MARK: - Actions
    
    @objc private func cancelTapped() {
        hide {
            self.onCancel?()
        }
    }
    
    @objc private func confirmTapped() {
        hide {
            self.onConfirm?()
        }
    }
    
    // MARK: - Show / Hide
    
    /// 展示弹窗
    func show() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else { return }
        
        window.addSubview(self)
        self.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 入场动画
        self.alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
            self.containerView.transform = .identity
        }
    }
    
    /// 隐藏弹窗
    private func hide(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
            self.containerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
}

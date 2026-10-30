//
//  InputAlertView.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/30.
//

import UIKit
import SnapKit

/// 通用输入弹窗
@MainActor
final class InputAlertView: UIView {
    
    // MARK: - Callbacks
    var onConfirm: ((String) -> Void)?
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
    
    // MARK: - Init
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
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        addSubview(dimmingView)
        
        // 白色卡片
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 12
        containerView.clipsToBounds = true
        addSubview(containerView)
        
        // 标题
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = AppColor.Text.primary
        titleLabel.textAlignment = .center
        containerView.addSubview(titleLabel)
        
        // 输入框
        textField.text = currentText
        textField.placeholder = placeholder
        textField.font = .systemFont(ofSize: 15)
        textField.textColor = AppColor.Text.primary
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor(hex: "#E5E5EA").cgColor
        textField.layer.cornerRadius = 4
        // 设置内边距
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        textField.clearButtonMode = .whileEditing
        containerView.addSubview(textField)
        
        // 分割线
        separatorH.backgroundColor = UIColor(hex: "#E5E5EA")
        containerView.addSubview(separatorH)
        
        separatorV.backgroundColor = UIColor(hex: "#E5E5EA")
        containerView.addSubview(separatorV)
        
        // 取消按钮（灰色）
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.setTitleColor(UIColor(hex: "#8E8E93"), for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17)
        containerView.addSubview(cancelButton)
        
        // 确定按钮（蓝色）
        confirmButton.setTitle("确定", for: .normal)
        confirmButton.setTitleColor(AppColor.Brand.primary, for: .normal)
        confirmButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        containerView.addSubview(confirmButton)
    }
    
    private func setupConstraints() {
        dimmingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(290)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        
        textField.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(40)
        }
        
        separatorH.snp.makeConstraints { make in
            make.top.equalTo(textField.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(0.5)
        }
        
        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(separatorH.snp.bottom)
            make.leading.equalToSuperview()
            make.width.equalToSuperview().dividedBy(2)
            make.height.equalTo(50)
            make.bottom.equalToSuperview()
        }
        
        separatorV.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(separatorH.snp.bottom)
            make.bottom.equalToSuperview()
            make.width.equalTo(0.5)
        }
        
        confirmButton.snp.makeConstraints { make in
            make.top.equalTo(separatorH.snp.bottom)
            make.trailing.equalToSuperview()
            make.width.equalToSuperview().dividedBy(2)
            make.height.equalTo(50)
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
    
    @objc private func cancelTapped() {
        hide {
            self.onCancel?()
        }
    }
    
    @objc private func confirmTapped() {
        // 拦截空字符串
        let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            // 这里可以给个抖动动画或直接忽略
            return
        }
        
        hide {
            self.onConfirm?(text)
        }
    }
    
    // MARK: - Show / Hide
    
    func show() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else { return }
        
        window.addSubview(self)
        self.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        
        // 延迟弹起键盘
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.textField.becomeFirstResponder()
        }
        
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
            self.containerView.transform = .identity
        }
    }
    
    private func hide(completion: (() -> Void)? = nil) {
        self.endEditing(true)
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
            self.containerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
}

//
//  ActionPickerViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/30.
//

import UIKit
import SnapKit

/// 耳机功能动作类型（支持的所有选项）
enum EarAction: String, CaseIterable {
    case modeSwitch = "模式切换"
    case volumeDown = "减小音量"
    case volumeUp   = "增大音量"
    case previous   = "上一曲"
    case next       = "下一曲"
    case playPause  = "播放/暂停"
    case none       = "无"
}

/// 自定义底部滚轮选择器
@MainActor
final class ActionPickerViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        static let pickerHeight: CGFloat = 250
        static let toolbarHeight: CGFloat = 50
    }

    // MARK: - Properties

    private let actionTitle: String
    private let options: [EarAction]
    private var selectedAction: EarAction
    private let onConfirm: (EarAction) -> Void

    // MARK: - UI

    private lazy var dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.alpha = 0
        let tap = UITapGestureRecognizer(target: self, action: #selector(cancelTapped))
        view.addGestureRecognizer(tap)
        return view
    }()

    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 16
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
        return view
    }()

    private lazy var toolbarView: UIView = {
        let view = UIView()
        // 底部细线
        let line = UIView()
        line.backgroundColor = UIColor(hex: "#E5E5EA")
        view.addSubview(line)
        line.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }
        return view
    }()

    private lazy var cancelButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("取消", for: .normal)
        btn.setTitleColor(UIColor(hex: "#333333"), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16)
        btn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = actionTitle
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor(hex: "#333333")
        label.textAlignment = .center
        return label
    }()

    private lazy var confirmButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("确认", for: .normal)
        btn.setTitleColor(AppColor.Brand.primary, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        btn.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var pickerView: UIPickerView = {
        let picker = UIPickerView()
        picker.dataSource = self
        picker.delegate = self
        return picker
    }()

    // MARK: - Init

    /// 初始化
    /// - Parameters:
    ///   - actionTitle: 操作类型标题（如："双击"）
    ///   - currentAction: 当前选中的动作
    ///   - onConfirm: 点击确认后的回调
    init(actionTitle: String, currentAction: EarAction, onConfirm: @escaping (EarAction) -> Void) {
        self.actionTitle = actionTitle
        self.options = EarAction.allCases
        self.selectedAction = currentAction
        self.onConfirm = onConfirm
        super.init(nibName: nil, bundle: nil)
        // 全屏覆盖，背景透明
        self.modalPresentationStyle = .overFullScreen
        self.modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        
        // 默认滚动到当前选中的行
        if let index = options.firstIndex(of: selectedAction) {
            pickerView.selectRow(index, inComponent: 0, animated: false)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showAnimate()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .clear
        
        view.addSubview(dimmingView)
        view.addSubview(containerView)
        
        containerView.addSubview(toolbarView)
        toolbarView.addSubview(cancelButton)
        toolbarView.addSubview(titleLabel)
        toolbarView.addSubview(confirmButton)
        
        containerView.addSubview(pickerView)
    }

    private func setupConstraints() {
        dimmingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 初始状态隐藏在屏幕底部
        containerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(view.snp.bottom)
        }
        
        toolbarView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Layout.toolbarHeight)
        }
        
        cancelButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }
        
        confirmButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        pickerView.snp.makeConstraints { make in
            make.top.equalTo(toolbarView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(Layout.pickerHeight)
        }
    }

    // MARK: - Animation

    private func showAnimate() {
        // 更新约束，让容器弹起（预留底部安全区高度）
        containerView.snp.remakeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(view.snp.bottom).offset(-(Layout.pickerHeight + Layout.toolbarHeight + view.safeAreaInsets.bottom))
        }
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.dimmingView.alpha = 1
            self.view.layoutIfNeeded()
        }
    }

    private func hideAnimate(completion: (() -> Void)? = nil) {
        // 恢复到底部隐藏
        containerView.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(view.snp.bottom)
        }
        
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
            self.dimmingView.alpha = 0
            self.view.layoutIfNeeded()
        }) { _ in
            self.dismiss(animated: false, completion: completion)
        }
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        hideAnimate()
    }

    @objc private func confirmTapped() {
        onConfirm(selectedAction)
        hideAnimate()
    }
}

// MARK: - UIPickerViewDataSource & UIPickerViewDelegate

extension ActionPickerViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return options.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return options[row].rawValue
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedAction = options[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 50
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel()
        label.text = options[row].rawValue
        label.textAlignment = .center
        // 选中和未选中字体颜色区分
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.textColor = UIColor(hex: "#333333")
        return label
    }
}

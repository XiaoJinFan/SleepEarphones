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

    /// 模式切换
    case modeSwitch = "模式切换"

    /// 减小音量
    case volumeDown = "减小音量"

    /// 增大音量
    case volumeUp = "增大音量"

    /// 上一曲
    case previous = "上一曲"

    /// 下一曲
    case next = "下一曲"

    /// 播放 / 暂停
    case playPause = "播放/暂停"

    /// 无（不绑定动作）
    case none = "无"

    /// 展示名称（**已本地化**）
    ///
    /// - Returns: 当前语言下的展示文案
    var displayName: String {
        switch self {
        case .modeSwitch: return LN("模式切换")
        case .volumeDown: return LN("减小音量")
        case .volumeUp:   return LN("增大音量")
        case .previous:   return LN("上一曲")
        case .next:       return LN("下一曲")
        case .playPause:  return LN("播放/暂停")
        case .none:       return LN("无")
        }
    }
}

/// 自定义底部滚轮选择器
///
/// ## 调用方法
/// ```swift
/// let picker = ActionPickerViewController(
///     actionTitle: "左耳双击",  // 调用方负责本地化（如 "\(ear.title)\(action.displayName)"）
///     currentAction: .volumeUp
/// ) { newAction in
///     // 用户点击"确认"
/// }
/// present(picker, animated: false)
/// ```
@MainActor
final class ActionPickerViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        static let pickerHeight: CGFloat = 250
        static let toolbarHeight: CGFloat = 50
        static let rowHeight: CGFloat = 50
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
        view.backgroundColor = AppColor.Background.card
        view.layer.cornerRadius = AppSpacing.Corner.card
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
        return view
    }()

    private lazy var toolbarView: UIView = {
        let view = UIView()
        // 底部细线
        let line = UIView()
        line.backgroundColor = AppColor.separator
        view.addSubview(line)
        line.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(AppSpacing.Border.hairline)
        }
        return view
    }()

    private lazy var cancelButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(L("取消"), for: .normal)
        btn.setTitleColor(AppColor.Text.primary, for: .normal)
        btn.titleLabel?.font = AppFont.Body.regular
        btn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = actionTitle
        label.font = AppFont.Body.emphasized
        label.textColor = AppColor.Text.primary
        label.textAlignment = .center
        return label
    }()

    private lazy var confirmButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(L("确认"), for: .normal)
        btn.setTitleColor(AppColor.Brand.primary, for: .normal)
        btn.titleLabel?.font = AppFont.Body.emphasized
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
    ///   - actionTitle: 操作类型标题（如："左耳双击"）——**调用方负责本地化**
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
            make.leading.equalToSuperview().offset(AppSpacing.md)
            make.centerY.equalToSuperview()
        }

        confirmButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-AppSpacing.md)
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

        UIView.animate(
            withDuration: AppSpacing.Animation.slow,
            delay: 0,
            options: .curveEaseOut
        ) {
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

        UIView.animate(
            withDuration: AppSpacing.Animation.standard,
            delay: 0,
            options: .curveEaseIn,
            animations: {
                self.dimmingView.alpha = 0
                self.view.layoutIfNeeded()
            }
        ) { _ in
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

    /// 纯文本行——用于系统默认渲染（不常用，因为 `viewForRow` 会覆盖）
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return options[row].displayName
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedAction = options[row]
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return Layout.rowHeight
    }

    /// 自定义行视图
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel()
        label.text = options[row].displayName
        label.textAlignment = .center
        label.font = AppFont.Title.section
        label.textColor = AppColor.Text.primary
        return label
    }
}

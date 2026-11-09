//
//  DeviceSettingsViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/30.
//

import UIKit
import SnapKit
import Combine

// MARK: - UserDefaults Keys

public enum AppUserDefaultsKeys {
    /// 敲击功能开关
    public static let deviceTouchFunctionEnabled = "device_touch_function_enabled"
    /// 所有提示音开关
    public static let deviceAllTonesEnabled = "device_all_tones_enabled"
}

/// 耳机设置页面（其他设置）
@MainActor
final class DeviceSettingsViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let cardCornerRadius: CGFloat = AppSpacing.Corner.card // 通用卡片圆角
        static let rowHeight: CGFloat = 56 // 单个卡片的高度
        static let sectionSpacing: CGFloat = 12 // ✅ 每个独立卡片之间的间距
        static let contentTopInset: CGFloat = 16
        static let contentBottomInset: CGFloat = 30
        
        static let rowHorizontalPadding: CGFloat = 16
        static let rowIconSize: CGFloat = 20 // 图标尺寸
        static let iconToTitleSpacing: CGFloat = 12 // 图标到文字的间距
    }

    // MARK: - Properties

    private let device: DeviceModel
    private var cancellables = Set<AnyCancellable>()

    @Published private var isTouchFunctionEnabled: Bool = {
        return UserDefaults.standard.object(forKey: AppUserDefaultsKeys.deviceTouchFunctionEnabled) as? Bool ?? true
    }()

    // 提出来以便动态修改设备名
    private lazy var deviceNameValueLabel: UILabel = {
        let label = UILabel()
        label.font = AppFont.Body.regular
        label.textColor = AppColor.Text.tertiary // 右侧文字偏灰
        label.textAlignment = .right
        label.text = device.name
        return label
    }()

    // MARK: - UI
    
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.contentInsetAdjustmentBehavior = .automatic
        return sv
    }()

    /// 主垂直栈：管理所有独立的卡片
    private lazy var contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Layout.sectionSpacing
        return stack
    }()

    // MARK: - Init

    init(device: DeviceModel) {
        self.device = device
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupUI()
        setupConstraints()
        buildContent()
        setupBindings()
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        self.title = L("其他设置")

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: AppColor.Text.primary]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = AppColor.Text.primary
    }

    private func setupUI() {
        view.backgroundColor = AppColor.Background.secondary // 浅灰背景色，衬托白色卡片
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
    }

    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentStackView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide).inset(UIEdgeInsets(
                top: Layout.contentTopInset,
                left: Layout.horizontalInset,
                bottom: Layout.contentBottomInset,
                right: Layout.horizontalInset
            ))
            make.width.equalTo(scrollView.frameLayoutGuide).offset(-Layout.horizontalInset * 2)
        }
    }

    // MARK: - Build Content

    private func buildContent() {
        // ==================== 卡片 1：禁用敲击 ====================
        let touchSwitch = UISwitch()
        touchSwitch.isOn = isTouchFunctionEnabled
        touchSwitch.onTintColor = AppColor.Brand.primary
        touchSwitch.addTarget(self, action: #selector(touchSwitchChanged(_:)), for: .valueChanged)

        let row1 = SettingsRowView(
            icon: "hand.raised",
            title: L("禁用敲击"),
            rightView: touchSwitch
        )
        contentStackView.addArrangedSubview(row1)

        // ==================== 卡片 2：设备名修改 ====================
        let row2 = SettingsRowView(
            icon: "square.and.pencil",
            title: L("设备名修改"),
            rightView: deviceNameValueLabel,
            showArrow: true
        ) { [weak self] in
            self?.showEditDeviceNameAlert()
        }
        contentStackView.addArrangedSubview(row2)
        
        // ==================== 卡片 3：查找设备 ====================
        let row3 = SettingsRowView(
            icon: "speaker.wave.2",
            title: L("查找设备"),
            showArrow: true
        ) { [weak self] in
            self?.navigationController?.pushViewController(FindDeviceViewController(), animated: true)
        }
        contentStackView.addArrangedSubview(row3)
        
        // ==================== 卡片 4：提示音开关 ====================
        let row4 = SettingsRowView(
            icon: "speaker.wave.1",
            title: L("提示音开关"),
            showArrow: true
        ) { [weak self] in
            self?.navigationController?.pushViewController(ToneSettingsViewController(), animated: true)
        }
        contentStackView.addArrangedSubview(row4)
        
        // ==================== 卡片 5：提示音音量调节 ====================
        let row5 = SettingsRowView(
            icon: "speaker.wave.3",
            title: L("提示音音量调节"),
            showArrow: true
        ) {
            AppLog.device.debug("点击提示音音量调节（待实现）")
        }
        contentStackView.addArrangedSubview(row5)
        
        // ==================== 卡片 6：耳机音量调节 ====================
        let row6 = SettingsRowView(
            icon: "headphones",
            title: L("耳机音量调节"),
            showArrow: true
        ) {
            AppLog.device.debug("点击耳机音量调节（待实现）")
        }
        contentStackView.addArrangedSubview(row6)
        
        // ==================== 卡片 7：固件升级 ====================
        let row7 = SettingsRowView(
            icon: "arrow.up.circle",
            title: L("固件升级"),
            showArrow: true
        ) { [weak self] in
            guard let self = self else { return }
            // 传入当前的设备模型
            let vc = FirmwareUpgradeViewController(device: self.device)
            self.navigationController?.pushViewController(vc, animated: true)
        }
        contentStackView.addArrangedSubview(row7)
        
        // ==================== 卡片 8：恢复默认 ====================
        let row8 = SettingsRowView(
            icon: "ellipsis.circle",
            title: L("恢复默认"),
            showArrow: true
        ) {
            AppLog.device.debug("点击恢复默认（待实现）")
        }
        contentStackView.addArrangedSubview(row8)
        
        // ==================== 卡片 9：恢复出厂 ====================
        let row9 = SettingsRowView(
            icon: "arrow.triangle.2.circlepath",
            title: L("恢复出厂"),
            showArrow: true
        ) {
            AppLog.device.debug("点击恢复出厂（待实现）")
        }
        contentStackView.addArrangedSubview(row9)
    }

    // MARK: - Bindings

    private func setupBindings() {
        $isTouchFunctionEnabled
            .dropFirst()
            .sink { isOn in
                UserDefaults.standard.set(isOn, forKey: AppUserDefaultsKeys.deviceTouchFunctionEnabled)
                AppLog.device.debug("保存敲击功能状态: \(isOn)")
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func touchSwitchChanged(_ sender: UISwitch) {
        isTouchFunctionEnabled = sender.isOn
    }

    private func showEditDeviceNameAlert() {
        let alert = InputAlertView(
            title: L("请输入"),
            placeholder: L("请输入名称"),
            currentText: deviceNameValueLabel.text
        )

        alert.onConfirm = { [weak self] newName in
            guard let self = self else { return }
            self.deviceNameValueLabel.text = newName
            self.showToast(L("修改成功"))
            AppLog.device.debug("设备名称已修改为: \(newName, privacy: .private)")
        }

        alert.show()
    }
}

// MARK: - 独立封装的单行卡片视图
@MainActor
private final class SettingsRowView: UIView {

    private let action: (() -> Void)?

    init(icon: String, title: String, rightView: UIView? = nil, showArrow: Bool = false, action: (() -> Void)? = nil) {
        self.action = action
        super.init(frame: .zero)
        setupUI(icon: icon, title: title, rightView: rightView, showArrow: showArrow)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI(icon: String, title: String, rightView: UIView?, showArrow: Bool) {
        // ✅ 核心：自身配置为独立的白色圆角卡片
        backgroundColor = AppColor.Background.card
        layer.cornerRadius = AppSpacing.Corner.card
        clipsToBounds = true
        
        // 1. 左侧图标
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = AppColor.Text.primary
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)
        
        // 2. 标题
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppFont.Body.regular
        titleLabel.textColor = AppColor.Text.primary
        addSubview(titleLabel)
        
        // 3. 右侧容器（文字、开关、箭头）
        let rightStack = UIStackView()
        rightStack.axis = .horizontal
        rightStack.spacing = 8
        rightStack.alignment = .center
        rightStack.isUserInteractionEnabled = false // 让点击穿透
        addSubview(rightStack)
        
        if let rightView = rightView {
            rightStack.addArrangedSubview(rightView)
        }
        
        if showArrow {
            let arrowView = UIImageView(image: UIImage(systemName: "chevron.right"))
            arrowView.tintColor = AppColor.Text.tertiary.withAlphaComponent(0.5)
            arrowView.contentMode = .scaleAspectFit
            rightStack.addArrangedSubview(arrowView)
            arrowView.snp.makeConstraints { make in
                make.width.height.equalTo(12)
            }
        }
        
        // 4. 布局约束
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16) // 卡片内左侧留白
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12) // 图标与文字间距
            make.centerY.equalToSuperview()
        }
        
        rightStack.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16) // 卡片内右侧留白
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(12)
        }
        
        // 卡片固定高度
        self.snp.makeConstraints { make in
            make.height.equalTo(64)
        }
        
        // 5. 整行点击事件
        if let action = action {
            let btn = UIButton(type: .custom)
            btn.addAction(UIAction { _ in action() }, for: .touchUpInside)
            addSubview(btn)
            btn.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            sendSubviewToBack(btn)
        }
    }
}

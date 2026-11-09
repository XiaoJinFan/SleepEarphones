//
//  DeviceControllerView.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/30.
//

import UIKit
import SnapKit
import Combine

/// 设备详情页
@MainActor
final class DeviceControllerView: UIViewController {

    // MARK: - SettingRow
    private enum SettingRow: Int {
        case soundLibrary   = 100
        case alarm          = 101
        case control        = 102
        case audioPause     = 103
        case moreSettings   = 104
    }

    // MARK: - MidButton
    private enum MidButton: Int {
        case startSleep      = 200
        case sleepReport     = 201
        case bluetoothMode   = 202
        case localMode       = 203
    }

    // MARK: - Layout
    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let cardCornerRadius: CGFloat = AppSpacing.Corner.card
        static let rowHeight: CGFloat = 64
        static let rowCornerRadius: CGFloat = AppSpacing.Corner.card
        static let midButtonHeight: CGFloat = 48 // 稍微调矮一点，更贴合设计图
        static let deviceImageSize: CGFloat = 160
    }

    // MARK: - Properties

    /// 当前展示的设备数据（由首页 `HomeViewController` 传入）
    private let device: DeviceModel

    private var cancellables = Set<AnyCancellable>()
    
    /// 当前选中的模式（默认蓝牙模式）
    private var isBluetoothMode: Bool = true

    // MARK: - UI - ScrollView 容器

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.contentInsetAdjustmentBehavior = .automatic
        return sv
    }()

    private lazy var contentView = UIView()

    // MARK: - UI - 顶部设备信息区

    private lazy var deviceNameLabel: UILabel = {
        let label = UILabel()
        label.text = L("设备名称")
        label.font = AppFont.Title.page
        label.textColor = .black
        label.textAlignment = .center
        return label
    }()

    private lazy var deviceImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = AppImage.Device.defaultDeviceLarge
        return iv
    }()

    // 电量区域容器（横向）
    private lazy var batteryStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 30 // 增大间距以适应新设计
        stack.alignment = .top
        stack.distribution = .equalSpacing
        return stack
    }()

    // MARK: - UI - 记录睡眠卡片

    private lazy var sleepCardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#E6E9EC") // 保持设计图原有的浅灰背景
        view.layer.cornerRadius = Layout.cardCornerRadius
        view.clipsToBounds = true
        return view
    }()

    private lazy var sleepTitleLabel: UILabel = {
        let label = UILabel()
        label.text = L("记录睡眠")
        label.font = AppFont.Body.emphasized
        label.textColor = .black
        return label
    }()

    private lazy var midButtonsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 14
        stack.distribution = .fillEqually
        return stack
    }()

    // MARK: - UI - 蓝牙模式选择区
    
    // 保存模式按钮的引用，方便切换状态
    private var bluetoothModeBtn: UIButton?
    private var localModeBtn: UIButton?

    private lazy var bleModeStateStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 14
        stack.distribution = .fillEqually
        return stack
    }()

    // MARK: - UI - 设置列表区

    private lazy var settingsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = AppSpacing.md
        stack.distribution = .fillEqually
        return stack
    }()

    private lazy var smartPauseSwitch: UISwitch = createSwitch()

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
        setupBindings()
        bindDeviceInfo()
    }

    // MARK: - Setup Navigation

    private func setupNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance

        navigationController?.navigationBar.tintColor = .black
        navigationItem.backButtonDisplayMode = .minimal
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = UIColor(hex: "#F5F6F7") // 浅灰背景

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // 顶部区域
        contentView.addSubview(deviceImageView)
        contentView.addSubview(deviceNameLabel)
        contentView.addSubview(batteryStackView)

        // 记录睡眠卡片
        contentView.addSubview(sleepCardView)
        sleepCardView.addSubview(sleepTitleLabel)
        sleepCardView.addSubview(midButtonsStackView)

        midButtonsStackView.addArrangedSubview(
            makeTexteBrutButton(title: L("开始记录"), tag: MidButton.startSleep.rawValue)
        )
        midButtonsStackView.addArrangedSubview(
            makeTexteBrutButton(title: L("睡眠报告"), tag: MidButton.sleepReport.rawValue)
        )

        // 蓝牙 / 本地模式
        contentView.addSubview(bleModeStateStackView)
        
        let bleBtn = makeTexteBrutButton(title: L("蓝牙模式"), tag: MidButton.bluetoothMode.rawValue)
        self.bluetoothModeBtn = bleBtn
        
        let localBtn = makeTexteBrutButton(title: L("本地模式"), tag: MidButton.localMode.rawValue)
        self.localModeBtn = localBtn
        
        bleModeStateStackView.addArrangedSubview(bleBtn)
        bleModeStateStackView.addArrangedSubview(localBtn)
        
        // 初始化模式状态
        updateModeUI(isBluetooth: isBluetoothMode)

        // 设置列表
        contentView.addSubview(settingsStackView)
        buildSettingsRows()
    }

    private func buildSettingsRows() {
        let soundLibraryRow = makeSettingsRow(
            icon: AppImage.Device.soundLibrary,
            title: L("声音库"),
            rightView: makeArrowIcon(),
            action: { [weak self] in self?.handleSettingRowTapped(.soundLibrary) }
        )

        let alarmRow = makeSettingsRow(
            icon: AppImage.Device.iconAlarm,
            title: L("闹钟"),
            rightView: makeArrowIcon(),
            action: { [weak self] in self?.handleSettingRowTapped(.alarm) }
        )

        let controlRow = makeSettingsRow(
            icon: AppImage.Device.iconFinger,
            title: L("敲击控制"),
            rightView: makeArrowIcon(),
            action: { [weak self] in self?.handleSettingRowTapped(.control) }
        )

        let audioPauseRow = makeSettingsRow(
            icon: AppImage.Device.iconVolume,
            title: L("智能停止音频"),
            rightView: smartPauseSwitch,
            action: { [weak self] in self?.handleSettingRowTapped(.audioPause) }
        )

        let moreSettingRow = makeSettingsRow(
            icon: AppImage.Device.iconMoreSettings,
            title: L("更多设置"),
            rightView: makeArrowIcon(),
            action: { [weak self] in self?.handleSettingRowTapped(.moreSettings) }
        )

        [soundLibraryRow, alarmRow, controlRow, audioPauseRow, moreSettingRow].forEach {
            settingsStackView.addArrangedSubview($0)
        }
    }

    // MARK: - Setup Constraints

    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        // 设备名称 (图片中名字是在图片上方)
        deviceNameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20) // 距离顶部安全区一点距离
            make.centerX.equalToSuperview()
        }

        // 设备大图
        deviceImageView.snp.makeConstraints { make in
            make.top.equalTo(deviceNameLabel.snp.bottom).offset(10)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(Layout.deviceImageSize)
        }

        // 三路电量
        batteryStackView.snp.makeConstraints { make in
            make.top.equalTo(deviceImageView.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
            make.width.equalTo(240) // 限制宽度让它们均匀分布
        }

        // 记录睡眠卡片
        sleepCardView.snp.makeConstraints { make in
            make.top.equalTo(batteryStackView.snp.bottom).offset(30)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        sleepTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalToSuperview().offset(16)
        }

        midButtonsStackView.snp.makeConstraints { make in
            make.top.equalTo(sleepTitleLabel.snp.bottom).offset(25)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(Layout.midButtonHeight)
            make.bottom.equalToSuperview().offset(-25)
        }

        // 蓝牙 / 本地模式
        bleModeStateStackView.snp.makeConstraints { make in
            make.top.equalTo(sleepCardView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.height.equalTo(Layout.midButtonHeight+12)
        }

        // 设置列表
        settingsStackView.snp.makeConstraints { make in
            make.top.equalTo(bleModeStateStackView.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.bottom.equalToSuperview().offset(-30)
        }
    }

    // MARK: - Bindings

    private func bindDeviceInfo() {
        // 设置真实的设备名称（XINGMAN）
        deviceNameLabel.text = device.name

        deviceImageView.setImage(
            device.imageURL,
            placeholder: AppImage.Device.defaultDeviceLarge
        )

        // 构建新的电量UI
        updateBatteryUI()
    }

    private func setupBindings() {
        smartPauseSwitch.publisher(for: \.isOn)
            .dropFirst()
            .sink { isOn in
                AppLog.device.debug("智能停止音频切换为: \(isOn)")
            }
            .store(in: &cancellables)
    }

    // MARK: - Helpers

    /// 更新电量区域 UI（匹配设计图：上方文字，下方进度条）
    private func updateBatteryUI() {
        // 清空旧视图
        batteryStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let left = Int(device.leftBattery) ?? 0
        let box = Int(device.batteryLevel) ?? 0
        let right = Int(device.rightBattery) ?? 0

        // 左耳 (蓝色)
        let leftView = makeNewBatteryView(level: left, type: "L", color: UIColor(hex: "#1B84CC"))
        // 充电盒 (红色，图中是20%，红色警示)
        let boxColor = box < 30 ? UIColor(hex: "#FF3B30") : UIColor(hex: "#1B84CC")
        let boxView = makeNewBatteryView(level: box, type: "C", color: boxColor)
        // 右耳 (蓝色)
        let rightView = makeNewBatteryView(level: right, type: "R", color: UIColor(hex: "#1B84CC"))

        batteryStackView.addArrangedSubview(leftView)
        batteryStackView.addArrangedSubview(boxView)
        batteryStackView.addArrangedSubview(rightView)
    }

    /// 创建单个电量视图（百分比 + L/C/R + 长条进度）
    private func makeNewBatteryView(level: Int, type: String, color: UIColor) -> UIView {
        let container = UIView()
        
        // 文本："100% L"
        let label = UILabel()
        label.text = "\(level)% \(type)"
        label.font = AppFont.Caption.regular // 14pt
        label.textColor = AppColor.Text.primary
        
        // 进度条背景
        let progressBg = UIView()
        progressBg.backgroundColor = UIColor(hex: "#E5E5EA") // 浅灰底色
        progressBg.layer.cornerRadius = 2
        progressBg.clipsToBounds = true
        
        // 进度条前景
        let progressFg = UIView()
        progressFg.backgroundColor = color
        progressFg.layer.cornerRadius = 2
        progressFg.clipsToBounds = true
        
        container.addSubview(label)
        container.addSubview(progressBg)
        progressBg.addSubview(progressFg)
        
        // 布局
        label.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
        }
        
        progressBg.snp.makeConstraints { make in
            make.top.equalTo(label.snp.bottom).offset(6)
            make.centerX.equalToSuperview()
            make.width.equalTo(50) // 进度条固定宽度
            make.height.equalTo(4)  // 进度条高度
            make.bottom.equalToSuperview()
        }
        
        // 根据百分比计算前景宽度
        let percent = CGFloat(max(0, min(100, level))) / 100.0
        progressFg.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(percent)
        }
        
        return container
    }

    /// 切换 蓝牙/本地 模式的 UI 状态
    private func updateModeUI(isBluetooth: Bool) {
        let selectedColor = UIColor(hex: "#1B84CC") // 主题蓝
        let unselectedColor = UIColor.white
        
        if isBluetooth {
            bluetoothModeBtn?.backgroundColor = selectedColor
            bluetoothModeBtn?.setTitleColor(.white, for: .normal)
            
            localModeBtn?.backgroundColor = unselectedColor
            localModeBtn?.setTitleColor(AppColor.Text.primary, for: .normal)
        } else {
            localModeBtn?.backgroundColor = selectedColor
            localModeBtn?.setTitleColor(.white, for: .normal)
            
            bluetoothModeBtn?.backgroundColor = unselectedColor
            bluetoothModeBtn?.setTitleColor(AppColor.Text.primary, for: .normal)
        }
    }

    // MARK: - Setting Row Actions

    private func handleSettingRowTapped(_ row: SettingRow) {
        switch row {
        case .soundLibrary: pushMusicLibrary()
        case .alarm: navigationController?.pushViewController(AlarmViewController(), animated: true)
        case .control: navigationController?.pushViewController(GuestViewController(), animated: true)
        case .audioPause: showToast(L("点击开关可切换智能停止音频"))
        case .moreSettings:
            let settingsVC = DeviceSettingsViewController(device: device)
            navigationController?.pushViewController(settingsVC, animated: true)
        }
    }

    private func pushMusicLibrary() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let musicVC = storyboard.instantiateViewController(
            withIdentifier: "MusicViewController"
        ) as? MusicViewController else { return }
        musicVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(musicVC, animated: true)
    }

    // MARK: - Mid Button Actions

    @objc private func midButtonTapped(_ sender: UIButton) {
        guard let button = MidButton(rawValue: sender.tag) else { return }

        switch button {
        case .startSleep:
            AppLog.device.debug("点击开始记录睡眠")
            let monitorVC = SleepMonitorViewController()
            monitorVC.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(monitorVC, animated: true)
        case .sleepReport:
            showToast(L("睡眠报告页面开发中"))
        case .bluetoothMode:
            // 如果已经是蓝牙模式，不处理
            guard !isBluetoothMode else { return }
            isBluetoothMode = true
            updateModeUI(isBluetooth: true)
            AppLog.device.debug("切换到蓝牙模式")
            // TODO: 下发对应 BLE 指令
            
        case .localMode:
            // 如果已经是本地模式，不处理
            guard isBluetoothMode else { return }
            isBluetoothMode = false
            updateModeUI(isBluetooth: false)
            AppLog.device.debug("切换到本地模式")
            // TODO: 下发对应 BLE 指令
        }
    }
}

// MARK: - UI 组件工厂方法

extension DeviceControllerView {

    private func createSwitch() -> UISwitch {
        let sw = UISwitch()
        sw.onTintColor = UIColor(hex: "#1B84CC")
        return sw
    }

    /// 创建纯文本的按钮
    private func makeTexteBrutButton(title: String, tag: Int) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.tag = tag
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = AppFont.Body.regular
        btn.layer.cornerRadius = AppSpacing.Corner.button
        btn.addTarget(self, action: #selector(midButtonTapped(_:)), for: .touchUpInside)
        
        // 默认白底（用于睡眠卡片内的按钮）
        btn.backgroundColor = .white
        btn.setTitleColor(AppColor.Text.primary, for: .normal)
        
        return btn
    }

    /// 创建行尾箭头图标
    private func makeArrowIcon() -> UIImageView {
        let iv = UIImageView()
        iv.image = AppImage.System.chevronRight.withRenderingMode(.alwaysTemplate)
        iv.tintColor = UIColor(hex: "#C7C7CC") // 浅灰箭头
        iv.contentMode = .scaleAspectFit
        iv.snp.makeConstraints { make in
            make.width.equalTo(7)
            make.height.equalTo(13)
        }
        return iv
    }

    /// 创建设置列表行
    private func makeSettingsRow(icon: UIImage, title: String, rightView: UIView, action: (() -> Void)? = nil) -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = Layout.rowCornerRadius
        container.clipsToBounds = true

        // 左侧图标
        let iconView = UIImageView(image: icon)
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .black // 如果原图是黑色
        container.addSubview(iconView)

        // 标题
        let label = UILabel()
        label.text = title
        label.font = AppFont.Body.regular
        label.textColor = AppColor.Text.primary
        container.addSubview(label)

        // 右侧视图
        container.addSubview(rightView)

        // 布局
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20) // 图标统一 20x20
        }

        label.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(16)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(rightView.snp.leading).offset(-AppSpacing.sm)
        }

        rightView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
        }

        // 整行点击
        if let action = action {
            let btn = UIButton(type: .custom)
            btn.addAction(UIAction { _ in action() }, for: .touchUpInside)
            container.addSubview(btn)
            btn.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            container.sendSubviewToBack(btn)
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(Layout.rowHeight)
        }

        return container
    }
}

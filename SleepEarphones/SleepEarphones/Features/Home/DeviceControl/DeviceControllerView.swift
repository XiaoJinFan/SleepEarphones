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

    // MARK: - Constants

    /// 设置行标识（替代魔法数字 `tag`）
    private enum SettingRow: Int {
        case soundLibrary       = 100
        case alarm              = 101
        case control            = 102
        case AudioPause         = 103
        case moreSettings       = 104
    }

    /// 中间卡片按钮标识（替代魔法数字 `tag`）
    private enum MidButton: Int {
        case startSleep = 200
        case sleepReport  = 201
        case classBleModel  = 202
        case bleModel       = 203
    }

    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let cardCornerRadius: CGFloat = AppSpacing.Corner.card
        static let rowHeight: CGFloat = 64
        static let rowCornerRadius: CGFloat = AppSpacing.Corner.card
        static let recordButtonHeight: CGFloat = 32
        static let recordButtonCornerRadius: CGFloat = 16
        static let midButtonHeight: CGFloat = 51
        static let deviceImageSize: CGFloat = 153
    }

    // MARK: - Properties

    /// 当前展示的设备数据（由首页 `HomeViewController` 传入）
    private let device: DeviceModel

    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI - ScrollView 容器

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        // 依赖系统自动处理安全区（导航栏高度）
        sv.contentInsetAdjustmentBehavior = .automatic
        return sv
    }()

    private lazy var contentView = UIView()

    // MARK: - UI - 顶部设备信息区

    private lazy var deviceImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = AppImage.Device.defaultDeviceLarge
        return iv
    }()

    private lazy var deviceNameLabel: UILabel = {
        let label = UILabel()
        // 初始占位文案（**已本地化**）——`bindDeviceInfo` 会用真实名称覆盖
        label.text = L("设备名称")
        label.font = AppFont.Body.emphasized
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private lazy var batteryStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 29
        stack.alignment = .center
        stack.distribution = .equalSpacing
        return stack
    }()

    // 电量 Label 引用
    private let leftBatteryLabel = UILabel()
    private let rightBatteryLabel = UILabel()
    private let boxBatteryLabel = UILabel()

    // MARK: - UI - 记录睡眠卡片

    private lazy var sleepCardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#E6E9EC")
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

    // 开始记录 / 睡眠报告 按钮栈
    private lazy var midButtonsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 14
        stack.distribution = .fillEqually
        return stack
    }()
    
    // MARK: - UI - 蓝牙模式选择区
    
    // 蓝牙模式 / 本地模式 按钮栈
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

    // 开关控件引用
    private lazy var sleepModeSwitch: UISwitch = createSwitch()
    private lazy var smartVolumeSwitch: UISwitch = createSwitch()

    // 智能音量整行（默认隐藏）
    private lazy var smartVolumeRow = makeSettingsRow(
        icon: AppImage.Device.iconVolume,
        title: L("智能音量"),
        rightView: smartVolumeSwitch,
        isHidden: false,
        showInfoIcon: true
    )

    // MARK: - Init

    /// 初始化
    /// - Parameter device: 由列表页传入的设备模型
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
        // 1. 配置透明的导航栏
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance

        // 2. 设置整体图标颜色（适配深色背景，让系统返回按钮变白）
        navigationController?.navigationBar.tintColor = .white

        // 3. 左侧返回按钮：不写任何 leftBarButtonItem 的代码，依靠系统原生居中
        navigationItem.backButtonDisplayMode = .minimal
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = UIColor(hex: "#F5F6F7")

        // 添加滚动视图
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // 顶部区域
        contentView.addSubview(deviceImageView)
        contentView.addSubview(deviceNameLabel)
        contentView.addSubview(batteryStackView)

        // 构建三路电量
        let leftBatteryView = makeBatteryView(
            image: AppImage.Device.leftEar,
            label: leftBatteryLabel,
            isBox: false
        )
        let rightBatteryView = makeBatteryView(
            image: AppImage.Device.rightEar,
            label: rightBatteryLabel,
            isBox: false
        )
        let boxBatteryView = makeBatteryView(
            image: AppImage.Device.batteryBox,
            label: boxBatteryLabel,
            isBox: true
        )

        [leftBatteryView, rightBatteryView, boxBatteryView].forEach {
            batteryStackView.addArrangedSubview($0)
        }

        // 记录睡眠卡片
        contentView.addSubview(sleepCardView)
        sleepCardView.addSubview(sleepTitleLabel)
        sleepCardView.addSubview(midButtonsStackView)

        // 构建开始记录/睡眠报告按钮
        midButtonsStackView.addArrangedSubview(
            makeTexteBrutButton(
                title: L("开始记录"),
                tag: MidButton.startSleep.rawValue
            )
        )
        midButtonsStackView.addArrangedSubview(
            makeTexteBrutButton(
                title: L("睡眠报告"),
                tag: MidButton.sleepReport.rawValue
            )
        )
        
        // 构建蓝牙模式/本地模式按钮
        contentView.addSubview(bleModeStateStackView)
        bleModeStateStackView.addArrangedSubview(
            makeTexteBrutButton(
                title: L("蓝牙模式"),
                tag: MidButton.classBleModel.rawValue
            )
        )
        bleModeStateStackView.addArrangedSubview(
            makeTexteBrutButton(
                title: L("本地模式"),
                tag: MidButton.bleModel.rawValue
            )
        )

        // 设置列表
        contentView.addSubview(settingsStackView)
        buildSettingsRows()
    }

    private func buildSettingsRows() {
        // 1. 音频库
        let soundLibraryRow = makeSettingsRow(
            icon: AppImage.Device.soundLibrary,
            title: L("音频库"),
            rightView: makeArrowIcon(),
            action: { [weak self] in self?.typeRowTapped(row: .soundLibrary) }
        )
        
        // 2. 闹钟
        let alarmRow = makeSettingsRow(
            icon: AppImage.Device.iconAlarm,
            title: L("闹钟"),
            rightView: makeArrowIcon(),
            action: { [weak self] in self?.typeRowTapped(row: .alarm) }
        )
        
        // 3. 敲击控制
        let controlRow = makeSettingsRow(
            icon: AppImage.Device.iconFinger,
            title: L("敲击控制"),
            rightView: makeArrowIcon(),
            action: { [weak self] in self?.typeRowTapped(row: .control) }
        )
        
        // 4. 智能停止音频
        let intelligentAudioPauseRow = makeSettingsRow(
            icon: AppImage.Device.iconVolume,
            title: L("智能停止音频"),
            rightView: sleepModeSwitch,
            action: { [weak self] in self?.typeRowTapped(row: .AudioPause) }
        )
        
        // 5. 更多设置
        let moreSettingRow = makeSettingsRow(
            icon: AppImage.Device.iconMoreSettings,
            title: L("更多设置"),
            rightView: makeArrowIcon(),
            action: { [weak self] in self?.typeRowTapped(row: .moreSettings) }
        )

        [soundLibraryRow, alarmRow, controlRow, intelligentAudioPauseRow, moreSettingRow].forEach {
            settingsStackView.addArrangedSubview($0)
        }
    }

    // MARK: - Setup Constraints

    private func setupConstraints() {
        // 滚动视图铺满全屏
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        // 设备图片
        deviceImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(AppSpacing.lg)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(Layout.deviceImageSize)
        }

        // 设备名称
        deviceNameLabel.snp.makeConstraints { make in
            make.top.equalTo(deviceImageView.snp.bottom).offset(AppSpacing.md)
            make.centerX.equalToSuperview()
        }

        // 电量 Stack
        batteryStackView.snp.makeConstraints { make in
            make.top.equalTo(deviceNameLabel.snp.bottom).offset(AppSpacing.xl)
            make.centerX.equalToSuperview()
            make.height.equalTo(AppSpacing.lg)
        }

        // 记录睡眠卡片
        sleepCardView.snp.makeConstraints { make in
            make.top.equalTo(batteryStackView.snp.bottom).offset(AppSpacing.xxl)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        sleepTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(AppSpacing.lg)
            make.leading.equalToSuperview().offset(AppSpacing.md)
        }

        midButtonsStackView.snp.makeConstraints { make in
            make.top.equalTo(sleepTitleLabel.snp.bottom).offset(AppSpacing.xl)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.md)
            make.height.equalTo(Layout.midButtonHeight)
            make.bottom.equalToSuperview().offset(-AppSpacing.md)
        }
        
        // 蓝牙状态卡片
        bleModeStateStackView.snp.makeConstraints { make in
            make.top.equalTo(sleepCardView.snp.bottom).offset(AppSpacing.md)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.height.equalTo(Layout.midButtonHeight+19)
        }

        // 设置列表区
        settingsStackView.snp.makeConstraints { make in
            make.top.equalTo(bleModeStateStackView.snp.bottom).offset(AppSpacing.md)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.bottom.equalToSuperview().offset(-AppSpacing.lg)
        }
    }

    // MARK: - Bindings

    /// 绑定静态设备信息
    private func bindDeviceInfo() {
        deviceNameLabel.text = device.name

        // 加载设备大图，若无则用默认大图占位
        deviceImageView.setImage(
            device.imageURL,
            placeholder: AppImage.Device.defaultDeviceLarge
        )

        // 电量数据（`%` 是数字格式，不需要国际化）
        leftBatteryLabel.text = device.leftBattery.isEmpty
            ? "100%"
            : "\(device.leftBattery)%"
        rightBatteryLabel.text = device.rightBattery.isEmpty
            ? "100%"
            : "\(device.rightBattery)%"
        boxBatteryLabel.text = device.batteryLevel.isEmpty
            ? "100%"
            : "\(device.batteryLevel)%"
    }

    /// 绑定 BLE 实时状态（预留）
    private func setupBindings() {
        // 睡眠模式开关
        sleepModeSwitch.publisher(for: \.isOn)
            .dropFirst()
            .sink { [weak self] isOn in
                guard self != nil else { return }
                AppLog.device.debug("睡眠模式切换为: \(isOn)")
                // TODO: 下发 BLE 指令
            }
            .store(in: &cancellables)

        // 智能音量开关
        smartVolumeSwitch.publisher(for: \.isOn)
            .dropFirst()
            .sink { [weak self] isOn in
                guard self != nil else { return }
                AppLog.device.debug("智能音量切换为: \(isOn)")
                // TODO: 下发 BLE 指令
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    /// 点击睡眠模式旁边的问号图标
    @objc private func infoIconTapped(_ sender: UIButton) {
        if sender.accessibilityIdentifier == L("睡眠模式") {
            showAlert(
                L("启用此模式以节省电池并延长播放时间。注意：您只能访问已传输到耳机中的内置音频文件。如需更换内置音频，请访问音频库。"),
                title: L("提示")
            )
        } else {
            showAlert(
                L("智能音量会根据周围的噪音自动调整音量。请保持应用程序处于开启状态，以确保此功能正常运作。"),
                title: L("提示")
            )
        }
        
    }

    /// 设置行点击
    ///
    /// - Parameter row: 行标识（枚举，替代魔法数字）
    private func typeRowTapped(row: SettingRow) {
        AppLog.device.debug("点击列表项: \(row.rawValue)")
        
            
        switch row {
        case .soundLibrary:
            // 跳转音频库
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let musicVC = storyboard.instantiateViewController(
                withIdentifier: "MusicViewController"
            ) as? MusicViewController {
                musicVC.hidesBottomBarWhenPushed = true
                navigationController?.pushViewController(musicVC, animated: true)
            }
            
        case .alarm:
            // 跳转闹钟模式页面
            let alarmVC = AlarmViewController()
            navigationController?.pushViewController(alarmVC, animated: true)
            
        case .control:
            let controlVC = GuestViewController()
            navigationController?.pushViewController(controlVC, animated: true)
            
        case .AudioPause:
            showToast(L("点击智能停止音频"))
            
        case .moreSettings:
            let settingsVC = DeviceSettingsViewController(device: device)
            navigationController?.pushViewController(settingsVC, animated: true)
        }
    }

    /// 带图片的按钮点击
    ///
    /// - Parameter sender: 触发的按钮
    @objc private func textAndImgBtnTapped(_ sender: UIButton) {
        guard let button = MidButton(rawValue: sender.tag) else { return }
        AppLog.device.debug("点击中间卡片按钮: \(sender.tag)")
    }
    
    /// 纯文本的按钮点击
    ///
    /// - Parameter sender: 触发的按钮
    @objc private func texteBrutBtnTapped(_ sender: UIButton) {
        guard let button = MidButton(rawValue: sender.tag) else { return }
        AppLog.device.debug("点击中间卡片按钮: \(sender.tag)")
        
        switch button {
        case .startSleep:
            // 开始记录睡眠
            AppLog.device.debug("点击开始记录睡眠")
            
        case .sleepReport:
            showToast(L("睡眠报告页面开发中"))
            
        case .classBleModel:
            showToast(L("睡眠报告页面开发中"))
            
        case .bleModel:
            showToast(L("睡眠报告页面开发中"))
        }
    }
}

// MARK: - UI 组件工厂方法

extension DeviceControllerView {

    /// 创建 UISwitch
    private func createSwitch() -> UISwitch {
        let sw = UISwitch()
        sw.onTintColor = AppColor.Device.switchTint
        return sw
    }

    /// 创建电量胶囊视图
    private func makeBatteryView(image: UIImage, label: UILabel, isBox: Bool) -> UIView {
        let container = UIView()
        container.backgroundColor = AppColor.Device.batteryGreen
        container.layer.cornerRadius = 10
        container.clipsToBounds = true

        let iconView = UIImageView(image: image)
        iconView.contentMode = .scaleAspectFit
        container.addSubview(iconView)
        container.addSubview(label)

        // 占位值（会被 `bindDeviceInfo` 用真实电量覆盖）
        label.text = "100%"
        label.font = AppFont.Caption.tiny
        label.textColor = .white
        label.textAlignment = .left

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.width.equalTo(isBox ? 14 : 7)
            make.height.equalTo(10)
        }

        label.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(5)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-10)
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(AppSpacing.lg)
            make.width.greaterThanOrEqualTo(65)
        }

        return container
    }

    /// 创建带图片的按钮
    ///
    /// - Parameters:
    ///   - title: 按钮标题（**调用方需传入已本地化字符串**）
    ///   - image: 图标
    ///   - tag: `MidButton` 的 rawValue
    private func makeTextAndImgButton(title: String, image: UIImage, tag: Int) -> UIView {
        let container = UIView()
        container.backgroundColor = AppColor.Device.soundAndSleepBackground
        container.layer.cornerRadius = AppSpacing.Corner.button
        container.clipsToBounds = true

        let btn = UIButton(type: .custom)
        btn.tag = tag
        btn.addTarget(self, action: #selector(textAndImgBtnTapped(_:)), for: .touchUpInside)
        
        let iconView = UIImageView(image: image)
        iconView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = title
        label.font = AppFont.Body.emphasized
        label.textColor = AppColor.Device.buttonTextLightBlue

        container.addSubview(iconView)
        container.addSubview(label)
        container.addSubview(btn)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(36)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(AppSpacing.lg)
        }

        label.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(AppSpacing.xs)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-10)
        }

        btn.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        return container
    }
    
    /// 创建纯文本的按钮
    ///
    /// - Parameters:
    ///   - title: 按钮标题（**调用方需传入已本地化字符串**）
    ///   - tag: `MidButton` 的 rawValue
    private func makeTexteBrutButton(title: String, tag: Int) -> UIView {
        let container = UIView()
        container.layer.cornerRadius = AppSpacing.Corner.button
        container.clipsToBounds = true
        
        let btn = UIButton(type: .custom)
        btn.tag = tag
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = AppFont.Body.regular
        btn.setTitleColor(.black, for: .normal)
        btn.backgroundColor = .white
        btn.addTarget(self, action: #selector(texteBrutBtnTapped(_:)), for: .touchUpInside)
        
        container.addSubview(btn)
        btn.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        return container
    }

    /// 创建行尾箭头图标
    private func makeArrowIcon() -> UIImageView {
        let iv = UIImageView()
        // 安全解包：兼容 iconArrowNext 为可选类型的情况
        if let nextImg = AppImage.Device.iconArrowNext {
            iv.image = nextImg.withRenderingMode(.alwaysTemplate)
        } else {
            iv.image = UIImage(systemName: "chevron.right")?.withRenderingMode(.alwaysTemplate)
        }

        iv.tintColor = AppColor.Device.arrowGray
        iv.contentMode = .scaleAspectFit
        iv.snp.makeConstraints { make in
            make.width.equalTo(7)
            make.height.equalTo(13)
        }
        return iv
    }

    /// 创建设置列表行
    ///
    /// - Parameters:
    ///   - icon: 左侧图标
    ///   - title: 标题（**调用方需传入已本地化字符串**）
    ///   - rightView: 右侧视图（`UISwitch` / `UIImageView` 箭头等）
    ///   - isHidden: 是否隐藏（用于 `smartVolumeRow` 的默认隐藏）
    ///   - showInfoIcon: 是否在标题右侧显示问号图标
    ///   - action: 整行点击回调（`nil` 时不响应点击）
    private func makeSettingsRow(icon: UIImage, title: String, rightView: UIView, isHidden: Bool = false, showInfoIcon: Bool = false, action: (() -> Void)? = nil) -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = Layout.rowCornerRadius
        container.clipsToBounds = true
        container.isHidden = isHidden

        // 左侧图标
        let iconView = UIImageView(image: icon)
        iconView.contentMode = .scaleAspectFit
        container.addSubview(iconView)

        // 标题
        let label = UILabel()
        label.text = title
        label.font = AppFont.Body.regular
        label.textColor = .black
        container.addSubview(label)

        // 帮助信息图标（可选，改用 Button 以支持点击交互）
        if showInfoIcon {
            let infoBtn = UIButton(type: .custom)
            infoBtn.accessibilityIdentifier = title
            infoBtn.setImage(AppImage.Device.iconInfo, for: .normal)
            infoBtn.addTarget(self, action: #selector(infoIconTapped(_:)), for: .touchUpInside)
            container.addSubview(infoBtn)

            infoBtn.snp.makeConstraints { make in
                make.leading.equalTo(label.snp.trailing).offset(10)
                make.centerY.equalTo(label)
                make.width.height.equalTo(AppSpacing.md)
            }
        }

        // 右侧视图
        container.addSubview(rightView)

        // 布局
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(AppSpacing.md)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(25)
        }

        label.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(AppSpacing.md)
            make.centerY.equalToSuperview()
        }

        // 右侧约束
        rightView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-AppSpacing.md)
            make.centerY.equalToSuperview()
        }

        // 整行点击（如果有 action 且不是 Switch）
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

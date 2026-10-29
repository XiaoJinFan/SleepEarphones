//
//  DeviceDetailsController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/22.
//

import UIKit
import SnapKit
import Combine

/// 设备详情页
///
/// ## 职责
/// - 展示设备图片、名称、三路电量（左/右/充电盒）
/// - 承载睡眠记录、睡眠模式、智能音量等功能的入口
/// - 使用纯代码 + SnapKit + Combine 替换原 XIB 布局
@MainActor
final class DeviceDetailsController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let cardCornerRadius: CGFloat = 19
        static let rowHeight: CGFloat = 64
        static let rowCornerRadius: CGFloat = 13
    }

    // MARK: - Properties

    /// 当前展示的设备数据（由首页 HomeViewController 传入）
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
        label.text = "设备名称"
        label.font = .systemFont(ofSize: 16, weight: .medium)
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
        view.backgroundColor = AppColor.Device.cardBackground
        view.layer.cornerRadius = Layout.cardCornerRadius
        view.clipsToBounds = true
        return view
    }()

    private lazy var sleepTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "记录睡眠"
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = .white
        return label
    }()

    private lazy var startRecordButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .white
        config.baseForegroundColor = AppColor.Device.cardBackground
        
        config.cornerStyle = .fixed
        config.background.cornerRadius = 16 // 32 高的一半
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        
        var titleAttr = AttributedString("开始记录")
        titleAttr.font = .systemFont(ofSize: 14, weight: .bold)
        config.attributedTitle = titleAttr
        
        let btn = UIButton(configuration: config)
        btn.addTarget(self, action: #selector(startBtnClick), for: .touchUpInside)
        return btn
    }()

    private lazy var sleepDescLabel: UILabel = {
        let label = UILabel()
        label.text = "睡眠记录通过设备或软件采集入睡时长、睡眠阶段等数据，评估睡眠与健康状况"
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }()

    // 声音库 / 睡眠报告 按钮栈
    private lazy var midButtonsStackView: UIStackView = {
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
        stack.spacing = 16
        stack.distribution = .fillEqually
        return stack
    }()

    // 开关控件引用
    private lazy var sleepModeSwitch: UISwitch = createSwitch()
    private lazy var smartVolumeSwitch: UISwitch = createSwitch()
    
    // 智能音量整行（默认隐藏）
    private lazy var smartVolumeRow = makeSettingsRow(
        icon: AppImage.Device.iconVolume,
        title: "智能音量",
        rightView: smartVolumeSwitch,
        isHidden: true
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

        // 3. 左侧返回按钮：不要写任何 leftBarButtonItem 的代码！
        // 只要不写，系统会自动生成绝对居中的 `<` 箭头，并完美支持侧滑手势。
        
        // 如果你想隐藏返回按钮旁边的文字（默认可能是上一页的标题），可以加上这句
        // 注意：这个设置最好写在上一页（HomeViewController），在当前页写是影响下一页的
        // 但你可以尝试在这里写上，看看能否覆盖系统默认行为
        navigationItem.backButtonDisplayMode = .minimal

        // 4. 设置右侧按钮（使用系统纯原生图标）
        let helpItem = UIBarButtonItem(
            image: UIImage(systemName: "headphones"),
            style: .plain,
            target: self,
            action: #selector(helpBtnClick)
        )
        let settingsItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(setBtnClick)
        )
        
        // 数组顺序：left 到 right
        navigationItem.rightBarButtonItems = [settingsItem, helpItem]
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = AppColor.Device.background

        // 添加滚动视图
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // 顶部区域
        contentView.addSubview(deviceImageView)
        contentView.addSubview(deviceNameLabel)
        contentView.addSubview(batteryStackView)
        
        // 构建三路电量
        let leftBatteryView = makeBatteryView(image: AppImage.Device.leftEar, label: leftBatteryLabel, isBox: false)
        let rightBatteryView = makeBatteryView(image: AppImage.Device.rightEar, label: rightBatteryLabel, isBox: false)
        let boxBatteryView = makeBatteryView(image: AppImage.Device.batteryBox, label: boxBatteryLabel, isBox: true)
        
        [leftBatteryView, rightBatteryView, boxBatteryView].forEach {
            batteryStackView.addArrangedSubview($0)
        }

        // 记录睡眠卡片
        contentView.addSubview(sleepCardView)
        sleepCardView.addSubview(sleepTitleLabel)
        sleepCardView.addSubview(startRecordButton)
        sleepCardView.addSubview(sleepDescLabel)
        sleepCardView.addSubview(midButtonsStackView)

        // 构建声音库/睡眠报告按钮
        midButtonsStackView.addArrangedSubview(makeMidButton(title: "声音库", image: AppImage.Device.soundLibrary, tag: 200))
        midButtonsStackView.addArrangedSubview(makeMidButton(title: "睡眠报告", image: AppImage.Device.sleepReport, tag: 201))

        // 设置列表
        contentView.addSubview(settingsStackView)
        buildSettingsRows()
    }

    private func buildSettingsRows() {
        // 1. 睡眠模式
        let sleepModeRow = makeSettingsRow(
            icon: AppImage.Device.iconMoon,
            title: "睡眠模式",
            rightView: sleepModeSwitch,
            showInfoIcon: true
        )
        
        // 3. 闹钟模式
        let alarmRow = makeSettingsRow(
            icon: AppImage.Device.iconAlarm,
            title: "闹钟模式",
            rightView: makeArrowIcon(),
            action: { [weak self] in self?.typeRowTapped(tag: 100) }
        )
        
        // 4. 睡眠定时
        let timerRow = makeSettingsRow(
            icon: AppImage.Device.iconTimer,
            title: "睡眠定时",
            rightView: makeArrowIcon(),
            action: { [weak self] in self?.typeRowTapped(tag: 101) }
        )
        
        // 5. 控制
        let controlRow = makeSettingsRow(
            icon: AppImage.Device.iconFinger,
            title: "控制",
            rightView: makeArrowIcon(),
            action: { [weak self] in self?.typeRowTapped(tag: 102) }
        )
        
        // 6. 音效
        let soundRow = makeSettingsRow(
            icon: AppImage.Device.iconSpeaker,
            title: "音效",
            rightView: makeArrowIcon(),
            action: { [weak self] in self?.typeRowTapped(tag: 103) }
        )

        [sleepModeRow, smartVolumeRow, alarmRow, timerRow, controlRow, soundRow].forEach {
            settingsStackView.addArrangedSubview($0)
        }
    }

    // MARK: - Setup Constraints

    private func setupConstraints() {
        // 滚动视图铺满全屏，让系统通过 contentInsetAdjustmentBehavior 自动处理导航栏高度
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        // 设备图片
        deviceImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.centerX.equalToSuperview()
            make.width.equalTo(153)
            make.height.equalTo(153)
        }

        // 设备名称
        deviceNameLabel.snp.makeConstraints { make in
            make.top.equalTo(deviceImageView.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
        }

        // 电量 Stack
        batteryStackView.snp.makeConstraints { make in
            make.top.equalTo(deviceNameLabel.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
            make.height.equalTo(20)
        }

        // 记录睡眠卡片
        sleepCardView.snp.makeConstraints { make in
            make.top.equalTo(batteryStackView.snp.bottom).offset(32)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        sleepTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(21)
            make.leading.equalToSuperview().offset(16)
        }

        startRecordButton.snp.makeConstraints { make in
            make.centerY.equalTo(sleepTitleLabel)
            make.trailing.equalToSuperview().offset(-16)
            make.height.equalTo(32)
        }

        sleepDescLabel.snp.makeConstraints { make in
            make.top.equalTo(sleepTitleLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        midButtonsStackView.snp.makeConstraints { make in
            make.top.equalTo(sleepDescLabel.snp.bottom).offset(25)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(51)
            make.bottom.equalToSuperview().offset(-16)
        }

        // 设置列表区
        settingsStackView.snp.makeConstraints { make in
            make.top.equalTo(sleepCardView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.bottom.equalToSuperview().offset(-20)
        }
    }

    // MARK: - Bindings

    /// 绑定静态设备信息
    private func bindDeviceInfo() {
        deviceNameLabel.text = device.name
        
        // 加载设备大图，若无则用默认大图占位
        deviceImageView.setImage(device.imageURL, placeholder: AppImage.Device.defaultDeviceLarge)
        
        // 电量数据
        leftBatteryLabel.text = device.leftBattery.isEmpty ? "100%" : "\(device.leftBattery)%"
        rightBatteryLabel.text = device.rightBattery.isEmpty ? "100%" : "\(device.rightBattery)%"
        boxBatteryLabel.text = device.batteryLevel.isEmpty ? "100%" : "\(device.batteryLevel)%"
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

    @objc private func setBtnClick() {
        AppLog.device.debug("点击设置")
    }

    @objc private func helpBtnClick() {
        AppLog.device.debug("点击帮助")
    }

    @objc private func startBtnClick() {
        AppLog.device.debug("点击开始记录睡眠")
    }

    private func typeRowTapped(tag: Int) {
        AppLog.device.debug("点击列表项: \(tag)")
    }

    @objc private func midBtnTapped(tag: Int) {
        AppLog.device.debug("点击中间卡片按钮: \(tag)")
    }
}

// MARK: - UI 组件工厂方法

extension DeviceDetailsController {
    
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
        
        label.text = "100%"
        label.font = .systemFont(ofSize: 10, weight: .bold)
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
            make.height.equalTo(20)
            make.width.greaterThanOrEqualTo(65)
        }
        
        return container
    }

    /// 创建记录睡眠卡片中间按钮
    private func makeMidButton(title: String, image: UIImage, tag: Int) -> UIView {
        let container = UIView()
        container.backgroundColor = AppColor.Device.cardBackground.withAlphaComponent(0.6)
        container.layer.cornerRadius = 8
        container.clipsToBounds = true
        
        let btn = UIButton(type: .custom)
        btn.tag = tag
        btn.addTarget(self, action: #selector(midBtnTapped(tag:)), for: .touchUpInside)
        
        let iconView = UIImageView(image: image)
        iconView.contentMode = .scaleAspectFit
        
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = AppColor.Device.buttonTextLightBlue
        
        container.addSubview(iconView)
        container.addSubview(label)
        container.addSubview(btn)
        
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(36)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
        
        label.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-10)
        }
        
        btn.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        return container
    }

    /// 创建行尾箭头图标
    private func makeArrowIcon() -> UIImageView {
        // 修复了这里可能引发编译报错的 Optional 语法（去掉了 ?. ）
        let iv = UIImageView(image: AppImage.Device.iconArrowNext?.withRenderingMode(.alwaysTemplate))
        iv.tintColor = AppColor.Device.arrowGray
        iv.contentMode = .scaleAspectFit
        iv.snp.makeConstraints { make in
            make.width.equalTo(7)
            make.height.equalTo(13)
        }
        return iv
    }

    /// 创建设置列表行
    private func makeSettingsRow(
        icon: UIImage,
        title: String,
        rightView: UIView,
        isHidden: Bool = false,
        showInfoIcon: Bool = false,
        action: (() -> Void)? = nil
    ) -> UIView {
        let container = UIView()
        container.backgroundColor = AppColor.Device.cardBackground
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
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .white
        container.addSubview(label)
        
        // 帮助信息图标（可选）
        if showInfoIcon {
            let info = UIImageView(image: AppImage.Device.iconInfo)
            info.contentMode = .scaleAspectFit
            container.addSubview(info)
            
            info.snp.makeConstraints { make in
                make.leading.equalTo(label.snp.trailing).offset(10)
                make.centerY.equalTo(label)
                make.width.height.equalTo(16)
            }
        }
        
        // 右侧视图
        container.addSubview(rightView)
        
        // 布局
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(25)
        }
        
        label.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(16)
            make.centerY.equalToSuperview()
        }
        
        // 右侧约束
        rightView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
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

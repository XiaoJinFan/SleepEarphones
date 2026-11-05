//
//  DeviceSettingsViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/30.
//

import UIKit
import SnapKit
import Combine

// MARK: - UserDefaults Keys（集中管理）

/// 全局 `UserDefaults` key 常量
enum AppUserDefaultsKeys {

    /// 敲击功能开关
    static let deviceTouchFunctionEnabled = "device_touch_function_enabled"

    /// 所有提示音开关
    static let deviceAllTonesEnabled = "device_all_tones_enabled"
}

/// 耳机设置页面
@MainActor
final class DeviceSettingsViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        static let horizontalInset: CGFloat = AppSpacing.md
        static let cardCornerRadius: CGFloat = AppSpacing.Corner.card
        static let rowHeight: CGFloat = 56
        static let sectionSpacing: CGFloat = AppSpacing.md
        static let contentTopInset: CGFloat = AppSpacing.md
        static let contentBottomInset: CGFloat = 30
        static let rowHorizontalPadding: CGFloat = AppSpacing.md
        static let rowIconSize: CGFloat = AppSpacing.md
        static let separatorHeight: CGFloat = AppSpacing.Border.hairline
        static let separatorInset: CGFloat = AppSpacing.md
    }

    // MARK: - Properties

    /// 当前设备模型（外部传入）
    private let device: DeviceModel

    private var cancellables = Set<AnyCancellable>()

    /// 敲击功能开关状态（从 UserDefaults 读取，默认开启）
    @Published private var isTouchFunctionEnabled: Bool = {
        return UserDefaults.standard.object(forKey: AppUserDefaultsKeys.deviceTouchFunctionEnabled) as? Bool ?? true
    }()

    /// 所有提示音开关状态
    @Published private var isAllTonesEnabled: Bool = {
        return UserDefaults.standard.object(forKey: AppUserDefaultsKeys.deviceAllTonesEnabled) as? Bool ?? true
    }()

    /// 用于展示设备名称的 Label（提出来以便动态更新）
    private lazy var deviceNameValueLabel: UILabel = {
        let label = UILabel()
        label.font = AppFont.Body.regular
        label.textColor = AppColor.Text.primary
        label.textAlignment = .right
        label.text = device.name
        return label
    }()

    // MARK: - UI

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        return sv
    }()

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
        self.title = L("设置")

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: AppColor.Text.primary]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = AppColor.Text.primary
    }

    private func setupUI() {
        view.backgroundColor = AppColor.Background.secondary

        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
    }

    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentStackView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
                .inset(UIEdgeInsets(
                    top: Layout.contentTopInset,
                    left: Layout.horizontalInset,
                    bottom: Layout.contentBottomInset,
                    right: Layout.horizontalInset
                ))
            make.width.equalTo(scrollView.frameLayoutGuide)
                .offset(-Layout.horizontalInset * 2)
        }
    }

    // MARK: - Build Content

    private func buildContent() {
        // 卡片 1：查找设备
        let card1 = makeSectionCard(rows: [
            makeRow(
                title: L("查找设备"),
                showArrow: true,
                action: { [weak self] in
                    let vc = FindDeviceViewController()
                    self?.navigationController?.pushViewController(vc, animated: true)
                }
            )
        ])

        // 卡片 2：提示音
        let card2 = makeSectionCard(rows: [
            makeRow(
                title: L("提示音"),
                showArrow: true,
                action: { [weak self] in
                    let toneVC = ToneSettingsViewController()
                    self?.navigationController?.pushViewController(toneVC, animated: true)
                }
            )
        ])

        // 卡片 3：敲击功能 / 所有提示音
        let touchSwitch = createSwitch(isOn: isTouchFunctionEnabled)
        touchSwitch.addTarget(self, action: #selector(touchSwitchChanged(_:)), for: .valueChanged)

        let toneSwitch = createSwitch(isOn: isAllTonesEnabled)
        toneSwitch.addTarget(self, action: #selector(allTonesSwitchChanged(_:)), for: .valueChanged)

        let card3 = makeSectionCard(rows: [
            makeSwitchRow(title: L("敲击功能"), switchView: touchSwitch),
            makeSwitchRow(title: L("所有提示音"), switchView: toneSwitch)
        ])

        // 卡片 4：设备信息
        let deviceNameRow = makeRowWithCustomRightView(
            title: L("设备名称"),
            rightView: deviceNameValueLabel,
            action: { [weak self] in
                self?.showEditDeviceNameAlert()
            }
        )

        // 固件版本：当前硬编码 "1.00"——应从后端 `firmwareDetails` 接口拉取
        let firmwareVersion = L("未知")

        let card4 = makeSectionCard(rows: [
            deviceNameRow,
            makeRow(
                title: L("升级固件"),
                rightText: firmwareVersion,
                showArrow: true,
                action: {
                    // TODO: 跳转固件升级页
                    AppLog.device.debug("点击升级固件（待实现）")
                }
            ),
            makeRow(
                title: L("序列号"),
                rightText: device.serialNumber,
                showArrow: false,
                rightIcon: UIImage(systemName: "square.on.square"),
                action: { [weak self] in
                    self?.copySerialNumber()
                }
            )
        ])

        // 卡片 5：故障上报
        let card5 = makeSectionCard(rows: [
            makeRow(
                title: L("故障上报"),
                showArrow: true,
                action: {
                    // TODO: 跳转故障上报页（`APIEndpoint.faultType` / `faultSubmit`）
                    AppLog.device.debug("点击故障上报（待实现）")
                }
            )
        ])

        [card1, card2, card3, card4, card5].forEach {
            contentStackView.addArrangedSubview($0)
        }
    }

    // MARK: - Bindings

    private func setupBindings() {
        // 监听状态变化并持久化到本地
        $isTouchFunctionEnabled
            .dropFirst()
            .sink { isOn in
                UserDefaults.standard.set(isOn, forKey: AppUserDefaultsKeys.deviceTouchFunctionEnabled)
                AppLog.device.debug("保存敲击功能状态: \(isOn)")
                // TODO: 下发 BLE 指令 `deviceControl.controllTouchAction(isClose:)`
            }
            .store(in: &cancellables)

        $isAllTonesEnabled
            .dropFirst()
            .sink { isOn in
                UserDefaults.standard.set(isOn, forKey: AppUserDefaultsKeys.deviceAllTonesEnabled)
                AppLog.device.debug("保存所有提示音状态: \(isOn)")
                // TODO: 下发 BLE 指令
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func touchSwitchChanged(_ sender: UISwitch) {
        isTouchFunctionEnabled = sender.isOn
    }

    @objc private func allTonesSwitchChanged(_ sender: UISwitch) {
        isAllTonesEnabled = sender.isOn
    }

    /// 复制序列号到剪贴板
    private func copySerialNumber() {
        guard !device.serialNumber.isEmpty else {
            AppLog.device.debug("序列号为空，跳过复制")
            return
        }

        UIPasteboard.general.string = device.serialNumber
        showToast(L("序列号已复制"))
        AppLog.device.debug("已复制序列号: \(self.device.serialNumber, privacy: .private)")
    }

    /// 点击修改设备名称
    private func showEditDeviceNameAlert() {
        let alert = InputAlertView(
            title: L("请输入"),
            placeholder: L("请输入名称"),
            currentText: deviceNameValueLabel.text
        )

        alert.onConfirm = { [weak self] newName in
            guard let self = self else { return }

            // 1. 更新本地 UI
            self.deviceNameValueLabel.text = newName

            // 2. 提示成功
            self.showToast(L("修改成功"))
            AppLog.device.debug("设备名称已修改为: \(newName, privacy: .private)")

            // TODO: 3. 调用接口或下发 BLE 指令修改设备名称
            //         - 云侧：`APIEndpoint.editInformation`
            //         - BLE：`deviceControl.changeEarbudsPairName(name:)`
        }

        alert.show()
    }
}

// MARK: - UI Factory Methods

extension DeviceSettingsViewController {

    /// 创建 `UISwitch`
    private func createSwitch(isOn: Bool) -> UISwitch {
        let sw = UISwitch()
        sw.isOn = isOn
        sw.onTintColor = AppColor.Brand.primary
        return sw
    }

    /// 生成带 `UISwitch` 的单行视图
    private func makeSwitchRow(title: String, switchView: UISwitch) -> UIView {
        let container = UIView()

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppFont.Body.regular
        titleLabel.textColor = AppColor.Text.primary
        container.addSubview(titleLabel)

        container.addSubview(switchView)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.rowHorizontalPadding)
            make.centerY.equalToSuperview()
        }

        switchView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Layout.rowHorizontalPadding)
            make.centerY.equalToSuperview()
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(Layout.rowHeight)
        }

        return container
    }

    /// 生成单行视图（右侧为文字 + 可选图标 / 箭头）
    ///
    /// - Parameters:
    ///   - title: 左侧标题（**调用方需传入已本地化字符串**）
    ///   - rightText: 右侧文字（如版本号 / 序列号）
    ///   - showArrow: 是否显示右箭头
    ///   - rightIcon: 右侧图标（如"复制"图标）
    ///   - action: 整行点击回调
    /// - Returns: 单行视图
    private func makeRow(title: String, rightText: String? = nil, showArrow: Bool = false, rightIcon: UIImage? = nil, action: (() -> Void)? = nil) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppFont.Body.regular
        titleLabel.textColor = AppColor.Text.primary
        container.addSubview(titleLabel)

        let rightStack = UIStackView()
        rightStack.axis = .horizontal
        rightStack.spacing = AppSpacing.xs
        rightStack.alignment = .center
        container.addSubview(rightStack)

        if let rightText = rightText, !rightText.isEmpty {
            let valueLabel = UILabel()
            valueLabel.text = rightText
            valueLabel.font = AppFont.Body.regular
            valueLabel.textColor = AppColor.Text.primary
            valueLabel.textAlignment = .right
            valueLabel.numberOfLines = 1
            valueLabel.lineBreakMode = .byTruncatingMiddle
            rightStack.addArrangedSubview(valueLabel)
        }

        if let rightIcon = rightIcon {
            let iconView = UIImageView(image: rightIcon)
            iconView.tintColor = AppColor.Brand.primary
            iconView.contentMode = .scaleAspectFit
            rightStack.addArrangedSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.width.height.equalTo(Layout.rowIconSize)
            }
        }

        if showArrow {
            let arrowView = UIImageView(image: UIImage(systemName: "chevron.right"))
            arrowView.tintColor = AppColor.Text.tertiary
            arrowView.contentMode = .scaleAspectFit
            rightStack.addArrangedSubview(arrowView)
            arrowView.snp.makeConstraints { make in
                make.width.height.equalTo(14)
            }
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.rowHorizontalPadding)
            make.centerY.equalToSuperview()
        }

        rightStack.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Layout.rowHorizontalPadding)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(AppSpacing.md)
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(Layout.rowHeight)
        }

        if let action = action {
            let btn = UIButton(type: .custom)
            btn.addAction(UIAction { _ in action() }, for: .touchUpInside)
            container.addSubview(btn)
            btn.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            container.sendSubviewToBack(btn)
        }

        return container
    }

    /// 生成单行视图（右侧为**自定义视图**，如 `deviceNameValueLabel`）
    ///
    /// - Parameters:
    ///   - title: 左侧标题
    ///   - rightView: 右侧自定义视图
    ///   - action: 整行点击回调
    /// - Returns: 单行视图
    private func makeRowWithCustomRightView(title: String, rightView: UIView, action: (() -> Void)? = nil) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppFont.Body.regular
        titleLabel.textColor = AppColor.Text.primary
        container.addSubview(titleLabel)

        container.addSubview(rightView)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.rowHorizontalPadding)
            make.centerY.equalToSuperview()
        }

        rightView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Layout.rowHorizontalPadding)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(AppSpacing.md)
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(Layout.rowHeight)
        }

        if let action = action {
            let btn = UIButton(type: .custom)
            btn.addAction(UIAction { _ in action() }, for: .touchUpInside)
            container.addSubview(btn)
            btn.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            container.sendSubviewToBack(btn)
        }

        return container
    }

    /// 生成白色圆角卡片
    ///
    /// - Parameter rows: 行视图数组
    /// - Returns: 圆角卡片
    private func makeSectionCard(rows: [UIView]) -> UIView {
        let card = UIView()
        card.backgroundColor = AppColor.Background.card
        card.layer.cornerRadius = Layout.cardCornerRadius
        card.clipsToBounds = true

        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.spacing = 0
        stack.distribution = .fill
        card.addSubview(stack)

        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 行间分隔线
        for (index, row) in rows.enumerated() where index > 0 {
            let line = UIView()
            line.backgroundColor = AppColor.separator
            card.addSubview(line)

            line.snp.makeConstraints { make in
                make.top.equalTo(row.snp.top)
                make.leading.equalToSuperview().offset(Layout.separatorInset)
                make.trailing.equalToSuperview().offset(-Layout.separatorInset)
                make.height.equalTo(Layout.separatorHeight)
            }
        }

        return card
    }
}

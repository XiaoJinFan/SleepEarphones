//
//  DeviceSettingsViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/30.
//

import UIKit
import SnapKit
import Combine

/// 耳机设置页面
@MainActor
final class DeviceSettingsViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let cardCornerRadius: CGFloat = 16
        static let rowHeight: CGFloat = 56
        static let sectionSpacing: CGFloat = 16
    }
    
    // MARK: - Properties

    /// 当前设备模型（外部传入）
    private let device: DeviceModel
    
    private var cancellables = Set<AnyCancellable>()
    
    /// 敲击功能开关状态（从 UserDefaults 读取，默认开启）
    @Published private var isTouchFunctionEnabled: Bool = {
        return UserDefaults.standard.object(forKey: "device_touch_function_enabled") as? Bool ?? true
    }()
    
    /// 所有提示音开关状态
    @Published private var isAllTonesEnabled: Bool = {
        return UserDefaults.standard.object(forKey: "device_all_tones_enabled") as? Bool ?? true
    }()
    
    /// 用于展示设备名称的 Label（提出来以便动态更新）
    private lazy var deviceNameValueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
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
        self.title = "设置"
        
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
            make.edges.equalTo(scrollView.contentLayoutGuide).inset(UIEdgeInsets(top: 16, left: Layout.horizontalInset, bottom: 30, right: Layout.horizontalInset))
            make.width.equalTo(scrollView.frameLayoutGuide).offset(-Layout.horizontalInset * 2)
        }
    }

    // MARK: - Build Content

    private func buildContent() {
        // 卡片 1
        let card1 = makeSectionCard(rows: [
            makeRow(title: "查找设备", showArrow: true, action: { [weak self] in
                let vc = FindDeviceViewController()
                self?.navigationController?.pushViewController(vc, animated: true)
            })
        ])
        
        // 卡片 2
        let card2 = makeSectionCard(rows: [
            makeRow(title: "提示音", showArrow: true, action: { [weak self] in
                let toneVC = ToneSettingsViewController()
                self?.navigationController?.pushViewController(toneVC, animated: true)
            })
        ])
        
        // 卡片 3（带开关，完全还原设计图）
        let touchSwitch = createSwitch(isOn: isTouchFunctionEnabled)
        touchSwitch.addTarget(self, action: #selector(touchSwitchChanged(_:)), for: .valueChanged)
        
        let toneSwitch = createSwitch(isOn: isAllTonesEnabled)
        toneSwitch.addTarget(self, action: #selector(allTonesSwitchChanged(_:)), for: .valueChanged)
        
        let card3 = makeSectionCard(rows: [
            makeSwitchRow(title: "敲击功能", switchView: touchSwitch),
            makeSwitchRow(title: "所有提示音", switchView: toneSwitch)
        ])
        
        let deviceNameRow = makeRow(
            title: "设备名称",
            rightText: nil, // 不用默认的 rightText
            showArrow: false,
            action: { [weak self] in
                self?.showEditDeviceNameAlert()
            }
        )
        // 把自定义的 Label 塞到 makeRow 里
        if let rightStack = deviceNameRow.subviews.compactMap({ $0 as? UIStackView }).first {
            rightStack.addArrangedSubview(deviceNameValueLabel)
        }
        
        // 卡片 4
        let card4 = makeSectionCard(rows: [
            deviceNameRow,
            makeRow(title: "升级固件", rightText: "1.00", showArrow: true, action: {
                print("跳转升级固件")
            }),
            makeRow(title: "序列号", rightText: device.serialNumber, showArrow: false, rightIcon: UIImage(systemName: "square.on.square"), action: { [weak self] in
                self?.copySerialNumber()
            })
        ])
        
        // 卡片 5
        let card5 = makeSectionCard(rows: [
            makeRow(title: "故障上报", showArrow: true, action: {
                print("跳转故障上报")
            })
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
                UserDefaults.standard.set(isOn, forKey: "device_touch_function_enabled")
                AppLog.device.debug("保存敲击功能状态: \(isOn)")
                // TODO: 下发 BLE 指令
            }
            .store(in: &cancellables)
            
        $isAllTonesEnabled
            .dropFirst()
            .sink { isOn in
                UserDefaults.standard.set(isOn, forKey: "device_all_tones_enabled")
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
    
    private func copySerialNumber() {
        UIPasteboard.general.string = device.serialNumber
        showToast("序列号已复制")
        AppLog.device.debug("已复制序列号: \(self.device.serialNumber)")
    }
    
    /// 点击修改设备名称
    private func showEditDeviceNameAlert() {
        let alert = InputAlertView(
            title: "请输入",
            placeholder: "请输入名称",
            currentText: deviceNameValueLabel.text
        )
        
        alert.onConfirm = { [weak self] newName in
            guard let self = self else { return }
            
            // 1. 更新本地 UI
            self.deviceNameValueLabel.text = newName
            
            // 2. 提示成功
            self.showToast("修改成功")
            AppLog.device.debug("设备名称已修改为: \(newName)")
            
            // TODO: 3. 调用接口或下发 BLE 指令修改设备名称
        }
        
        alert.show()
    }
}

// MARK: - UI Factory Methods

extension DeviceSettingsViewController {
    
    private func createSwitch(isOn: Bool) -> UISwitch {
        let sw = UISwitch()
        sw.isOn = isOn
        sw.onTintColor = AppColor.Brand.primary
        return sw
    }
    
    /// 生成带 Switch 的单行视图
    private func makeSwitchRow(title: String, switchView: UISwitch) -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        titleLabel.textColor = AppColor.Text.primary
        container.addSubview(titleLabel)
        
        container.addSubview(switchView)
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }
        
        switchView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
        
        container.snp.makeConstraints { make in
            make.height.equalTo(Layout.rowHeight)
        }
        
        return container
    }
    
    /// 生成单行视图
    private func makeRow(
        title: String,
        rightText: String? = nil,
        showArrow: Bool = false,
        rightIcon: UIImage? = nil,
        action: (() -> Void)? = nil
    ) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        titleLabel.textColor = AppColor.Text.primary
        container.addSubview(titleLabel)
        
        let rightStack = UIStackView()
        rightStack.axis = .horizontal
        rightStack.spacing = 8
        rightStack.alignment = .center
        container.addSubview(rightStack)
        
        if let rightText = rightText {
            let valueLabel = UILabel()
            valueLabel.text = rightText
            valueLabel.font = .systemFont(ofSize: 16, weight: .regular)
            valueLabel.textColor = AppColor.Text.primary
            valueLabel.textAlignment = .right
            rightStack.addArrangedSubview(valueLabel)
        }
        
        if let rightIcon = rightIcon {
            let iconView = UIImageView(image: rightIcon)
            iconView.tintColor = AppColor.Brand.primary
            iconView.contentMode = .scaleAspectFit
            rightStack.addArrangedSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.width.height.equalTo(16)
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
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }
        
        rightStack.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(16)
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
        
        for (index, row) in rows.enumerated() where index > 0 {
            let line = UIView()
            line.backgroundColor = AppColor.separator
            card.addSubview(line)
            
            line.snp.makeConstraints { make in
                make.top.equalTo(row.snp.top)
                make.leading.equalToSuperview().offset(16)
                make.trailing.equalToSuperview().offset(-16)
                make.height.equalTo(0.5)
            }
        }
        
        return card
    }
}

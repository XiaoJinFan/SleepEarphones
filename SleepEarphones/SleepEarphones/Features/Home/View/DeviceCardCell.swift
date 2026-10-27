//
//  DeviceCardCell.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/22.
//

import UIKit
import SnapKit

@MainActor
final class DeviceCardCell: UICollectionViewCell {

    // MARK: - Constants

    static let reuseID = "DeviceCardCell"

    // MARK: - Layout 常量

    private enum Layout {
        /// 卡片外边距
        static let cardMargin: CGFloat = 16
        /// 卡片内部 Padding
        static let cardPadding: CGFloat = 16

        /// 设备图片尺寸
        static let imageSize: CGFloat = 80
        /// 图片与右侧信息栈的间距
        static let imageToInfoSpacing: CGFloat = 16

        /// 状态点尺寸
        static let dotSize: CGFloat = 8
        /// 状态点与文字的间距
        static let dotToTextSpacing: CGFloat = 6

        /// 名称行与电量行的间距
        static let titleToBatterySpacing: CGFloat = 12
        /// 电量行与报告按钮的间距
        static let batteryToReportSpacing: CGFloat = 16

        /// 电量行高度
        static let batteryHeight: CGFloat = 28
    }

    // MARK: - UI 组件

    /// 白色卡片容器
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = AppColor.Background.card
        view.layer.cornerRadius = AppSpacing.Corner.card
        view.clipsToBounds = true
        return view
    }()

    /// 设备图片
    private let deviceImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        // TODO: 替换为真实的设备默认图资源
        iv.image = UIImage(systemName: "airpodspro")
        iv.tintColor = AppColor.Text.primary
        return iv
    }()

    /// 设备名称
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = AppFont.Title.card
        label.textColor = AppColor.Text.primary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        // 名称可被压缩（让状态行优先完整显示）
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    /// 状态点
    private let statusDot: UIView = {
        let view = UIView()
        view.layer.cornerRadius = Layout.dotSize / 2
        return view
    }()

    /// 状态文字
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = AppFont.Body.secondary
        return label
    }()

    /// 状态行（点 + 文字）
    private lazy var statusStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [statusDot, statusLabel])
        s.axis = .horizontal
        s.spacing = Layout.dotToTextSpacing
        s.alignment = .center
        // 状态行必须完整展示，不被名称挤压
        s.setContentHuggingPriority(.required, for: .horizontal)
        s.setContentCompressionResistancePriority(.required, for: .horizontal)
        return s
    }()

    /// 名称 + 状态行组合
    private lazy var titleRowStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [nameLabel, statusStack])
        s.axis = .horizontal
        s.spacing = AppSpacing.sm
        s.alignment = .center
        s.distribution = .fill
        return s
    }()

    /// 电量胶囊容器（L / R / C）
    private let batteryStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        return stack
    }()

    private let leftBatteryView  = BatteryCapsuleView(title: "L")
    private let rightBatteryView = BatteryCapsuleView(title: "R")
    private let boxBatteryView   = BatteryCapsuleView(title: "C")

    /// 查看睡眠报告按钮
    ///
    /// - Note: 通过 `isHidden` 控制显隐——垂直 StackView 会自动塌陷空间，
    ///         无需 `remakeConstraints`。
    private let reportButton: UIButton = {
        var config = UIButton.Configuration.plain()

        var titleAttr = AttributedString("查看睡眠报告")
        titleAttr.font = AppFont.Body.secondary
        titleAttr.foregroundColor = AppColor.Text.secondary
        config.attributedTitle = titleAttr

        config.image = UIImage(systemName: "chevron.right")
        config.imagePlacement = .trailing
        config.imagePadding = 10
        config.baseForegroundColor = AppColor.Text.tertiary

        config.background.backgroundColor = AppColor.Background.secondary
        config.background.cornerRadius = AppSpacing.Corner.medium

        // 内容内边距——让按钮天然拥有约 40pt 的高度
        // （字体 ~15pt + 上下各 12pt ≈ 39pt）
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 12,
            leading: AppSpacing.md,
            bottom: 12,
            trailing: AppSpacing.md
        )

        return UIButton(configuration: config)
    }()

    /// 右侧内容栈：名称行 + 电量行 + 报告按钮（垂直）
    ///
    /// - `reportButton.isHidden` 时，StackView 自动塌陷
    /// - `setCustomSpacing` 精确控制行间距
    private lazy var contentStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [
            titleRowStack,
            batteryStackView,
            reportButton
        ])
        s.axis = .vertical
        s.alignment = .fill
        s.distribution = .fill

        // 行间距（利用 setCustomSpacing 差异化）
        s.setCustomSpacing(Layout.titleToBatterySpacing, after: titleRowStack)
        s.setCustomSpacing(Layout.batteryToReportSpacing, after: batteryStackView)

        return s
    }()

    /// 外层水平栈：图片 + 右侧内容
    ///
    /// - `alignment = .top`：图片和内容都从顶部对齐
    /// - 高度由两侧较高者撑开——图片 80pt 固定，或内容栈按需
    private lazy var horizontalStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [deviceImageView, contentStack])
        s.axis = .horizontal
        s.spacing = Layout.imageToInfoSpacing
        s.alignment = .top
        s.distribution = .fill
        return s
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        // 清除状态色，避免复用时残留上一台设备的状态
        statusDot.backgroundColor = nil
        statusLabel.text = nil
        statusLabel.textColor = nil
        nameLabel.text = nil
    }

    // MARK: - Setup

    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.addSubview(horizontalStack)

        batteryStackView.addArrangedSubview(leftBatteryView)
        batteryStackView.addArrangedSubview(rightBatteryView)
        batteryStackView.addArrangedSubview(boxBatteryView)
    }

    private func setupConstraints() {
        // 卡片容器：铺满 cell，上下留 8pt、左右留 16pt
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(
                top: AppSpacing.xs,
                left: Layout.cardMargin,
                bottom: AppSpacing.xs,
                right: Layout.cardMargin
            ))
        }

        // 外层水平栈：卡片内边距 16pt
        horizontalStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Layout.cardPadding)
        }

        // 设备图片：固定尺寸
        deviceImageView.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.imageSize)
        }

        // 状态点：固定尺寸
        statusDot.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.dotSize)
        }

        // 电量行：固定高度
        batteryStackView.snp.makeConstraints { make in
            make.height.equalTo(Layout.batteryHeight)
        }
    }

    // MARK: - Configure

    /// 配置设备数据
    ///
    /// - Parameter data: 视图数据
    func configure(with data: DeviceViewData) {
        nameLabel.text = data.name

        // 状态样式
        let themeColor = data.isConnected ? AppColor.Semantic.success : AppColor.Text.tertiary
        statusDot.backgroundColor = themeColor
        statusLabel.text = data.isConnected ? "已连接" : "未连接"
        statusLabel.textColor = themeColor

        // 电量胶囊（传入具体的充电状态与电量）
        leftBatteryView.update(
            battery: data.leftBattery,
            chargingState: data.leftCharging,
            isConnected: data.isConnected
        )
        rightBatteryView.update(
            battery: data.rightBattery,
            chargingState: data.rightCharging,
            isConnected: data.isConnected
        )
        boxBatteryView.update(
            battery: data.boxBattery,
            chargingState: data.boxCharging,
            isConnected: data.isConnected
        )
        
        reportButton.isHidden = !data.isConnected
    }
}

// MARK: - 胶囊电量 View

@MainActor
final class BatteryCapsuleView: UIView {

    // MARK: - Private UI

    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()

    /// 最近一次应用的"语义颜色"（用于 trait 变化时重算 borderColor）
    ///
    /// - Note: 不直接缓存 CGColor——需要 UIColor 才能响应 trait 变化。
    private var lastAppliedColor: UIColor?

    // MARK: - Init

    init(title: String) {
        super.init(frame: .zero)
        setupUI(title: title)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI(title: String) {
        self.layer.cornerRadius = 14
        self.layer.borderWidth = 1
        self.layer.masksToBounds = true

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.image = UIImage(systemName: "battery.100")

        titleLabel.font = AppFont.Caption.tiny
        titleLabel.textAlignment = .center

        addSubview(iconImageView)
        addSubview(titleLabel)

        iconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(4)
            make.right.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
        }
    }

    // MARK: - Trait

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // 深/浅色模式切换时，`CGColor` 不会自动跟随 → 需重新解析
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection),
              let color = lastAppliedColor else { return }
        applyBorderColor(color)
    }

    // MARK: - Update

    /// 更新电量与充电状态
    ///
    /// - Parameters:
    ///   - battery: 电量（-1 = 未上报）
    ///   - chargingState: 充电状态
    ///   - isConnected: 是否已连接（决定基础色）
    func update(battery: Int, chargingState: BatteryChargingState, isConnected: Bool) {
        // 如果设备未上报电量 (-1)，显示 "--"
        titleLabel.text = battery < 0 ? "--" : "\(battery)%"

        let color = isConnected ? AppColor.Semantic.success : AppColor.Text.tertiary
        self.lastAppliedColor = color

        titleLabel.textColor = color
        iconImageView.tintColor = color
        applyBorderColor(color)

        // 充电状态图标变换
        if chargingState == .charging {
            iconImageView.image = UIImage(systemName: "battery.100.bolt")
        } else {
            iconImageView.image = UIImage(systemName: "battery.100")
        }
    }

    // MARK: - Private

    /// 应用边框色（`CGColor` 是静态快照，需要显式解析）
    private func applyBorderColor(_ color: UIColor) {
        layer.borderColor = color
            .resolvedColor(with: traitCollection)
            .withAlphaComponent(0.5)
            .cgColor
    }
}

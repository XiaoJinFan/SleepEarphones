//
//  HomeDeviceCardCell.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/27.
//

import UIKit
import SnapKit

// MARK: - 设备卡片 Cell

/// 首页设备卡片
///
/// ## 布局结构
/// ```
/// ┌──────────────────────────────────────────────────┐
/// │ ┌────────┐  ┌──────────────────────────────────┐ │
/// │ │        │  │ 设备名称           ● 已连接        │ │  ← titleRowStack
/// │ │ 设备图 │  ├──────────────────────────────────┤ │
/// │ │        │  │ [左耳] [右耳] [充电盒]              │ │  ← batteryStackView
/// │ │        │  ├──────────────────────────────────┤ │
/// │ │        │  │ 查看睡眠报告                      > │ │  ← reportButton（有报告时显示）
/// │ └────────┘  └──────────────────────────────────┘ │
/// └──────────────────────────────────────────────────┘
/// ```
///
/// ## 三态连接判断
/// | 状态 | BLE 匹配（`isPaired`） | 音频路由（`isConnected`） | 展示文案 | 状态点颜色 |
/// |---|---|---|---|---|
/// | 已连接 | ✅ | ✅ | `"已连接"` | `Semantic.success` |
/// | 已配对 | ✅ | ❌ | `"已配对"` | `Semantic.warning` |
/// | 未连接 | ❌ | ❌ | `"未连接"` | `Text.tertiary` |
@MainActor
final class HomeDeviceCardCell: UICollectionViewCell {

    // MARK: - Constants

    static let reuseID = "HomeDeviceCardCell"

    // MARK: - Layout

    private enum Layout {
        static let cardMargin: CGFloat = AppSpacing.md
        static let cardPadding: CGFloat = AppSpacing.md
        static let imageSize: CGFloat = 100
        static let imageToInfoSpacing: CGFloat = AppSpacing.md
        static let dotSize: CGFloat = 8
        static let dotToTextSpacing: CGFloat = 6
        static let batteryHeight: CGFloat = 28
        static let batterySpacing: CGFloat = 8
        static let reportHeight: CGFloat = 44
    }

    // MARK: - Callback

    /// 点击"查看睡眠报告"回调
    var onReportTapped: (() -> Void)?

    // MARK: - UI

    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = AppColor.Background.card
        v.layer.cornerRadius = AppSpacing.Corner.card
        v.clipsToBounds = true
        return v
    }()

    private let deviceImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = AppImage.Local.devicePlaceholder
        return iv
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Title.card
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return l
    }()

    private let statusDot: UIView = {
        let v = UIView()
        v.layer.cornerRadius = Layout.dotSize / 2
        return v
    }()

    private let statusLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Caption.emphasized
        return l
    }()

    private lazy var statusStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [statusDot, statusLabel])
        s.axis = .horizontal
        s.spacing = Layout.dotToTextSpacing
        s.alignment = .center
        s.setContentHuggingPriority(.required, for: .horizontal)
        s.setContentCompressionResistancePriority(.required, for: .horizontal)
        return s
    }()

    private lazy var titleRowStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [nameLabel, statusStack])
        s.axis = .horizontal
        s.spacing = AppSpacing.sm
        s.alignment = .center
        s.distribution = .fill
        return s
    }()

    private let batteryStackView: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = Layout.batterySpacing
        s.distribution = .fillEqually
        return s
    }()

    private let leftBatteryView  = HomeBatteryCapsuleView(type: .left)
    private let rightBatteryView = HomeBatteryCapsuleView(type: .right)
    private let boxBatteryView   = HomeBatteryCapsuleView(type: .box)

    /// "查看睡眠报告"按钮
    private let reportButton: UIButton = {
        var config = UIButton.Configuration.plain()

        var titleAttr = AttributedString(L("查看睡眠报告"))
        titleAttr.font = AppFont.Body.secondary
        titleAttr.foregroundColor = AppColor.Text.secondary
        config.attributedTitle = titleAttr
        
        config.baseForegroundColor = AppColor.Text.tertiary
        config.background.backgroundColor = AppColor.Background.secondary
        config.background.cornerRadius = AppSpacing.Corner.medium
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: AppSpacing.md,
            bottom: 0,
            trailing: AppSpacing.md
        )

        let b = UIButton(configuration: config)
        b.contentHorizontalAlignment = .leading

        // 右侧箭头单独作为子视图，约束到 trailing
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = AppColor.Text.tertiary
        chevron.contentMode = .scaleAspectFit
        chevron.isUserInteractionEnabled = false
        chevron.translatesAutoresizingMaskIntoConstraints = false
        b.addSubview(chevron)

        NSLayoutConstraint.activate([
            chevron.trailingAnchor.constraint(equalTo: b.trailingAnchor,
                                              constant: -AppSpacing.md),
            chevron.centerYAnchor.constraint(equalTo: b.centerYAnchor)
        ])

        // 默认隐藏——`configure` 会按 `isPaired && hasSleepReport` 决定显隐
        b.isHidden = true

        return b
    }()

    private lazy var infoStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [titleRowStack, batteryStackView, reportButton])
        s.axis = .vertical
        s.alignment = .fill
        s.distribution = .fill
        s.spacing = AppSpacing.sm
        s.setCustomSpacing(AppSpacing.md, after: batteryStackView)
        return s
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        deviceImageView.cancelRemoteImageLoad()
        deviceImageView.image = AppImage.Local.devicePlaceholder
        nameLabel.text = nil

        // 显式重置为中性色，避免复用时残留上一帧的绿色 / 橙色
        statusLabel.text = nil
        statusLabel.textColor = AppColor.Text.tertiary
        statusDot.backgroundColor = AppColor.Text.tertiary

        // 重置报告按钮显隐——`configure` 会立即按新数据修正
        reportButton.isHidden = true
        // 同步重置 custom spacing——防止上一帧 `reportButton.isHidden == false`
        // 残留的 16pt 间距在下一帧"隐藏"时造成底部空洞
        infoStack.setCustomSpacing(AppSpacing.sm, after: batteryStackView)

        onReportTapped = nil
    }

    // MARK: - Setup

    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.addSubview(deviceImageView)
        containerView.addSubview(infoStack)

        batteryStackView.addArrangedSubview(leftBatteryView)
        batteryStackView.addArrangedSubview(rightBatteryView)
        batteryStackView.addArrangedSubview(boxBatteryView)

        reportButton.addTarget(self, action: #selector(reportTapped), for: .touchUpInside)
    }

    private func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(
                top: AppSpacing.xs, left: Layout.cardMargin,
                bottom: AppSpacing.xs, right: Layout.cardMargin
            ))
        }

        deviceImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(Layout.cardPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.imageSize)
            make.top.greaterThanOrEqualToSuperview().offset(Layout.cardPadding)
            make.bottom.lessThanOrEqualToSuperview().offset(-Layout.cardPadding)
        }

        infoStack.snp.makeConstraints { make in
            make.left.equalTo(deviceImageView.snp.right).offset(Layout.imageToInfoSpacing)
            make.right.equalToSuperview().offset(-Layout.cardPadding)
            make.centerY.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview().offset(Layout.cardPadding)
            make.bottom.lessThanOrEqualToSuperview().offset(-Layout.cardPadding)
        }

        statusDot.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.dotSize)
        }

        batteryStackView.snp.makeConstraints { make in
            make.height.equalTo(Layout.batteryHeight)
        }

        reportButton.snp.makeConstraints { make in
            make.height.equalTo(Layout.reportHeight)
        }
    }

    // MARK: - Configure

    /// 配置单元格
    ///
    /// - Parameters:
    ///   - device: 服务器返回的历史设备
    ///   - isConnected: 是否完全就绪（BLE 已连接 **且** 音频已路由）——
    ///                  仅用于**状态点颜色**的"已连接"判定
    ///   - isPaired: BLE 是否已连接（音频可能未路由）——
    ///               用于**电池颜色**与**报告按钮显隐**
    ///
    /// ## 三态判断
    /// - `isConnected == true`：**已连接**（绿色）
    /// - `isConnected == false && isPaired == true`：**已配对**（橙色）
    /// - 其他：**未连接**（灰色）
    func configure(with device: DeviceModel, isConnected: Bool, isPaired: Bool) {
        nameLabel.text = device.name

        // MARK: 三态状态显示（文案已本地化）
        let themeColor: UIColor
        let statusText: String

        if isConnected {
            // 完全就绪：BLE + 音频都匹配
            themeColor = AppColor.Semantic.success
            statusText = L("已连接")
        } else if isPaired {
            // BLE 已连但音频未切——用橙色区分
            themeColor = AppColor.Semantic.warning
            statusText = L("已配对")
        } else {
            themeColor = AppColor.Text.tertiary
            statusText = L("未连接")
        }

        statusDot.backgroundColor = themeColor
        statusLabel.text = statusText
        statusLabel.textColor = themeColor

        // MARK: 电量解析
        let leftInt = Int(device.leftBattery) ?? -1
        let rightInt = Int(device.rightBattery) ?? -1
        let boxInt = Int(device.batteryLevel) ?? -1

        leftBatteryView.update(battery: leftInt, isConnected: isPaired)
        rightBatteryView.update(battery: rightInt, isConnected: isPaired)
        boxBatteryView.update(battery: boxInt, isConnected: isPaired)

        // MARK: "查看睡眠报告"按钮显隐（关键修复）
        reportButton.isHidden = !(isPaired && device.hasSleepReport)
        
        infoStack.setCustomSpacing(
            reportButton.isHidden ? AppSpacing.sm : AppSpacing.md,
            after: batteryStackView
        )

        deviceImageView.setImage(
            device.imageURL,
            placeholder: AppImage.Local.devicePlaceholder
        )
    }

    // MARK: - Actions

    @objc private func reportTapped() {
        onReportTapped?()
    }
}

// MARK: - 电池胶囊 View

/// 电池胶囊视图（左耳 / 右耳 / 充电盒）
@MainActor
final class HomeBatteryCapsuleView: UIView {

    // MARK: - CapsuleType

    /// 胶囊类型
    enum CapsuleType {
        case left, right, box

        /// SF Symbols 图标名（**不参与国际化**）
        var iconName: String {
            switch self {
            case .left, .right: return "ear"
            case .box:          return "battery.100"
            }
        }
    }

    // MARK: - Constants

    private enum Layout {
        /// 胶囊圆角（28 高的一半）
        static let capsuleCornerRadius: CGFloat = 14
        /// 图标尺寸
        static let iconSize: CGFloat = 14
        /// 图标左边距
        static let iconLeadingInset: CGFloat = AppSpacing.xs
        /// 图标与文字间距
        static let iconToTextSpacing: CGFloat = AppSpacing.xxs
        /// 文字右边距
        static let textTrailingInset: CGFloat = 6
        /// 边框宽度
        static let borderWidth: CGFloat = AppSpacing.Border.standard
        /// 边框透明度（与文字色叠加后降低视觉重量）
        static let borderAlpha: CGFloat = 0.5
    }

    // MARK: - Properties

    private let type: CapsuleType
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()

    /// 上次应用的颜色（用于 trait 切换时重新计算 `CGColor`）
    private var lastAppliedColor: UIColor?

    // MARK: - Init

    init(type: CapsuleType) {
        self.type = type
        super.init(frame: .zero)
        setupUI()
        registerTraitChangeObservation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        layer.cornerRadius = Layout.capsuleCornerRadius
        layer.borderWidth = Layout.borderWidth
        layer.masksToBounds = true

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.image = UIImage(systemName: type.iconName)

        titleLabel.font = AppFont.Caption.tiny
        titleLabel.textAlignment = .center

        addSubview(iconImageView)
        addSubview(titleLabel)

        iconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(Layout.iconLeadingInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.iconSize)
        }

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(Layout.iconToTextSpacing)
            make.right.equalToSuperview().offset(-Layout.textTrailingInset)
            make.centerY.equalToSuperview()
        }
    }

    // MARK: - Trait 变化监听

    /// 注册 trait 变化监听（iOS 17+）
    private func registerTraitChangeObservation() {
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: HomeBatteryCapsuleView, _) in
                view.reapplyBorderColorIfNeeded()
            }
        }
    }

    /// 用 `lastAppliedColor` 重新应用边框色
    private func reapplyBorderColorIfNeeded() {
        guard let color = lastAppliedColor else { return }
        applyBorderColor(color)
    }

    /// 旧版兼容（iOS 17 以下）
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // iOS 17+ 由 registerForTraitChanges 处理，避免重复
        if #available(iOS 17.0, *) { return }

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            reapplyBorderColorIfNeeded()
        }
    }

    // MARK: - Update

    /// 更新电量与连接状态
    ///
    /// - Parameters:
    ///   - battery: 电量（0~100）；`-1` 表示未知（显示 `"--"`）
    ///   - isConnected: 是否已连接（决定文字 / 图标的颜色）
    func update(battery: Int, isConnected: Bool) {
        // 未知电量用 `--`（数字占位，不参与国际化）
        titleLabel.text = battery < 0 ? "--" : "\(battery)%"

        let color = isConnected
            ? AppColor.Semantic.success
            : AppColor.Text.tertiary
        self.lastAppliedColor = color
        titleLabel.textColor = color
        iconImageView.tintColor = color
        applyBorderColor(color)
    }

    /// 应用边框色（带透明度，降低视觉重量）
    ///
    /// - Parameter color: 动态色
    private func applyBorderColor(_ color: UIColor) {
        layer.borderColor = color
            .resolvedColor(with: traitCollection)
            .withAlphaComponent(Layout.borderAlpha)
            .cgColor
    }
}

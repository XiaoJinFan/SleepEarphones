//
//  HomeDeviceCardCell.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/27.
//

import UIKit
import SnapKit

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

    private let reportButton: UIButton = {
        var config = UIButton.Configuration.plain()

        var titleAttr = AttributedString("查看睡眠报告")
        titleAttr.font = AppFont.Body.secondary
        titleAttr.foregroundColor = AppColor.Text.secondary
        config.attributedTitle = titleAttr

        config.image = UIImage(systemName: "chevron.right")
        config.imagePlacement = .trailing
        config.imagePadding = 8
        config.baseForegroundColor = AppColor.Text.tertiary

        config.background.backgroundColor = AppColor.Background.secondary
        config.background.cornerRadius = AppSpacing.Corner.medium

        config.contentInsets = NSDirectionalEdgeInsets(
            top: 0, leading: AppSpacing.md, bottom: 0, trailing: AppSpacing.md
        )

        let b = UIButton(configuration: config)
        b.contentHorizontalAlignment = .leading
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
        statusLabel.text = nil
        statusLabel.textColor = nil
        statusDot.backgroundColor = nil
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
    ///   - isConnected: 是否完全就绪（BLE 已连接 **且** 音频已路由）
    ///   - isPaired: BLE 是否已连接（音频可能未路由）
    ///
    func configure(with device: DeviceModel, isConnected: Bool, isPaired: Bool) {
        nameLabel.text = device.name

        // MARK: 三态状态显示
        let themeColor: UIColor
        let statusText: String

        if isConnected {
            // 完全就绪：BLE + 音频都匹配
            themeColor = AppColor.Semantic.success
            statusText = "已连接"
        } else if isPaired {
            // BLE 已连但音频未切——用橙色区分
            themeColor = AppColor.Semantic.warning
            statusText = "已配对"
        } else {
            themeColor = AppColor.Text.tertiary
            statusText = "未连接"
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

        // MARK: 睡眠报告按钮
        reportButton.isHidden = !(isConnected && device.hasSleepReport)

        deviceImageView.setImage(device.imageURL, placeholder: AppImage.Local.devicePlaceholder)
    }

    // MARK: - Actions

    @objc private func reportTapped() {
        onReportTapped?()
    }
}

// MARK: - 电池胶囊 View

@MainActor
final class HomeBatteryCapsuleView: UIView {

    enum CapsuleType {
        case left, right, box
        var iconName: String {
            switch self {
            case .left, .right: return "ear"
            case .box: return "battery.100"
            }
        }
    }

    private let type: CapsuleType
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private var lastAppliedColor: UIColor?

    init(type: CapsuleType) {
        self.type = type
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        layer.cornerRadius = 14
        layer.borderWidth = 1
        layer.masksToBounds = true

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.image = UIImage(systemName: type.iconName)

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
            make.right.equalToSuperview().offset(-6)
            make.centerY.equalToSuperview()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection),
           let color = lastAppliedColor {
            applyBorderColor(color)
        }
    }

    func update(battery: Int, isConnected: Bool) {
        titleLabel.text = battery < 0 ? "--" : "\(battery)%"

        let color = isConnected ? AppColor.Semantic.success : AppColor.Text.tertiary
        self.lastAppliedColor = color
        titleLabel.textColor = color
        iconImageView.tintColor = color
        applyBorderColor(color)
    }

    private func applyBorderColor(_ color: UIColor) {
        layer.borderColor = color.resolvedColor(with: traitCollection).withAlphaComponent(0.5).cgColor
    }
}

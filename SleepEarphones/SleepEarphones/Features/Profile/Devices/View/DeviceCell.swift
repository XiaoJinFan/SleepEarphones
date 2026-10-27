//
//  DeviceCell.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/11.
//

import UIKit
import SnapKit
import Kingfisher

/// 设备列表单元格
/// 
@MainActor
final class DeviceCell: UITableViewCell {

    // MARK: - Constants

    static let reuseID = "DeviceCell"

    // MARK: - Layout 常量（设备专用）

    private enum Layout {
        /// 卡片上下左右外边距
        static let cardVerticalMargin: CGFloat = AppSpacing.xs
        static let cardHorizontalMargin: CGFloat = AppSpacing.md

        /// 卡片内边距
        static let cardPadding: CGFloat = AppSpacing.md

        /// 设备图片尺寸
        static let imageSize: CGFloat = 80

        /// 卡片内最小上下内边距（图片 / 信息栈各自距卡片边缘的下限）
        static let cardMinVerticalPadding: CGFloat = AppSpacing.md

        /// 信息栈额外上下内边距
        static let infoStackExtraInset: CGFloat = 4

        /// 状态点直径
        static let dotDiameter: CGFloat = 8
    }

    // MARK: - UI

    /// 白色圆角卡片
    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = AppColor.Background.card
        v.layer.cornerRadius = AppSpacing.Corner.card
        v.layer.masksToBounds = true
        return v
    }()

    /// 设备图片
    private let deviceImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = AppImage.Local.devicePlaceholder
        return iv
    }()

    /// 设备名称
    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Title.card
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return l
    }()

    /// 状态点（小圆点）
    ///
    /// - Note: 圆角在 `layoutSubviews` 里按实际宽度计算——
    ///         避免固定圆角值与约束尺寸不一致导致"圆点变圆角方块"。
    private let dotView: UIView = {
        let v = UIView()
        v.clipsToBounds = true
        return v
    }()

    /// 状态文字（"已连接" / "未连接" / "故障"）
    private let statusLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Caption.emphasized
        return l
    }()

    /// 状态行：状态点 + 状态文字
    private lazy var statusStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [dotView, statusLabel])
        s.axis = .horizontal
        s.spacing = 6
        s.alignment = .center
        s.setContentHuggingPriority(.required, for: .horizontal)
        s.setContentCompressionResistancePriority(.required, for: .horizontal)
        return s
    }()

    /// 副标题（MAC 或序列号）
    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Caption.regular
        l.textColor = AppColor.Text.secondary
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingMiddle
        return l
    }()

    /// 名称 + 状态行
    private lazy var titleRow: UIStackView = {
        let s = UIStackView(arrangedSubviews: [nameLabel, statusStack])
        s.axis = .horizontal
        s.spacing = AppSpacing.sm
        s.alignment = .center
        return s
    }()

    /// 右侧信息栈：名称行 + 副标题
    private lazy var infoStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [titleRow, subtitleLabel])
        s.axis = .vertical
        s.spacing = AppSpacing.sm + 2    // 14
        s.alignment = .fill
        return s
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()

        // 取消图片加载 + 重置为占位图
        deviceImageView.cancelRemoteImageLoad()
        deviceImageView.image = AppImage.Local.devicePlaceholder

        // 清空文本
        nameLabel.text = nil
        statusLabel.text = nil
        subtitleLabel.text = nil

        // ⚠️ 必须重置状态点颜色，避免复用时残留上一台设备的状态色
        dotView.backgroundColor = nil
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        // 状态点正圆：圆角 = 宽度的一半
        dotView.layer.cornerRadius = dotView.bounds.width / 2
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(cardView)
        cardView.addSubview(deviceImageView)
        cardView.addSubview(infoStack)

        // 卡片约束
        cardView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.cardVerticalMargin)
            make.bottom.equalToSuperview().offset(-Layout.cardVerticalMargin)
            make.leading.equalToSuperview().offset(Layout.cardHorizontalMargin)
            make.trailing.equalToSuperview().offset(-Layout.cardHorizontalMargin)
        }

        // 设备图约束
        deviceImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.cardPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.imageSize)
            make.top.greaterThanOrEqualToSuperview().offset(Layout.cardMinVerticalPadding)
            make.bottom.lessThanOrEqualToSuperview().offset(-Layout.cardMinVerticalPadding)
        }

        // 信息栈约束
        let infoInset = Layout.cardMinVerticalPadding + Layout.infoStackExtraInset
        infoStack.snp.makeConstraints { make in
            make.leading.equalTo(deviceImageView.snp.trailing).offset(Layout.cardPadding)
            make.trailing.equalToSuperview().offset(-Layout.cardPadding)
            make.centerY.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview().offset(infoInset)
            make.bottom.lessThanOrEqualToSuperview().offset(-infoInset)
        }

        // 状态点固定尺寸（直径）
        dotView.snp.makeConstraints { make in
            make.width.height.equalTo(Layout.dotDiameter)
        }
    }

    // MARK: - Configure

    /// 配置单元格
    ///
    /// - Parameter device: 设备模型
    func configure(with device: DeviceModel) {
        nameLabel.text = device.name

        statusLabel.text = device.status.title
        statusLabel.textColor = device.status.color
        dotView.backgroundColor = device.status.color

        subtitleLabel.text = device.subtitle

        deviceImageView.setImage(
            device.imageURL,
            placeholder: AppImage.Local.devicePlaceholder
        )
    }
}

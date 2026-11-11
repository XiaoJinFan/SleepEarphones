//
//  DeviceCell.swift
//  SleepEarphones
//

import UIKit
import SnapKit
import Kingfisher

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
        static let infoStackExtraInset: CGFloat = AppSpacing.xxs

        /// 状态点直径
        static let dotDiameter: CGFloat = 8

        /// 状态点与文字间距
        static let dotToTextSpacing: CGFloat = 6
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
        return l
    }()

    /// 设备最后连接时间
    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Caption.regular
        l.textColor = AppColor.Text.secondary
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingMiddle
        return l
    }()

    /// 右侧信息栈：只有名称和副标题（时间）
    private lazy var infoStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [nameLabel, subtitleLabel])
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
        subtitleLabel.text = nil
    }

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
    }

    // MARK: - Configure
    
    /// 只配置名称、时间和图片，不展示连接状态
    func configure(with device: DeviceModel) {
        nameLabel.text = device.name
        subtitleLabel.text = device.subtitle
        deviceImageView.setImage(device.imageURL, placeholder: AppImage.Local.devicePlaceholder)
    }
}

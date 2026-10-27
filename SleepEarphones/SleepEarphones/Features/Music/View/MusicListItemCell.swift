//
//  MusicListItemCell.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/12.
//

import UIKit
import SnapKit

@MainActor
final class MusicListItemCell: UITableViewCell {

    // MARK: - Constants

    static let reuseID = "MusicListItemCell"

    // MARK: - Layout

    private enum Layout {
        /// 卡片垂直外边距
        static let cardVerticalMargin: CGFloat = AppSpacing.xs
        /// 卡片水平外边距
        static let cardHorizontalMargin: CGFloat = AppSpacing.md
        /// 卡片内部 padding
        static let cardPadding: CGFloat = AppSpacing.sm
        /// 封面尺寸
        static let coverSize: CGFloat = 60
        /// 封面圆角
        static let coverCornerRadius: CGFloat = 8
        /// 播放图标容器尺寸（**不是**图标本身尺寸——图标 18pt 居中于 24pt 容器）
        static let playIconContainerSize: CGFloat = 24
    }

    // MARK: - UI

    /// 卡片容器
    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = AppColor.Background.card
        v.layer.cornerRadius = AppSpacing.Corner.card
        v.clipsToBounds = true
        return v
    }()

    /// 封面图
    private let coverImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = Layout.coverCornerRadius
        iv.backgroundColor = AppColor.Background.secondary
        return iv
    }()

    /// 标题
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Body.regular
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    /// 播放 / 暂停图标
    ///
    /// - Note: `isUserInteractionEnabled = false`——点击整行都触发播放。
    private let playIconView: UIImageView = {
        let iv = UIImageView()
        iv.tintColor = AppColor.Text.primary
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = false
        return iv
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
        coverImageView.cancelRemoteImageLoad()
        coverImageView.image = nil
        titleLabel.text = nil
        // 复位默认字体——`configure` 会按播放状态重新设置
        titleLabel.font = AppFont.Body.regular
        titleLabel.textColor = AppColor.Text.primary
        playIconView.image = nil
        playIconView.tintColor = AppColor.Text.primary
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addSubview(coverImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(playIconView)

        // 卡片容器
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.cardVerticalMargin)
            make.bottom.equalToSuperview().offset(-Layout.cardVerticalMargin)
            make.leading.equalToSuperview().offset(Layout.cardHorizontalMargin)
            make.trailing.equalToSuperview().offset(-Layout.cardHorizontalMargin)
        }

        // 封面：左侧，垂直居中
        coverImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.cardPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.coverSize)
            make.top.greaterThanOrEqualToSuperview().offset(Layout.cardPadding)
            make.bottom.lessThanOrEqualToSuperview().offset(-Layout.cardPadding)
        }

        // 播放按钮：右侧
        playIconView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Layout.cardPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.playIconContainerSize)
        }

        // 标题：封面与播放按钮之间
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverImageView.snp.trailing).offset(AppSpacing.md)
            make.trailing.equalTo(playIconView.snp.leading).offset(-AppSpacing.sm)
            make.centerY.equalToSuperview()
        }
    }

    // MARK: - Configure

    /// 配置单元格
    ///
    /// - Parameters:
    ///   - item: 子分类卡片数据
    ///   - isPlaying: 是否为"正在播放"（包含播放中 + 暂停中）
    ///   - isPaused: 是否为"正在播放但已暂停"（决定图标是 ⏸ 还是 ▶）
    ///   
    func configure(with item: MusicCardItem, isPlaying: Bool, isPaused: Bool) {
        titleLabel.text = item.title
        coverImageView.setImage(
            item.coverURL,
            placeholder: AppImage.Local.emptyData
        )

        // 图标
        let iconName: String
        if isPlaying && !isPaused {
            iconName = "pause.fill"        // 播放中 → 显示暂停按钮
        } else {
            iconName = "play.fill"         // 未播放 / 已暂停 → 显示播放按钮
        }

        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        playIconView.image = UIImage(systemName: iconName, withConfiguration: config)

        // 视觉状态：字体 + 颜色（标题与图标同步）
        let themeColor = isPlaying
            ? AppColor.Brand.primary
            : AppColor.Text.primary

        titleLabel.font = isPlaying
            ? AppFont.Body.emphasized
            : AppFont.Body.regular
        titleLabel.textColor = themeColor
        playIconView.tintColor = themeColor
    }
}

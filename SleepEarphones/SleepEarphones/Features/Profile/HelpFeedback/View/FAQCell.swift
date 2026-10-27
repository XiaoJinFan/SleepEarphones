//
//  FAQCell.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/16.
//

import UIKit
import SnapKit

/// 帮助文章列表单元格
@MainActor
final class FAQCell: UITableViewCell {

    // MARK: - Constants

    /// 复用标识符
    static let reuseID = "FAQCell"

    // MARK: - Layout 常量

    private enum Layout {
        /// 卡片上下外边距
        static let cardVerticalMargin: CGFloat = AppSpacing.xs
        /// 卡片水平外边距
        static let cardHorizontalMargin: CGFloat = AppSpacing.md
        /// 卡片内部水平内边距
        static let cardPadding: CGFloat = AppSpacing.md
        /// 卡片内部垂直内边距（上下各一份）
        static let cardVerticalPadding: CGFloat = AppSpacing.md
        /// 卡片最小高度（无副标题时的视觉高度）
        static let cardMinHeight: CGFloat = 60
        /// 箭头尺寸
        static let arrowSize: CGFloat = 16
    }

    // MARK: - UI

    /// 白色圆角卡片
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = AppColor.Background.card
        view.layer.cornerRadius = AppSpacing.Corner.button
        view.clipsToBounds = true
        return view
    }()

    /// 主标题
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = AppFont.Body.emphasized
        label.textColor = AppColor.Text.primary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    /// 副标题（简介）
    ///
    /// - Note: 无内容时自动隐藏，卡片高度也随之收缩。
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = AppFont.Caption.regular
        label.textColor = AppColor.Text.secondary
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    /// 标题 + 副标题的组合容器
    private lazy var titleStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        s.axis = .vertical
        s.spacing = AppSpacing.xxs
        s.alignment = .fill
        return s
    }()

    /// 右箭头
    private let arrowImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = AppImage.System.chevronRight
        // 与 `SettingsRowView` 的箭头色统一（tertiary）
        iv.tintColor = AppColor.Text.tertiary
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameters:
    ///   - style: cell 样式（忽略，本项目自定义布局）
    ///   - reuseIdentifier: 复用标识符
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
        titleLabel.text = nil
        subtitleLabel.text = nil
        subtitleLabel.isHidden = false   // configure 会立即按数据修正
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addSubview(titleStack)
        containerView.addSubview(arrowImageView)

        // 卡片约束
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.cardVerticalMargin)
            make.bottom.equalToSuperview().offset(-Layout.cardVerticalMargin)
            make.leading.equalToSuperview().offset(Layout.cardHorizontalMargin)
            make.trailing.equalToSuperview().offset(-Layout.cardHorizontalMargin)
            make.height.greaterThanOrEqualTo(Layout.cardMinHeight)
        }

        // 标题 + 副标题栈约束
        //
        // - Note: 只用 `top` + `bottom` 撑开卡片高度——
        //         **不要**再加 `centerY`，否则与 top/bottom 形成过度约束
        //         （top + height = bottom 已隐含 centerY）
        titleStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.cardPadding)
            make.trailing.lessThanOrEqualTo(arrowImageView.snp.leading).offset(-AppSpacing.sm)
            make.top.equalToSuperview().offset(Layout.cardVerticalPadding)
            make.bottom.equalToSuperview().offset(-Layout.cardVerticalPadding)
        }

        // 箭头约束（垂直居中，右侧固定位置）
        arrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Layout.cardPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.arrowSize)
        }
    }

    // MARK: - Configure

    /// 配置单元格（带副标题）
    ///
    /// - Parameters:
    ///   - title: 主标题（`HelpFAQItem.title`）
    ///   - subtitle: 副标题（`HelpFAQItem.synopsis`）；传 nil / 空串时隐藏副标题
    ///
    /// - Note: `subtitleLabel.isHidden` 与 `UIStackView` 配合——
    ///         隐藏的 arrangedSubview 不占用 stack 空间，卡片高度自动收缩。
    func configure(title: String, subtitle: String? = nil) {
        titleLabel.text = title

        if let subtitle, !subtitle.isEmpty {
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.text = nil
            subtitleLabel.isHidden = true
        }
    }
}

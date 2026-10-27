//
//  MessageCell.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import UIKit
import SnapKit

/// 消息列表单元格 —— **普通文字消息**（无图）
@MainActor
final class MessageCell: UITableViewCell {

    // MARK: - Constants

    /// 复用标识符
    static let reuseID = "MessageCell"

    // MARK: - Layout 常量

    private enum Layout {
        /// 图标左边距
        static let iconLeading: CGFloat = 20
        /// 图标尺寸（40×40）
        static let iconSize: CGFloat = 40
        /// 文字左侧与图标的间距
        static let textLeading: CGFloat = 10
        /// 时间右边距
        static let timeTrailing: CGFloat = 20
        /// 内容上边距（同时用于下边距，保证上下对称）
        static let verticalInset: CGFloat = 20
        /// 分类名 / 标题的最小高度（允许 Dynamic Type 撑高）
        static let labelMinHeight: CGFloat = 20
    }

    // MARK: - UI

    /// 图标（圆角背景 + SF Symbol）
    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .center
        iv.tintColor = .white
        iv.clipsToBounds = true
        return iv
    }()

    /// 分类名（上行主文字）
    private let categoryLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Body.secondary
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    /// 标题（下行灰色小字，视觉上是"摘要"）
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Caption.regular
        l.textColor = AppColor.Text.secondary
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    /// 时间（右上）
    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Caption.regular
        l.textColor = AppColor.Text.secondary
        l.textAlignment = .right
        l.numberOfLines = 1
        // 右侧固定，优先压缩左侧文字
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        return l
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

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        // 图标圆形：等布局完成后按实际宽度计算
        iconImageView.layer.cornerRadius = iconImageView.bounds.width / 2
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.image = nil
        iconImageView.backgroundColor = nil
        categoryLabel.text = nil
        titleLabel.text = nil
        timeLabel.text = nil
    }

    // MARK: - Setup

    private func setupUI() {
        // 用设计系统色，自动适配暗黑模式
        backgroundColor = AppColor.Background.card
        contentView.backgroundColor = AppColor.Background.card
        selectionStyle = .default
        layer.cornerRadius = AppSpacing.Corner.card
        // 让圆角对背景真正生效
        clipsToBounds = true

        contentView.addSubview(iconImageView)
        contentView.addSubview(categoryLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(timeLabel)

        // 图标约束（leading=20, centerY, 40x40）
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.iconLeading)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.iconSize)
        }

        // 分类名约束（leading=icon.trailing+10, top=20）
        categoryLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(Layout.textLeading)
            make.top.equalToSuperview().offset(Layout.verticalInset)
            make.height.greaterThanOrEqualTo(Layout.labelMinHeight)
            make.trailing.lessThanOrEqualTo(timeLabel.snp.leading).offset(-AppSpacing.xs)
        }

        // 标题约束（leading=icon.trailing+10, top=category.bottom）
        //
        // ✅ 关键：加一条 `bottom = contentView.bottom - verticalInset`，
        //    形成从 top 到 bottom 的完整约束链——
        //    否则 `UITableView.automaticDimension` 无法推导 cell 高度。
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(categoryLabel)
            make.top.equalTo(categoryLabel.snp.bottom)
            make.height.greaterThanOrEqualTo(Layout.labelMinHeight)
            make.trailing.lessThanOrEqualToSuperview().offset(-Layout.timeTrailing)
            make.bottom.equalToSuperview().offset(-Layout.verticalInset)
        }

        // 时间约束（trailing=20, centerY=category）
        timeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Layout.timeTrailing)
            make.centerY.equalTo(categoryLabel)
        }
    }

    // MARK: - Configure

    /// 配置单元格
    ///
    /// - Parameter message: 消息模型
    ///
    /// ## 行为
    /// - 图标：圆形底 + SF Symbol（依 `message.iconColor` / `iconSymbolName`）
    /// - 分类名 / 标题 / 时间：直接映射
    func configure(with message: MessageModel) {
        // 图标：圆形底 + SF Symbol
        //
        // - `backgroundColor`：分类对应色（走设计系统）
        // - `image`：SF Symbol（用 SymbolConfiguration 限制字号，避免撑满）
        iconImageView.backgroundColor = message.iconColor
        iconImageView.image = UIImage(
            systemName: message.iconSymbolName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        )

        categoryLabel.text = message.categoryName
        titleLabel.text = message.title
        timeLabel.text = message.createTime
    }
}

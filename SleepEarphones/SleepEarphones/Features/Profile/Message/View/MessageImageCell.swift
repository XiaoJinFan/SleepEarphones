//
//  MessageImageCell.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import UIKit
import SnapKit

@MainActor
final class MessageImageCell: UITableViewCell {

    // MARK: - Constants

    /// 复用标识符
    static let reuseID = "MessageImageCell"

    // MARK: - Layout 常量

    private enum Layout {
        /// 水平边距
        static let horizontalInset: CGFloat = AppSpacing.lg
        /// 标题顶部间距
        static let titleTopInset: CGFloat = AppSpacing.md
        /// 标题最小高度
        static let titleMinHeight: CGFloat = 25
        /// 副标题最小高度
        static let subtitleMinHeight: CGFloat = 20
        /// 缩略图顶部间距
        static let imageTopInset: CGFloat = AppSpacing.xxs
        /// 缩略图高度
        static let imageHeight: CGFloat = 80
        /// 分隔线顶部间距
        static let separatorTopInset: CGFloat = AppSpacing.xs
        /// 分隔线高度
        static let separatorHeight: CGFloat = AppSpacing.Border.standard
        /// 时间顶部间距
        static let timeTopInset: CGFloat = AppSpacing.xs
        /// 时间最小高度
        static let timeMinHeight: CGFloat = 20
        /// 底部间距
        static let bottomInset: CGFloat = AppSpacing.md
    }

    // MARK: - UI

    /// 标题（**内容来自后端，已本地化**）
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Body.emphasized        // 16pt medium
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    /// 副标题（**内容来自后端，已本地化**）
    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Caption.regular        // 14pt
        l.textColor = AppColor.Text.secondary
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    /// 标题 + 副标题的组合栈
    private lazy var textStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        s.axis = .vertical
        s.spacing = 0
        s.alignment = .fill
        return s
    }()

    /// 缩略图
    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = AppSpacing.Corner.medium
        iv.backgroundColor = AppColor.Background.secondary
        return iv
    }()

    /// 分隔线
    private let separatorView: UIView = {
        let v = UIView()
        v.backgroundColor = AppColor.separator
        return v
    }()

    /// 时间（**内容来自后端，已本地化**）
    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Caption.regular
        l.textColor = AppColor.Text.secondary
        l.numberOfLines = 1
        return l
    }()

    // MARK: - Init

    /// 初始化
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Reuse

    /// 复用清理
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        subtitleLabel.text = nil
        subtitleLabel.isHidden = false
        timeLabel.text = nil
        thumbnailImageView.cancelRemoteImageLoad()
        thumbnailImageView.image = nil
    }

    // MARK: - Setup

    private func setupUI() {
        // 用设计系统色，自动适配暗黑模式
        backgroundColor = AppColor.Background.card
        contentView.backgroundColor = AppColor.Background.card
        selectionStyle = .none
        // 整个 cell 呈现为一张卡片——
        // clipsToBounds 保证圆角生效；当前无阴影，不会误裁。
        layer.cornerRadius = AppSpacing.Corner.card
        clipsToBounds = true

        contentView.addSubview(textStack)
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(separatorView)
        contentView.addSubview(timeLabel)

        // 文本栈（leading/trailing=20, top=15）
        textStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.titleTopInset)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        // 标题 / 副标题使用**最小高度**约束，
        // 保证 Dynamic Type 放大字号时文字不会被裁掉。
        titleLabel.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Layout.titleMinHeight)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Layout.subtitleMinHeight)
        }

        // 缩略图（top 到 textStack.bottom，自动随副标题显隐变化）
        thumbnailImageView.snp.makeConstraints { make in
            make.top.equalTo(textStack.snp.bottom).offset(Layout.imageTopInset)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.height.equalTo(Layout.imageHeight)
        }

        // 分隔线
        separatorView.snp.makeConstraints { make in
            make.top.equalTo(thumbnailImageView.snp.bottom)
                .offset(Layout.separatorTopInset)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.height.equalTo(Layout.separatorHeight)
        }

        // 时间
        timeLabel.snp.makeConstraints { make in
            make.top.equalTo(separatorView.snp.bottom).offset(Layout.timeTopInset)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.height.greaterThanOrEqualTo(Layout.timeMinHeight)
            // 撑开 card 底部
            make.bottom.equalToSuperview().offset(-Layout.bottomInset)
        }
    }

    // MARK: - Configure

    /// 配置单元格
    ///
    /// - Parameter message: 消息模型（**必须**有 `imageURL`，否则用 `MessageCell`）
    func configure(with message: MessageModel) {
        // 标题
        titleLabel.text = message.title

        // 副标题：为空时隐藏（`UIStackView` 自动收缩，图片上移）
        subtitleLabel.text = message.synopsis
        subtitleLabel.isHidden = !message.hasSubtitle

        // 时间
        timeLabel.text = message.createTime

        // 缩略图
        thumbnailImageView.setImage(
            message.imageURL,
            placeholder: AppImage.Local.emptyData
        )
    }
}

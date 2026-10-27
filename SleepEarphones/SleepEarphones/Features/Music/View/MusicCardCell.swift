//
//  MusicCardCell.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/10.
//

import UIKit
import SnapKit

@MainActor
final class MusicCardCell: UICollectionViewCell {

    // MARK: - Constants

    static let reuseID = "MusicCardCell"

    // MARK: - UI

    /// 封面图（正方形 + 圆角）
    private let coverImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        // 圆角与设计稿对齐（12pt）
        iv.layer.cornerRadius = AppSpacing.Corner.card
        iv.backgroundColor = AppColor.Background.card
        return iv
    }()

    /// 标题（单行，尾部截断）
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Body.secondary
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        contentView.addSubview(coverImageView)
        contentView.addSubview(titleLabel)

        // 封面：顶部铺满，高度 = 宽度（正方形）
        coverImageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(coverImageView.snp.width)
        }

        // 标题：封面下方
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(coverImageView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(20)
        }
    }

    // MARK: - Configure

    /// 配置单元格
    ///
    /// - Parameter item: 音乐卡片模型
    func configure(with item: MusicCardItem) {
        coverImageView.setImage(
            item.coverURL,
            placeholder: AppImage.Local.emptyData
        )
        titleLabel.text = item.title
    }
}

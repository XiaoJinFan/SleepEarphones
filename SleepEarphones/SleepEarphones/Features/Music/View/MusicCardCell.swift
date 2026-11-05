//
//  MusicCardCell.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/10.
//

import UIKit
import SnapKit

/// 音乐卡片 Cell（首页音乐 Tab 的分类横滑列表使用）
///
/// ## 布局结构
/// ```
/// ┌──────────────┐
/// │              │  ← 正方形封面
/// │   封面图     │
/// │              │
/// └──────────────┘
///  音乐标题          ← 单行，尾部截断
/// ```
@MainActor
final class MusicCardCell: UICollectionViewCell {

    // MARK: - Constants

    static let reuseID = "MusicCardCell"

    // MARK: - Layout

    /// 内部布局常量
    private enum Layout {
        /// 标题与封面的间距
        static let titleSpacing: CGFloat = AppSpacing.xs
    }

    // MARK: - UI

    /// 封面图（正方形 + 圆角）
    private let coverImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        // 圆角与设计稿对齐（`AppSpacing.Corner.card` = 12pt）
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

    // MARK: - Reuse

    /// 复用清理
    override func prepareForReuse() {
        super.prepareForReuse()

        // 取消远程图片加载 + 恢复占位背景（避免残留上一张图）
        coverImageView.cancelRemoteImageLoad()
        coverImageView.image = nil

        // 清空文本
        titleLabel.text = nil
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
            make.top.equalTo(coverImageView.snp.bottom).offset(Layout.titleSpacing)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    // MARK: - Configure

    /// 配置单元格
    ///
    /// - Parameter item: 音乐卡片模型（`title` / `coverURL` 已由后端本地化）
    func configure(with item: MusicCardItem) {
        coverImageView.setImage(
            item.coverURL,
            placeholder: AppImage.Local.emptyData
        )
        titleLabel.text = item.title
    }
}

// ============================================================
// MARK: - 跨文件约束说明（重要）
// ============================================================
//
// ## 本 Cell 与 `MusicViewController.CardLayout` 的耦合
//
// 本 Cell 的内部布局参数**必须**与 `MusicViewController.CardLayout` 一致：
//
// | 参数 | 本文件 | `MusicViewController` |
// |---|---|---|
// | 标题与封面间距 | `Layout.titleSpacing = AppSpacing.xs` | `CardLayout.titleSpacing = 8` |
// | 标题字体 | `AppFont.Body.secondary` | `CardLayout.titleHeight = ceil(AppFont.Body.secondary.lineHeight)` |
//
// ## 为什么需要两处同步？
//
// CollectionView 的 item 高度由 `CardLayout` 计算：
// ```swift
// let itemHeight = cardWidth + titleSpacing + titleHeight
// ```
//
// 而 Cell 内部的实际布局是：
// ```
// ┌──────────────┐
// │   cover      │  ← 高度 = cardWidth（正方形）
// └──────────────┘
//   ↕ titleSpacing
//   title        ← 高度 = 字体 lineHeight
// ```
//
// 两者**必须**严格对齐——否则：
// - `CardLayout` 计算的高度 < Cell 实际高度 → 内容被裁切
// - `CardLayout` 计算的高度 > Cell 实际高度 → 底部留白
//
// ## 修改流程
//
// 若未来需要调整本 Cell 的样式（如改字体、改间距）：
// 1. 修改本文件 `Layout.titleSpacing` 或 `titleLabel.font`
// 2. **同步**修改 `MusicViewController.CardLayout.titleSpacing` / `.titleHeight`
// 3. 运行 App 验证——**不要只改一处**
//
// ## 为什么 `CardLayout.titleHeight` 是 `static var`（计算属性）？
//
// `let` 会在首次访问时求值一次——若用户在 App 运行中调整了系统字号
// （设置 → 辅助功能 → 更大字体），`titleHeight` 不会更新，导致：
// - 字体变大 → 标题超出 Cell 高度被裁
//
// `var` 每次访问都重新计算 `AppFont.Body.secondary.lineHeight`——
// 跟随 `Content Size Category` 动态变化。
//
// ============================================================

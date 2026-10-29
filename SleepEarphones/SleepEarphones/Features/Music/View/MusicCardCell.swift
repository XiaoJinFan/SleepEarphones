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

    // MARK: - Layout

    /// 内部布局常量
    ///
    /// - Note: 这些值必须与 `MusicViewController.CardLayout` **保持一致**——
    ///         因为 Cell 内部布局与外部 itemHeight 计算共用同一套参数。
    ///         当前为"视觉设计稿"约定值。
    private enum Layout {
        /// 标题与封面的间距
        static let titleSpacing: CGFloat = 8
    }

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
    ///
    /// - Note: **不设固定高度**——由 `AppFont.Body.secondary` 的 intrinsic size 决定。
    ///         外层 `CardLayout.titleHeight` 已通过 `font.lineHeight` 计算
    ///         出对应的高度，两侧自然对齐。
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
    ///
    /// - Note: 原代码**未实现此方法**——`UICollectionView` 复用时
    ///         若 `titleLabel` / `coverImageView` 未清空，会短暂显示上一张卡片的内容。
    ///         虽然 Kingfisher 会自动取消旧图下载，但：
    ///         1. `titleLabel.text` 不会被自动清空
    ///         2. `coverImageView.image` 在 Kingfisher 加载新图前仍显示旧图
    ///         因此必须手动清理。
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
    /// - Parameter item: 音乐卡片模型
    func configure(with item: MusicCardItem) {
        coverImageView.setImage(
            item.coverURL,
            placeholder: AppImage.Local.emptyData
        )
        titleLabel.text = item.title
    }
}

// ============================================================
// MARK: - 配套改动说明（无需复制到本文件）
// ============================================================
//
// ⚠️ `MusicViewController.swift` 的 `CardLayout.titleHeight = 20` 必须同步修改：
//
// ```swift
// private enum CardLayout {
//     static let cardWidth: CGFloat = 150
//     static let interitemSpacing: CGFloat = 14
//     static let titleSpacing: CGFloat = 8
//
//     /// 标题高度 —— 基于字体行高动态计算（支持 Dynamic Type）
//     ///
//     /// - Note: 原值 `20` 是硬编码——Dynamic Type 放大字号后
//     ///         标题会被裁切（因为 `MusicCardCell` 的高度由本值决定，
//     ///         但 `UILabel` 的实际行高会随字号变大）。
//     ///
//     ///         改为 `font.lineHeight` 计算后，两侧自然对齐。
//     ///         用 `ceil` 向上取整——避免浮点像素导致文字底部被裁 1pt。
//     static var titleHeight: CGFloat {
//         ceil(AppFont.Body.secondary.lineHeight)
//     }
//
//     static let headerHeight: CGFloat = 50
//     static let sectionSpacing: CGFloat = 30
// }
// ```
//
// **为什么 `titleHeight` 是 `static var`（计算属性）而不是 `static let`？**
// - `let` 会在类型加载时（首次访问）求值一次——此时 `AppFont.Body.secondary`
//   的 `lineHeight` 按当前 trait collection 计算（通常是设备当前 Content Size）
// - `var` 每次访问都重新计算——若未来支持"App 内切换字号"，
//   `lineHeight` 变化后能反映到布局
//
// - Note: 当前 App 不支持"App 内切换字号"，`let` 也能工作。
//         用 `var` 是为未来扩展留口子，性能开销可忽略（`lineHeight` 读取纳秒级）。

//
//  MusicSectionHeaderView.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/10.
//

import UIKit
import SnapKit

/// 音乐分组标题（Section Header）
///
/// ## 布局
/// ```
/// ┌──────────────────────────────────┐
/// │ 推荐白噪音                        │  ← 高度 = CardLayout.headerHeight (50)
/// └──────────────────────────────────┘
/// ```
@MainActor
final class MusicSectionHeaderView: UICollectionReusableView {

    // MARK: - Constants

    static let reuseID = "MusicSectionHeaderView"

    // MARK: - Layout

    private enum Layout {
        /// 标题字号（基准 20pt）
        static let titleBaseSize: CGFloat = 20
        /// 字号上限（保证能放进 50pt 的 header 高度）
        static let titleMaxSize: CGFloat = 28
    }

    // MARK: - UI

    /// 分组标题
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.scaled(
            size: Layout.titleBaseSize,
            weight: .bold,
            textStyle: .title3,
            maximumPointSize: Layout.titleMaxSize
        )
        l.textColor = AppColor.Text.primary
        // 单行 + 尾部截断——避免分类名过长时与右侧内容重叠
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
        addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            // `lessThanOrEqualTo`——分类名较短时不强行拉满宽度
            make.trailing.lessThanOrEqualToSuperview()
        }
    }

    // MARK: - Configure

    /// 配置分组标题
    ///
    /// - Parameter title: 分组标题（如 `"推荐白噪音"` / `"自然"`）
    ///                    **来自后端，已按 `Accept-Language` 本地化**
    func configure(title: String) {
        titleLabel.text = title
    }
}

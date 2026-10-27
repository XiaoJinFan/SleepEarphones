//
//  CustomNoiseCategoryCell.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/13.
//

import UIKit
import SnapKit


@MainActor
final class CustomNoiseCategoryCell: UICollectionViewCell {

    // MARK: - Constants

    static let reuseID = "CustomNoiseCategoryCell"

    // MARK: - Layout

    private enum Layout {
        /// 胶囊高度
        static let chipHeight: CGFloat = 36
        /// 水平内边距（文字左右）
        static let chipHorizontalPadding: CGFloat = AppSpacing.md
        /// 最小宽度
        static let chipMinWidth: CGFloat = 60
    }

    // MARK: - UI

    /// 胶囊背景
    private let chipBackgroundView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: "#252B4D")
        v.layer.cornerRadius = Layout.chipHeight / 2
        v.clipsToBounds = true
        return v
    }()

    /// 标题
    private let titleLabel: UILabel = {
        let l = UILabel()
        // 默认用 regular（未选中态）
        l.font = AppFont.Body.secondary
        l.textColor = .white
        l.textAlignment = .center
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        // ✅ 关键：设置抗压缩优先级，避免宽度不足时截断
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        l.setContentHuggingPriority(.required, for: .horizontal)
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
        contentView.addSubview(chipBackgroundView)
        contentView.addSubview(titleLabel)

        chipBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Layout.chipHorizontalPadding)
            make.centerY.equalToSuperview()
        }
    }

    // MARK: - Configure

    /// 配置 chip
    ///
    /// - Parameters:
    ///   - title: 标题（如"海浪铃声"）
    ///   - isSelected: 是否选中
    func configure(title: String, isSelected: Bool) {
        titleLabel.text = title

        if isSelected {
            chipBackgroundView.backgroundColor = AppColor.Brand.primary
            titleLabel.font = AppFont.Body.emphasized
        } else {
            chipBackgroundView.backgroundColor = UIColor(hex: "#252B4D")
            titleLabel.font = AppFont.Body.secondary
        }
    }

    // MARK: - Size

    /// 计算 chip 所需尺寸
    ///
    /// - Parameter title: 标题
    /// - Returns: 建议尺寸（宽度自适应，高度固定）
    ///
    /// - Important: ⚠️ **用 `emphasized`（选中态字体）计算宽度**——
    ///              选中时字重变粗 + 字号变大，需要更宽的宽度。
    ///              若用 `secondary`（未选中态字体）计算，
    ///              选中后会因宽度不足而截断（显示 `...`）。
    static func size(for title: String) -> CGSize {
        // ✅ 关键修复：用 emphasized 计算
        let font = AppFont.Body.emphasized
        let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
        let width = max(Layout.chipMinWidth, textWidth + Layout.chipHorizontalPadding * 2)
        return CGSize(width: ceil(width), height: Layout.chipHeight)
    }
}

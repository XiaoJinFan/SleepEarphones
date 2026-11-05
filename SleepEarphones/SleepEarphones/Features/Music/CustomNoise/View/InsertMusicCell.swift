//
//  InsertMusicCell.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/13.
//

import UIKit
import SnapKit

@MainActor
final class InsertMusicCell: UITableViewCell {

    // MARK: - Constants

    static let reuseID = "InsertMusicCell"

    // MARK: - Layout

    private enum Layout {
        /// 单选圆圈直径
        static let radioSize: CGFloat = 22
        /// 圆圈边框宽度
        ///
        /// - Note: 1.5pt 是设计稿值——**非整数宽度**在 Retina 屏上会轻微抗锯齿，
        ///         但视觉上比 1pt 更有"存在感"，1.5pt 是常见折中。
        static let radioBorderWidth: CGFloat = 1.5
        /// 圆圈左边距
        static let radioLeadingInset: CGFloat = AppSpacing.md
        /// 圆圈到标题的间距
        static let radioToTitleSpacing: CGFloat = AppSpacing.md
        /// 标题右边距
        static let titleTrailingInset: CGFloat = AppSpacing.md
    }

    // MARK: - UI

    /// 单选圆圈
    private let radioView: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.layer.borderWidth = Layout.radioBorderWidth
        // 初始为未选中态边框（`updateBorderColor` 会按 trait 重新解析）
        v.layer.borderColor = AppColor.separator.cgColor
        v.layer.cornerRadius = Layout.radioSize / 2
        v.clipsToBounds = true
        return v
    }()

    /// 选中态的勾
    private let checkImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(
            systemName: "checkmark",
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: 11,
                weight: .bold
            )
        )
        iv.tintColor = .white
        // `.center` —— 图标按自身 intrinsic size 居中，不拉伸
        iv.contentMode = .center
        iv.isHidden = true
        return iv
    }()

    /// 名字（**内容来自后端，已本地化**）
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Body.regular
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    // MARK: - State

    /// 当前是否处于选中态
    private var isCurrentlySelected = false

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        registerTraitChangeObservation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Reuse

    /// 复用清理
    override func prepareForReuse() {
        super.prepareForReuse()

        titleLabel.text = nil

        // 重置为未选中态
        isCurrentlySelected = false
        radioView.backgroundColor = .clear
        radioView.layer.borderColor = AppColor.separator
            .resolvedColor(with: traitCollection)
            .cgColor
        checkImageView.isHidden = true
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(radioView)
        radioView.addSubview(checkImageView)
        contentView.addSubview(titleLabel)

        radioView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.radioLeadingInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.radioSize)
        }

        checkImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(radioView.snp.trailing).offset(Layout.radioToTitleSpacing)
            make.trailing.equalToSuperview().offset(-Layout.titleTrailingInset)
            make.centerY.equalToSuperview()
        }
    }

    // MARK: - Trait 变化监听

    /// 注册 trait 变化监听（iOS 17+）
    private func registerTraitChangeObservation() {
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (cell: InsertMusicCell, _) in
                cell.reapplyBorderColorIfNeeded()
            }
        }
    }

    /// 旧版兼容（iOS 17 以下）
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // iOS 17+ 由 registerForTraitChanges 处理，避免重复
        if #available(iOS 17.0, *) { return }

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            reapplyBorderColorIfNeeded()
        }
    }

    /// 按当前 trait 重新应用边框色
    private func reapplyBorderColorIfNeeded() {
        let color = isCurrentlySelected
            ? AppColor.Brand.primary
            : AppColor.separator
        radioView.layer.borderColor = color
            .resolvedColor(with: traitCollection)
            .cgColor
    }

    // MARK: - Configure

    /// 配置单元格
    ///
    /// - Parameters:
    ///   - song: 音乐数据（`title` 来自后端）
    ///   - isSelected: 是否已选中
    func configure(with song: MusicSong, isSelected: Bool) {
        titleLabel.text = song.title

        isCurrentlySelected = isSelected

        if isSelected {
            // 选中态：实心蓝圈 + 白勾
            radioView.backgroundColor = AppColor.Brand.primary
            radioView.layer.borderColor = AppColor.Brand.primary
                .resolvedColor(with: traitCollection)
                .cgColor
            checkImageView.isHidden = false
        } else {
            // 未选中态：透明 + 灰色边框
            radioView.backgroundColor = .clear
            radioView.layer.borderColor = AppColor.separator
                .resolvedColor(with: traitCollection)
                .cgColor
            checkImageView.isHidden = true
        }
    }
}

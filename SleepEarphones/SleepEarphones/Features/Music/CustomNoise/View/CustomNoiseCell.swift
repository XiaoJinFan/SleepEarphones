//
//  CustomNoiseCell.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/13.
//

import UIKit
import SnapKit

@MainActor
final class CustomNoiseCell: UICollectionViewCell {

    // MARK: - Constants

    static let reuseID = "CustomNoiseCell"

    // MARK: - Layout

    private enum Layout {
        /// 圆形图标直径
        static let iconSize: CGFloat = 56
        /// 名字高度
        static let titleHeight: CGFloat = 18
        /// 名字与图标的间距
        static let titleSpacing: CGFloat = AppSpacing.xs
        /// 选中态外圈与图标间距
        static let selectionRingInset: CGFloat = 8
        /// 选中态外圈边框宽度
        static let selectionRingBorderWidth: CGFloat = 2
        /// 图标背景色（固定深蓝，与 `CustomNoiseViewController` 主背景同色系）
        static let iconBackgroundHex = "#262849"
    }

    // MARK: - UI

    /// 圆形图标容器
    private let iconContainer: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: Layout.iconBackgroundHex)
        v.layer.cornerRadius = Layout.iconSize / 2
        v.clipsToBounds = true
        return v
    }()

    /// 图标（图片 / SF Symbol）
    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()

    /// 选中态边框（外圈光环）
    private let selectionRing: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.layer.borderWidth = Layout.selectionRingBorderWidth
        v.layer.borderColor = AppColor.Brand.primary.cgColor
        v.layer.cornerRadius = (Layout.iconSize + Layout.selectionRingInset) / 2
        v.isHidden = true
        return v
    }()

    /// 名字（**内容来自后端，已本地化**）
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Caption.regular
        l.textColor = .white
        l.textAlignment = .center
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
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

        // 清空图标
        iconImageView.cancelRemoteImageLoad()
        iconImageView.image = nil
        iconImageView.tintColor = nil
        iconImageView.contentMode = .scaleAspectFill

        // 清空文字
        titleLabel.text = nil
        titleLabel.textColor = .white

        // 重置选中态
        selectionRing.isHidden = true
    }

    // MARK: - Setup

    private func setupUI() {
        contentView.addSubview(iconContainer)
        iconContainer.addSubview(iconImageView)
        contentView.addSubview(selectionRing)
        contentView.addSubview(titleLabel)

        iconContainer.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.height.equalTo(Layout.iconSize)
        }

        iconImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Layout.selectionRingInset)
        }

        selectionRing.snp.makeConstraints { make in
            make.center.equalTo(iconContainer)
            make.width.height.equalTo(Layout.iconSize + Layout.selectionRingInset)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconContainer.snp.bottom).offset(Layout.titleSpacing)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Layout.titleHeight)
        }
    }

    // MARK: - Trait 变化监听

    /// 注册 trait 变化监听（iOS 17+）
    private func registerTraitChangeObservation() {
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (cell: CustomNoiseCell, _) in
                cell.reapplySelectionRingColor()
            }
        }
    }

    /// 旧版兼容（iOS 17 以下）
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // iOS 17+ 由 registerForTraitChanges 处理，避免重复
        if #available(iOS 17.0, *) { return }

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            reapplySelectionRingColor()
        }
    }

    /// 按当前 trait 重新应用选中态外圈颜色
    private func reapplySelectionRingColor() {
        selectionRing.layer.borderColor = AppColor.Brand.primary
            .resolvedColor(with: traitCollection)
            .cgColor
    }

    // MARK: - Configure

    /// 配置单元格
    ///
    /// - Parameters:
    ///   - song: 音乐数据（`title` / `coverURL` 来自后端）
    ///   - isSelected: 是否已选中
    ///   - order: 选中的序号（`1` / `2` / `3`），未选中传 `nil`
    func configure(with song: MusicSong, isSelected: Bool, order: Int?) {
        titleLabel.text = song.title

        // 封面
        if let coverURL = song.coverURL, !coverURL.isEmpty {
            iconImageView.setImage(coverURL, placeholder: AppImage.Local.emptyData)
            iconImageView.contentMode = .scaleAspectFill
            // 重置 tintColor——复用路径中可能残留上一次的白色
            iconImageView.tintColor = nil
        } else {
            iconImageView.image = UIImage(
                systemName: "waveform",
                withConfiguration: UIImage.SymbolConfiguration(
                    pointSize: 24,
                    weight: .medium
                )
            )
            iconImageView.tintColor = .white
            iconImageView.contentMode = .center
        }

        // 选中态
        selectionRing.isHidden = !isSelected
        titleLabel.textColor = isSelected ? AppColor.Brand.primary : .white

        // ⚠️ `order` 参数暂未使用——见类注释
        _ = order
    }
}

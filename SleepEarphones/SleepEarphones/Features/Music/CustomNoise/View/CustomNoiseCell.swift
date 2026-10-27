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
        static let titleSpacing: CGFloat = 8
    }

    // MARK: - UI

    /// 圆形图标容器
    private let iconContainer: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: "#262849")
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

    /// 选中态边框
    private let selectionRing: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.layer.borderWidth = 2
        v.layer.borderColor = AppColor.Brand.primary.cgColor
        v.layer.cornerRadius = (Layout.iconSize + 8) / 2
        v.isHidden = true
        return v
    }()

    /// 名字
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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
            make.edges.equalToSuperview().inset(8)
        }

        selectionRing.snp.makeConstraints { make in
            make.center.equalTo(iconContainer)
            make.width.height.equalTo(Layout.iconSize + 8)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconContainer.snp.bottom).offset(Layout.titleSpacing)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Layout.titleHeight)
        }
    }

    // MARK: - Configure

    /// 配置单元格
    ///
    /// - Parameters:
    ///   - song: 音乐数据
    ///   - isSelected: 是否已选中
    ///   - order: 选中的序号（1 / 2 / 3），未选中传 nil
    func configure(with song: MusicSong, isSelected: Bool, order: Int?) {
        titleLabel.text = song.title

        // 封面
        if let coverURL = song.coverURL, !coverURL.isEmpty {
            iconImageView.setImage(coverURL, placeholder: AppImage.Local.emptyData)
            iconImageView.contentMode = .scaleAspectFill
        } else {
            iconImageView.image = UIImage(
                systemName: "waveform",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
            )
            iconImageView.tintColor = .white
            iconImageView.contentMode = .center
        }

        // 选中态
        selectionRing.isHidden = !isSelected
        titleLabel.textColor = isSelected ? AppColor.Brand.primary : .white
    }
}

//
//  CustomNoiseSlotView.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/13.
//

import UIKit
import SnapKit

/// 底部自定义白噪音槽位
@MainActor
final class CustomNoiseSlotView: UIView {

    // MARK: - Constants

    /// 槽位直径（与设计稿 50×50 一致）
    static let diameter: CGFloat = 50

    // MARK: - Layout

    private enum Layout {
        /// 槽位背景色（固定深蓝）
        static let backgroundHex = "#262C4D"

        /// 序号徽章尺寸
        static let badgeSize: CGFloat = 16

        /// 序号徽章字号
        static let badgePointSize: CGFloat = 10

        /// 无封面时的 SF Symbol 字号
        static let placeholderSymbolPointSize: CGFloat = 20
    }

    // MARK: - Callbacks

    /// 点击回调
    var onTap: (() -> Void)?

    // MARK: - UI

    /// 槽位背景（深色实心圆）
    private let backgroundView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: Layout.backgroundHex)
        v.layer.cornerRadius = CustomNoiseSlotView.diameter / 2
        v.clipsToBounds = true
        return v
    }()

    /// 封面图（圆形）
    private let coverImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = CustomNoiseSlotView.diameter / 2
        return iv
    }()

    /// 序号徽章（右下角）
    private let orderLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: Layout.badgePointSize, weight: .bold)
        l.textColor = .white
        l.textAlignment = .center
        l.backgroundColor = AppColor.Brand.primary
        // 徽章 16×16——`cornerRadius = 16 / 2 = 8` 才能显示正圆
        l.layer.cornerRadius = Layout.badgeSize / 2
        l.clipsToBounds = true
        l.isHidden = true
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
        addSubview(backgroundView)
        addSubview(coverImageView)
        addSubview(orderLabel)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        coverImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        orderLabel.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview()
            make.width.height.equalTo(Layout.badgeSize)
        }

        // 点击手势
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    // MARK: - Configure

    /// 配置为空槽位（仅显示深蓝实心圆）
    func configureEmpty() {
        coverImageView.isHidden = true
        orderLabel.isHidden = true
        backgroundView.isHidden = false
    }

    /// 配置为已填充（展示封面 + 序号）
    ///
    /// - Parameters:
    ///   - song: 歌曲（`coverURL` 来自后端）
    ///   - order: 序号（`1` / `2` / `3`）——**纯数字，不参与国际化**
    func configure(with song: MusicSong, order: Int) {
        coverImageView.isHidden = false
        orderLabel.isHidden = false
        orderLabel.text = "\(order)"

        if let url = song.coverURL, !url.isEmpty {
            // 有封面：加载远程图片
            coverImageView.setImage(url, placeholder: AppImage.Local.emptyData)
            coverImageView.contentMode = .scaleAspectFill
        } else {
            // 无封面：SF Symbol 占位（图标无语言）
            coverImageView.image = UIImage(
                systemName: "waveform",
                withConfiguration: UIImage.SymbolConfiguration(
                    pointSize: Layout.placeholderSymbolPointSize,
                    weight: .medium
                )
            )
            coverImageView.tintColor = .white
            coverImageView.contentMode = .center
            coverImageView.backgroundColor = UIColor(hex: Layout.backgroundHex)
        }
    }

    // MARK: - Actions

    @objc private func handleTap() {
        onTap?()
    }
}

//
//  MiniPlayerView.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/12.
//

import UIKit
import SnapKit

/// 迷你播放条
///
/// ## 职责
/// - 在音乐 Tab / 音乐列表页的底部展示"当前正在播放的曲目"
/// - 支持点击整条进入播放页 / 点击播放按钮切换播放暂停
/// - 由 `MusicViewController` / `MusicListViewController` **共同持有**（各自一份）
///
/// ## 布局结构
/// ```
/// ┌──────────────────────────────────────────┐
/// │ ┌────┐                                   │
/// │ │封面│  音乐名                    [▶/⏸]  │
/// │ └────┘                                   │
/// └──────────────────────────────────────────┘
/// ```
@MainActor
final class MiniPlayerView: UIView {

    // MARK: - Constants

    /// 迷你条高度
    static let height: CGFloat = 64

    // MARK: - Layout

    private enum Layout {
        /// 容器内边距
        static let containerInset: CGFloat = AppSpacing.md
        /// 封面尺寸
        static let coverSize: CGFloat = 48
        /// 封面圆角
        static let coverCornerRadius: CGFloat = AppSpacing.Corner.medium
        /// 封面左内边距
        static let coverLeadingInset: CGFloat = AppSpacing.xs
        /// 播放按钮尺寸
        static let playButtonSize: CGFloat = 40
        /// 播放按钮右内边距
        static let playButtonTrailingInset: CGFloat = AppSpacing.xs
        /// 封面到标题的间距
        static let coverToTitleSpacing: CGFloat = AppSpacing.sm
        /// 标题到播放按钮的间距
        static let titleToButtonSpacing: CGFloat = AppSpacing.sm
        /// 播放图标 SF Symbol 字号
        static let playIconPointSize: CGFloat = 32
    }

    // MARK: - Callbacks

    /// 点击整条（打开播放页）
    var onTap: (() -> Void)?

    /// 点击播放 / 暂停按钮
    var onPlayPause: (() -> Void)?

    // MARK: - Private State

    /// 上次配置的曲目 ID（用于跳过无意义的重复 `configure`）
    private var lastConfiguredSongID: String?

    /// 上次配置的封面 URL（用于判断是否需要重新加载图片）
    private var lastConfiguredCoverURL: String?

    // MARK: - UI

    /// 白色圆角容器
    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = AppColor.Background.card
        v.layer.cornerRadius = AppSpacing.Corner.card
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.08
        v.layer.shadowOffset = CGSize(width: 0, height: -2)
        v.layer.shadowRadius = 8
        return v
    }()

    /// 封面图
    private let coverImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = Layout.coverCornerRadius
        iv.backgroundColor = AppColor.Background.secondary
        return iv
    }()

    /// 音乐名（**内容来自后端，已本地化**）
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Body.emphasized
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    /// 播放 / 暂停按钮
    private let playPauseButton: UIButton = {
        let b = UIButton(type: .system)
        b.tintColor = AppColor.Text.primary
        return b
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
        backgroundColor = .clear

        addSubview(containerView)
        containerView.addSubview(coverImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(playPauseButton)

        // 容器：左右缩进 16pt
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(
                top: 0, left: Layout.containerInset,
                bottom: 0, right: Layout.containerInset
            ))
        }

        // 封面：左 8pt，垂直居中，48x48
        coverImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.coverLeadingInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.coverSize)
        }

        // 播放按钮：右 8pt，40x40
        playPauseButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Layout.playButtonTrailingInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.playButtonSize)
        }

        // 标题：封面右边 12pt，播放按钮左边 12pt
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverImageView.snp.trailing).offset(Layout.coverToTitleSpacing)
            make.trailing.equalTo(playPauseButton.snp.leading).offset(-Layout.titleToButtonSpacing)
            make.centerY.equalToSuperview()
        }

        // 点击整条
        let tap = UITapGestureRecognizer(target: self, action: #selector(containerTapped))
        containerView.addGestureRecognizer(tap)

        // 播放按钮
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
    }

    // MARK: - Configure

    /// 配置内容
    ///
    /// - Parameters:
    ///   - song: 当前播放的音乐（`title` / `coverURL` 已由后端本地化）
    ///   - isPlaying: 是否正在播放（决定按钮图标）
    func configure(with song: MusicSong, isPlaying: Bool) {
        titleLabel.text = song.title

        // 封面：仅当曲目或封面 URL 变化时才重新加载
        let coverChanged = (song.id != lastConfiguredSongID)
            || (song.coverURL != lastConfiguredCoverURL)

        if coverChanged {
            coverImageView.setImage(
                song.coverURL,
                placeholder: AppImage.Local.emptyData
            )
            lastConfiguredSongID = song.id
            lastConfiguredCoverURL = song.coverURL
        }

        // 播放 / 暂停图标（SF Symbol，无国际化）
        let iconName = isPlaying ? "pause.circle.fill" : "play.circle.fill"
        let config = UIImage.SymbolConfiguration(
            pointSize: Layout.playIconPointSize,
            weight: .regular
        )
        playPauseButton.setImage(
            UIImage(systemName: iconName, withConfiguration: config),
            for: .normal
        )
    }

    // MARK: - Actions

    @objc private func containerTapped() {
        onTap?()
    }

    @objc private func playPauseTapped() {
        onPlayPause?()
    }
}

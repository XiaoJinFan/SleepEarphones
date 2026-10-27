//
//  MiniPlayerView.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/12.
//

import UIKit
import SnapKit

///
/// ## 调用方法
/// ```swift
/// let mini = MiniPlayerView()
/// mini.onTap = { /* 打开播放页 */ }
/// mini.onPlayPause = { MusicPlayerManager.shared.toggle() }
/// mini.configure(with: song, isPlaying: true)
/// ```
@MainActor
final class MiniPlayerView: UIView {

    // MARK: - Constants

    /// 迷你条高度
    static let height: CGFloat = 64

    // MARK: - Callbacks

    /// 点击整条（打开播放页）
    var onTap: (() -> Void)?

    /// 点击播放 / 暂停按钮
    var onPlayPause: (() -> Void)?

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
        iv.layer.cornerRadius = 8
        iv.backgroundColor = AppColor.Background.secondary
        return iv
    }()

    /// 音乐名
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
                top: 0, left: AppSpacing.md,
                bottom: 0, right: AppSpacing.md
            ))
        }

        // 封面：左 8pt，垂直居中，48x48
        coverImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(48)
        }

        // 播放按钮：右 8pt，40x40
        playPauseButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }

        // 标题：封面右边 12pt，播放按钮左边 12pt
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverImageView.snp.trailing).offset(12)
            make.trailing.equalTo(playPauseButton.snp.leading).offset(-12)
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
    ///   - song: 当前播放的音乐
    ///   - isPlaying: 是否正在播放（决定按钮图标）
    func configure(with song: MusicSong, isPlaying: Bool) {
        titleLabel.text = song.title
        coverImageView.setImage(song.coverURL, placeholder: AppImage.Local.emptyData)

        let iconName = isPlaying ? "pause.circle.fill" : "play.circle.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .regular)
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

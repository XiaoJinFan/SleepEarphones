//
//  MusicPlayerViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/12.
//

import UIKit
import SnapKit
import AVFoundation
import Combine

@MainActor
final class MusicPlayerViewController: UIViewController {

    // MARK: - Playback Mode

    /// 播放模式（底部左侧按钮）
    private enum PlaybackMode {
        /// 顺序播放
        case sequential
        /// 单曲循环
        case singleLoop
        /// 随机播放
        case shuffle

        /// 循环切换
        mutating func toggle() {
            switch self {
            case .sequential: self = .singleLoop
            case .singleLoop: self = .shuffle
            case .shuffle:    self = .sequential
            }
        }

        /// SF Symbol 图标名
        var iconName: String {
            switch self {
            case .sequential: return "repeat"
            case .singleLoop: return "repeat.1"
            case .shuffle:    return "shuffle"
            }
        }

        /// 显示名（Toast 提示用）
        var displayName: String {
            switch self {
            case .sequential: return "顺序播放"
            case .singleLoop: return "单曲循环"
            case .shuffle:    return "随机播放"
            }
        }
    }

    // MARK: - Constants

    private enum Layout {
        /// 顶部栏按钮尺寸
        static let topButtonSize: CGFloat = 44
        /// 圆形封面直径
        static let coverDiameter: CGFloat = 240
        /// 底部按钮尺寸
        static let bottomButtonSize: CGFloat = 56
        /// 播放按钮尺寸
        static let playButtonSize: CGFloat = 72
        /// 底部栏距底部安全区偏移
        static let bottomOffset: CGFloat = 60
    }

    // MARK: - Properties

    /// 全局播放管理器（单例）
    private let playerManager = MusicPlayerManager.shared

    /// 进入 PlayerVC 前的导航栏状态（用于返回时恢复）
    private var wasNavigationBarHidden: Bool = false

    /// 当前展示的音乐（**可变**——订阅 `currentSong` 变化后更新）
    private var song: MusicSong

    /// 当前播放模式（仅 UI 状态）
    private var playbackMode: PlaybackMode = .sequential

    /// 定时关闭剩余秒数（0 = 无定时）
    private var countdownSeconds: Int = 0

    /// 倒计时 Timer
    private var countdownTimer: Timer?

    /// Combine 订阅容器
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI

    /// 关闭按钮（左上）
    private lazy var closeButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(
            UIImage(systemName: "chevron.down",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)),
            for: .normal
        )
        b.tintColor = .white
        b.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return b
    }()

    /// 倒计时 Label（中上）
    private lazy var countdownLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 20, weight: .medium)
        l.textColor = .white
        l.textAlignment = .center
        l.text = ""
        return l
    }()

    /// 菜单按钮（右上）
    private lazy var menuButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(
            UIImage(systemName: "list.bullet",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)),
            for: .normal
        )
        b.tintColor = .white
        b.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
        return b
    }()

    /// 音乐名称
    private lazy var titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 24, weight: .semibold)
        l.textColor = .white
        l.textAlignment = .center
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    /// 封面容器（圆形，白色边框）
    private lazy var coverContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.layer.borderWidth = 2
        v.layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
        v.layer.cornerRadius = Layout.coverDiameter / 2
        v.clipsToBounds = true
        return v
    }()

    /// 封面图
    private lazy var coverImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()

    /// 播放模式按钮（底部左侧）
    private lazy var modeButton: UIButton = {
        let b = UIButton(type: .system)
        b.tintColor = .white
        b.addTarget(self, action: #selector(modeTapped), for: .touchUpInside)
        return b
    }()

    /// 播放 / 暂停按钮（底部中央，蓝色圆形）
    private lazy var playPauseButton: UIButton = {
        let b = UIButton(type: .system)
        b.backgroundColor = UIColor(hex: "#2FA9E0")
        b.tintColor = .white
        b.layer.cornerRadius = Layout.playButtonSize / 2
        b.clipsToBounds = true
        b.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        return b
    }()

    /// 定时关闭按钮（底部右侧）
    private lazy var timerButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(
            UIImage(systemName: "clock",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)),
            for: .normal
        )
        b.tintColor = .white
        b.addTarget(self, action: #selector(timerTapped), for: .touchUpInside)
        return b
    }()

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter song: 要播放的音乐
    init(song: MusicSong) {
        self.song = song
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        refreshContent()
        refreshModeButton()
        refreshPlayPauseButton()

        // 委托 Manager 播放（同一首继续，不同首切换）
        playerManager.play(song: song)

        // 订阅播放状态
        bindPlayerState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 保存进入前的导航栏状态
        wasNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false

        // 隐藏导航栏（沉浸式）
        navigationController?.setNavigationBarHidden(true, animated: animated)

        // 每次进入时**同步 Manager 的当前歌曲**——
        // 处理"从列表页播放了新歌 → 返回本页"的场景
        syncWithManager()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // 恢复导航栏状态
        navigationController?.setNavigationBarHidden(wasNavigationBarHidden, animated: animated)
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor(hex: "#0A1430")

        view.addSubview(closeButton)
        view.addSubview(countdownLabel)
        view.addSubview(menuButton)
        view.addSubview(titleLabel)
        view.addSubview(coverContainer)
        coverContainer.addSubview(coverImageView)
        view.addSubview(modeButton)
        view.addSubview(playPauseButton)
        view.addSubview(timerButton)
    }

    private func setupConstraints() {
        // 顶部栏：关闭按钮（左）
        closeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(AppSpacing.md)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(AppSpacing.sm)
            make.width.height.equalTo(Layout.topButtonSize)
        }

        // 顶部栏：倒计时（中）
        countdownLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }

        // 顶部栏：菜单按钮（右）
        menuButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-AppSpacing.md)
            make.centerY.equalTo(closeButton)
            make.width.height.equalTo(Layout.topButtonSize)
        }

        // 音乐名称
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(closeButton.snp.bottom).offset(AppSpacing.xxl)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.xl)
        }

        // 圆形封面
        coverContainer.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(AppSpacing.xxl)
            make.width.height.equalTo(Layout.coverDiameter)
        }

        coverImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 播放 / 暂停按钮（底部中央）
        playPauseButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-Layout.bottomOffset)
            make.width.height.equalTo(Layout.playButtonSize)
        }

        // 播放模式按钮（播放按钮左侧）
        modeButton.snp.makeConstraints { make in
            make.centerY.equalTo(playPauseButton)
            make.trailing.equalTo(playPauseButton.snp.leading).offset(-AppSpacing.xxl)
            make.width.height.equalTo(Layout.bottomButtonSize)
        }

        // 定时按钮（播放按钮右侧）
        timerButton.snp.makeConstraints { make in
            make.centerY.equalTo(playPauseButton)
            make.leading.equalTo(playPauseButton.snp.trailing).offset(AppSpacing.xxl)
            make.width.height.equalTo(Layout.bottomButtonSize)
        }
    }

    /// 刷新标题与封面（**从 `self.song` 读取**）
    private func refreshContent() {
        titleLabel.text = song.title.isEmpty ? "未知音乐" : song.title
        coverImageView.setImage(
            song.coverURL,
            placeholder: AppImage.Local.emptyData
        )
    }

    /// 刷新播放模式按钮图标
    private func refreshModeButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        modeButton.setImage(
            UIImage(systemName: playbackMode.iconName, withConfiguration: config),
            for: .normal
        )
    }

    /// 刷新播放 / 暂停按钮图标
    private func refreshPlayPauseButton() {
        let isPlaying = playerManager.isPlaying
        let iconName = isPlaying ? "pause.fill" : "play.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .bold)
        playPauseButton.setImage(
            UIImage(systemName: iconName, withConfiguration: config),
            for: .normal
        )
    }

    // MARK: - Sync with Manager

    /// 与 Manager 的当前歌曲同步（若不同则更新 UI）
    private func syncWithManager() {
        guard let current = playerManager.currentSong else { return }

        // 与当前展示的曲目不同：更新
        if current.id != song.id {
            AppLog.app.debug(
                "PlayerVC 同步新曲目：\(current.title, privacy: .public)（原：\(self.song.title, privacy: .public)）"
            )
            song = current
            refreshContent()
        }

        // 同步播放状态
        refreshPlayPauseButton()
    }

    // MARK: - Binding

    /// 订阅 Manager 的播放状态
    private func bindPlayerState() {
        // 播放状态 → 刷新按钮
        playerManager.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshPlayPauseButton()
            }
            .store(in: &cancellables)

        // 当前曲目变化 → 刷新 UI
        playerManager.$currentSong
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncWithManager()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    /// 关闭页面
    @objc private func closeTapped() {
        if navigationController?.viewControllers.first !== self {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    /// 播放列表菜单 → 进入列表页
    @objc private func menuTapped() {
        AppLog.app.debug("点击播放列表菜单")

        // push 音乐列表页
        let listVC = MusicListViewController(currentSong: playerManager.currentSong)
        navigationController?.pushViewController(listVC, animated: true)
    }

    /// 切换播放模式
    @objc private func modeTapped() {
        playbackMode.toggle()
        refreshModeButton()
        showToast(playbackMode.displayName)
    }

    /// 播放 / 暂停
    @objc private func playPauseTapped() {
        playerManager.toggle()
        // 状态通过订阅自动刷新
    }

    /// 定时关闭
    @objc private func timerTapped() {
        let sheet = UIAlertController(
            title: "定时关闭",
            message: nil,
            preferredStyle: .actionSheet
        )
        let options: [(String, Int)] = [
            ("15 分钟", 15 * 60),
            ("30 分钟", 30 * 60),
            ("60 分钟", 60 * 60)
        ]
        for (title, seconds) in options {
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.startCountdown(seconds: seconds)
            })
        }
        if countdownSeconds > 0 {
            sheet.addAction(UIAlertAction(title: "关闭定时", style: .destructive) { [weak self] _ in
                self?.stopCountdown()
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))

        // iPad 兼容
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = timerButton
            popover.sourceRect = timerButton.bounds
        }
        present(sheet, animated: true)
    }

    // MARK: - Countdown

    /// 开始倒计时
    ///
    /// - Parameter seconds: 倒计时总秒数
    /// 
    private func startCountdown(seconds: Int) {
        stopCountdown()
        countdownSeconds = seconds
        refreshCountdownLabel()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            // ⚠️ 核心修复：self 已释放（VC 被 pop）时必须 invalidate，
            //    否则 Timer 会被 RunLoop 持续持有，每秒唤醒却什么也不做。
            guard let self else {
                timer.invalidate()
                return
            }

            MainActor.assumeIsolated {
                self.countdownSeconds -= 1
                self.refreshCountdownLabel()
                if self.countdownSeconds <= 0 {
                    self.handleCountdownFinished()
                }
            }
        }
    }

    /// 停止倒计时
    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownSeconds = 0
        refreshCountdownLabel()
    }

    /// 刷新倒计时 Label
    private func refreshCountdownLabel() {
        if countdownSeconds <= 0 {
            countdownLabel.text = ""
        } else if countdownSeconds >= 60 {
            let minutes = countdownSeconds / 60
            countdownLabel.text = "\(minutes)M"
        } else {
            countdownLabel.text = "\(countdownSeconds)S"
        }
    }

    /// 倒计时结束 → 停止播放
    private func handleCountdownFinished() {
        stopCountdown()
        playerManager.pause()
        showToast("定时结束，已停止播放")
    }
}

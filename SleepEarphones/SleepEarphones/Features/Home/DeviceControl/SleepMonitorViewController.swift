//
//  SleepMonitorViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/11/7.
//

import UIKit
import SnapKit
import Combine

/// 睡眠监测页（无返回按钮，长按退出）
@MainActor
final class SleepMonitorViewController: UIViewController {

    // MARK: - Constants
    
    private enum Layout {
        static let timeLabelTopInset: CGFloat = 100
        static let alarmPillTopSpacing: CGFloat = 20
        static let durationLabelTopSpacing: CGFloat = 16
        
        static let longPressContainerSize: CGFloat = 100
        static let longPressOuterSize: CGFloat = 96
        static let longPressInnerSize: CGFloat = 80
        static let longPressCenterSize: CGFloat = 32
        
        static let tipsTopSpacing: CGFloat = 24
        static let musicPillBottomInset: CGFloat = 30
        static let musicPillHeight: CGFloat = 50
        
        /// 长按所需时间（秒）
        static let longPressDuration: TimeInterval = 1.5
        /// 圆环的线宽
        static let progressRingLineWidth: CGFloat = 4
    }
    
    // MARK: - Properties
    
    /// 睡眠开始时间
    private let startTime = Date()
    
    /// 定时器（每秒更新当前时间和睡眠时长）
    private var timer: Timer?
    
    /// 长按退出的延时任务
    private var exitWorkItem: DispatchWorkItem?
    
    /// 音乐数据请求
    private let musicRepository = MusicRepository.shared
    
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI
    
    /// 大号当前时间（实时跳动）
    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 72, weight: .light)
        l.textColor = AppColor.Brand.primary
        l.textAlignment = .center
        return l
    }()
    
    /// 最近闹钟胶囊视图
    private lazy var alarmPillView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: "#E5E9F2")
        v.layer.cornerRadius = 16
        v.clipsToBounds = true
        
        let icon = UIImageView(image: UIImage(systemName: "alarm"))
        icon.tintColor = AppColor.Text.tertiary
        icon.contentMode = .scaleAspectFit
        
        let label = UILabel()
        label.font = AppFont.Body.regular
        label.textColor = AppColor.Text.tertiary
        // 联动 AlarmManager 获取最近的已开启闹钟
        label.text = AlarmManager.shared.nearestActiveAlarmTime ?? L("无闹钟")
        
        v.addSubview(icon)
        v.addSubview(label)
        
        icon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }
        
        label.snp.makeConstraints { make in
            make.leading.equalTo(icon.snp.trailing).offset(6)
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
        }
        
        return v
    }()
    
    /// 睡眠时长
    private let durationLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Body.regular
        l.textColor = AppColor.Text.secondary
        l.textAlignment = .center
        return l
    }()
    
    /// 长按退出容器
    private lazy var longPressContainer: UIView = {
        let v = UIView()
        return v
    }()
    
    /// 长按外围光圈1
    private let outerRingView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: "#E5E9F2")
        v.layer.cornerRadius = Layout.longPressOuterSize / 2
        return v
    }()
    
    /// 长按外围光圈2
    private let innerRingView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: "#D3D9E5")
        v.layer.cornerRadius = Layout.longPressInnerSize / 2
        return v
    }()
    
    /// 长按中心方块
    private let centerSquareView: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 8
        return v
    }()
    
    /// 长按进度圆环（覆盖在外圈上）
    private let progressLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = AppColor.Brand.primary.cgColor
        layer.lineWidth = Layout.progressRingLineWidth
        layer.lineCap = .round
        layer.strokeEnd = 0
        return layer
    }()
    
    /// 退出提示
    private let exitTipLabel: UILabel = {
        let l = UILabel()
        l.text = L("长按退出监测")
        l.font = AppFont.Caption.regular
        l.textColor = AppColor.Text.secondary
        l.textAlignment = .center
        return l
    }()
    
    /// 不足半小时提示
    private let warningTipLabel: UILabel = {
        let l = UILabel()
        l.text = L("睡眠不足半小时不能生成报告")
        l.font = AppFont.Caption.regular
        l.textColor = AppColor.Text.primary
        l.textAlignment = .center
        return l
    }()
    
    /// 底部音乐胶囊
    private lazy var musicPillView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: "#DCE4F2")
        v.layer.cornerRadius = Layout.musicPillHeight / 2
        v.clipsToBounds = true
        return v
    }()
    
    private let musicCoverImageView: UIImageView = {
        let iv = UIImageView()
        iv.backgroundColor = AppColor.Background.card
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 18
        return iv
    }()
    
    private let musicTitleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Caption.emphasized
        l.textColor = AppColor.Text.primary
        return l
    }()
    
    private let playPauseButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.tintColor = .white
        return btn
    }()

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        setupRingLayer()
        startTimer()
        bindMusicPlayer()
        
        // 初始刷新一次 UI 状态
        refreshMusicUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        stopTimer()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .white
        
        view.addSubview(timeLabel)
        view.addSubview(alarmPillView)
        view.addSubview(durationLabel)
        
        view.addSubview(longPressContainer)
        longPressContainer.addSubview(outerRingView)
        longPressContainer.addSubview(innerRingView)
        longPressContainer.addSubview(centerSquareView)
        
        view.addSubview(exitTipLabel)
        view.addSubview(warningTipLabel)
        
        view.addSubview(musicPillView)
        musicPillView.addSubview(musicCoverImageView)
        musicPillView.addSubview(musicTitleLabel)
        musicPillView.addSubview(playPauseButton)
    }
    
    private func setupConstraints() {
        timeLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(Layout.timeLabelTopInset)
            make.centerX.equalToSuperview()
        }
        
        alarmPillView.snp.makeConstraints { make in
            make.top.equalTo(timeLabel.snp.bottom).offset(Layout.alarmPillTopSpacing)
            make.centerX.equalToSuperview()
            make.height.equalTo(32)
        }
        
        durationLabel.snp.makeConstraints { make in
            make.top.equalTo(alarmPillView.snp.bottom).offset(Layout.durationLabelTopSpacing)
            make.centerX.equalToSuperview()
        }
        
        longPressContainer.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(60)
            make.width.height.equalTo(Layout.longPressContainerSize)
        }
        
        outerRingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Layout.longPressOuterSize)
        }
        
        innerRingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Layout.longPressInnerSize)
        }
        
        centerSquareView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Layout.longPressCenterSize)
        }
        
        exitTipLabel.snp.makeConstraints { make in
            make.top.equalTo(longPressContainer.snp.bottom).offset(Layout.tipsTopSpacing)
            make.centerX.equalToSuperview()
        }
        
        warningTipLabel.snp.makeConstraints { make in
            make.top.equalTo(exitTipLabel.snp.bottom).offset(12)
            make.centerX.equalToSuperview()
        }
        
        musicPillView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-Layout.musicPillBottomInset)
            make.height.equalTo(Layout.musicPillHeight)
        }
        
        musicCoverImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(7)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(36)
        }
        
        musicTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(musicCoverImageView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(playPauseButton.snp.leading).offset(-12)
        }
        
        playPauseButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(30)
        }
        
        updateTimeAndDuration()
    }
    
    private func setupRingLayer() {
        let center = CGPoint(x: Layout.longPressContainerSize / 2, y: Layout.longPressContainerSize / 2)
        let radius = (Layout.longPressOuterSize - Layout.progressRingLineWidth) / 2
        let path = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: 1.5 * .pi,
            clockwise: true
        )
        progressLayer.path = path.cgPath
        longPressContainer.layer.addSublayer(progressLayer)
    }
    
    private func setupActions() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.05
        longPressContainer.addGestureRecognizer(longPress)
        
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
    }
    
    // MARK: - Logic
    
    private func startTimer() {
        updateTimeAndDuration()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTimeAndDuration()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimeAndDuration() {
        let now = Date()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        timeLabel.text = formatter.string(from: now)
        
        let interval = now.timeIntervalSince(startTime)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            durationLabel.text = L("睡眠时间：%lld小时%lld分钟", hours, minutes)
        } else {
            durationLabel.text = L("睡眠时间：%lld分钟", minutes)
        }
    }
    
    // MARK: - Long Press & Animation
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            startRingAnimation()
            UIView.animate(withDuration: 0.2) {
                self.longPressContainer.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
        case .ended, .cancelled, .failed:
            cancelRingAnimation()
            UIView.animate(withDuration: 0.2) {
                self.longPressContainer.transform = .identity
            }
        default:
            break
        }
    }
    
    private func startRingAnimation() {
        progressLayer.removeAllAnimations()
        progressLayer.strokeEnd = 0
        
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = Layout.longPressDuration
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        progressLayer.add(animation, forKey: "ringAnimation")
        
        exitWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.exitMonitor()
        }
        exitWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.longPressDuration, execute: workItem)
    }
    
    private func cancelRingAnimation() {
        exitWorkItem?.cancel()
        exitWorkItem = nil
        progressLayer.removeAllAnimations()
        progressLayer.strokeEnd = 0
    }
    
    private func exitMonitor() {
        AppLog.device.debug("长按完成，退出睡眠监测")
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Music Bindings & Logic
    
    /// 订阅播放器状态
    private func bindMusicPlayer() {
        let manager = MusicPlayerManager.shared
        
        // 1. 监听当前歌曲变化
        manager.$currentSong
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMusicUI()
            }
            .store(in: &cancellables)
            
        // 2. 监听播放状态
        manager.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMusicUI()
            }
            .store(in: &cancellables)
    }
    
    /// 刷新底部音乐胶囊的 UI
    private func refreshMusicUI() {
        let manager = MusicPlayerManager.shared
        
        if let song = manager.currentSong {
            // 有播放的歌曲
            musicTitleLabel.text = song.title
            musicCoverImageView.setImage(song.coverURL, placeholder: AppImage.Local.emptyData)
            musicCoverImageView.contentMode = .scaleAspectFill
            musicCoverImageView.tintColor = nil
            musicCoverImageView.backgroundColor = AppColor.Background.secondary
        } else {
            // 暂无播放
            musicTitleLabel.text = L("暂无播放")
            musicCoverImageView.image = UIImage(
                systemName: "music.note",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            )
            musicCoverImageView.contentMode = .center
            musicCoverImageView.tintColor = AppColor.Text.tertiary
            musicCoverImageView.backgroundColor = AppColor.Background.card
        }
        
        // 更新按钮图标
        let iconName = manager.isPlaying ? "pause.circle.fill" : "play.circle.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .regular)
        playPauseButton.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
    }
    
    // MARK: - Actions
    
    @objc private func playPauseTapped() {
        let manager = MusicPlayerManager.shared
        
        if manager.currentSong != nil {
            // 如果当前有音乐，直接切换播放/暂停
            manager.toggle()
        } else {
            // 如果当前没有音乐，拉取一首默认的白噪音播放
            fetchAndPlayDefaultMusic()
        }
    }
    
    /// 获取一首默认音乐并播放
    private func fetchAndPlayDefaultMusic() {
        // 1. 防抖与提示：将按钮禁用并显示加载状态
        playPauseButton.isEnabled = false
        musicTitleLabel.text = L("加载中...")
        
        // 2. 拉取自定义白噪音列表（或者拉取推荐音乐列表）
        musicRepository.fetchCustomNoises()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.playPauseButton.isEnabled = true
                    
                    if case .failure(let error) = completion {
                        if case .cancelled = error { return }
                        AppLog.app.error("自动拉取音乐失败：\(error.logCode, privacy: .public)")
                        self.showToast(L("获取音乐失败，请稍后重试"))
                        self.refreshMusicUI() // 恢复原状
                    }
                },
                receiveValue: { [weak self] songs in
                    guard let self = self else { return }
                    
                    // 3. 取第一条可播放的歌曲
                    if let firstSong = songs.first(where: { $0.canPlay }) {
                        MusicPlayerManager.shared.play(song: firstSong)
                    } else {
                        self.showToast(L("暂无可用音乐"))
                        self.refreshMusicUI()
                    }
                }
            )
            .store(in: &cancellables)
    }
}

//
//  MusicPlayerManager.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/12.
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class MusicPlayerManager {

    // MARK: - Singleton

    static let shared = MusicPlayerManager()

    private init() {
        setupNotifications()
    }

    // MARK: - Published

    /// 当前播放的音乐（nil = 无）
    @Published private(set) var currentSong: MusicSong?

    /// 是否正在播放
    @Published private(set) var isPlaying: Bool = false

    /// 播放错误回调（流媒体加载失败 / 解码失败等）
    let onPlaybackError = PassthroughSubject<NetworkError, Never>()

    // MARK: - Private（Player）

    /// 音频播放器
    private var player: AVPlayer?

    /// KVO 监听器：`player.timeControlStatus`
    private var timeControlObservation: NSKeyValueObservation?

    /// KVO 监听器：`playerItem.status`
    private var itemStatusObservation: NSKeyValueObservation?

    /// 播放完成通知观察者
    nonisolated(unsafe) private var playerEndObserver: NSObjectProtocol?

    // MARK: - Private（System Notifications）

    /// 音频中断通知观察者（来电 / 闹钟）
    nonisolated(unsafe) private var interruptionObserver: NSObjectProtocol?

    /// 音频路由变化通知观察者（拔耳机）
    nonisolated(unsafe) private var routeChangeObserver: NSObjectProtocol?

    /// 标记：是否因为系统中断（如来电）而暂停
    private var isPausedByInterruption = false

    // MARK: - Private（Audio Session）

    /// 当前 App 的音频会话是否已激活
    private var isAudioSessionActive = false

    /// 音频分类是否已配置（`.playback` 只需配置一次）
    private var hasConfiguredCategory = false

    // MARK: - Public API

    /// 播放指定音乐
    func play(song: MusicSong) {
        // 分支 1：同一首 + player 有效 → 从暂停处继续
        if currentSong?.id == song.id, let existingPlayer = player {
            activateAudioSession()
            existingPlayer.play()
            return
        }

        // 分支 2 / 3：清理旧播放器，重新加载
        cleanupPlayer()
        currentSong = song

        guard let urlString = song.audioURL,
              let url = URL(string: urlString) else {
            AppLog.app.error("音频 URL 无效：\(song.audioURL ?? "nil", privacy: .public)")
            onPlaybackError.send(.invalidURL)
            // 没有播放 → 释放音频会话，避免占用其他 App 的音频通道
            deactivateAudioSession()
            return
        }

        // 先激活 session，再创建 player——保证第一帧音频就能播放
        activateAudioSession()

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .none
        self.player = player

        setupPlayerObservers(player: player, item: item)
        player.play()

        AppLog.app.debug("开始播放：\(song.title, privacy: .public)")
    }

    /// 播放 / 暂停切换
    func toggle() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            activateAudioSession()
            player.play()
        }
    }

    /// 暂停（不销毁播放器）
    func pause() {
        player?.pause()
    }

    /// 停止并清空（销毁播放器）
    func stop() {
        cleanupPlayer()
        currentSong = nil
        deactivateAudioSession()
    }

    // MARK: - Audio Session Management

    /// 激活音频会话（幂等）
    private func activateAudioSession() {
        guard !isAudioSessionActive else { return }

        let session = AVAudioSession.sharedInstance()
        do {
            if !hasConfiguredCategory {
                try session.setCategory(.playback, mode: .default, options: [])
                hasConfiguredCategory = true
            }
            try session.setActive(true)
            isAudioSessionActive = true
        } catch {
            AppLog.app.error(
                "AVAudioSession 激活失败：\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// 取消激活音频会话（幂等）
    private func deactivateAudioSession() {
        guard isAudioSessionActive else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
            isAudioSessionActive = false
        } catch {
            // `AVAudioSessionErrorCodeIsBusy` 等错误不影响后续使用
            AppLog.app.debug(
                "AVAudioSession 取消激活失败：\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Observers Setup

    /// 监听播放器与 Item 的内部状态变化
    private func setupPlayerObservers(player: AVPlayer, item: AVPlayerItem) {
        // 1. 监听 timeControlStatus（控制 isPlaying 的唯一真相来源）
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let playing = (player.timeControlStatus == .playing)
                if self.isPlaying != playing {
                    self.isPlaying = playing
                }
            }
        }

        // 2. 监听 AVPlayerItem 状态（捕获流媒体加载失败）
        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if item.status == .failed {
                    let errorMsg = item.error?.localizedDescription ?? "未知错误"
                    AppLog.app.error("音频播放失败：\(errorMsg, privacy: .public)")

                    // 用 NetworkError 包装，方便 UI 层处理
                    let networkError = NetworkError.underlying(
                        NSError(
                            domain: "MusicPlayer",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "音频加载失败：\(errorMsg)"]
                        )
                    )
                    self.onPlaybackError.send(networkError)

                    // 播放失败 → 释放播放器 + 取消激活 session
                    //
                    // - Note: 若不 deactivate，其他 App 的音频输出会被阻塞。
                    self.cleanupPlayer()
                    self.deactivateAudioSession()
                }
            }
        }

        // 3. 监听播放完成
        playerEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handlePlayToEnd()
            }
        }
    }

    // MARK: - System Notifications

    /// 监听系统级通知（音频中断、路由变化）
    private func setupNotifications() {
        // 1. 监听音频中断（来电 / 闹钟）
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt

            Task { @MainActor [weak self] in
                self?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }

        // 2. 监听音频路由变化（拔耳机）
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt

            Task { @MainActor [weak self] in
                self?.handleRouteChange(reasonValue: reasonValue)
            }
        }
    }

    /// 处理音频中断
    ///
    /// ## 系统行为（重要）
    /// - `.began`：系统**自动** deactivate 当前 App 的 session → 同步标志位
    /// - `.ended`：session **不会**自动恢复激活 → 需要主动 `setActive(true)`
    ///
    /// - Parameters:
    ///   - typeValue: 中断类型（原始值）
    ///   - optionsValue: 中断选项（原始值）
    private func handleInterruption(typeValue: UInt?, optionsValue: UInt?) {
        guard let typeValue = typeValue,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // 中断开始（如来电）——系统自动停用 session
            AppLog.app.debug("音频播放被中断，系统已停用 session")
            // ⚠️ 关键：标志位同步为 false——否则后续 activate 会被错误地跳过
            isAudioSessionActive = false

            if player?.timeControlStatus == .playing {
                isPausedByInterruption = true
                player?.pause()
            }

        case .ended:
            // 中断结束
            guard let optionsValue = optionsValue else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

            // 系统允许恢复 + 中断前正在播放 → 自动恢复
            if options.contains(.shouldResume) && isPausedByInterruption {
                AppLog.app.debug("中断结束，恢复播放")
                // ⚠️ 关键：session 不会自动恢复，必须重新激活
                activateAudioSession()
                player?.play()
            }
            isPausedByInterruption = false

        @unknown default:
            break
        }
    }

    /// 处理音频路由变化（如拔耳机）
    ///
    /// - Parameter reasonValue: 路由变化原因（原始值）
    private func handleRouteChange(reasonValue: UInt?) {
        guard let reasonValue = reasonValue,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        // 旧设备不可用（通常是拔出了耳机）
        if reason == .oldDeviceUnavailable {
            AppLog.app.debug("耳机已断开，自动暂停")
            player?.pause()
        }
    }

    // MARK: - Private Helpers

    /// 播放完成
    private func handlePlayToEnd() {
        player?.seek(to: .zero)
        player?.pause()
    }

    /// 销毁播放器及所有监听
    private func cleanupPlayer() {
        player?.pause()
        player = nil

        timeControlObservation?.invalidate()
        timeControlObservation = nil

        itemStatusObservation?.invalidate()
        itemStatusObservation = nil

        if let observer = playerEndObserver {
            NotificationCenter.default.removeObserver(observer)
            playerEndObserver = nil
        }

        isPlaying = false
    }

    /// 释放资源
    deinit {
        // 移除所有通知观察者（AudioSession 与 PlayerEnd）
        if let observer = playerEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

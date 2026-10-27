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
    ///
    /// - Note: 完全由 KVO 监听 `timeControlStatus` 驱动，**不要**手动修改。
    @Published private(set) var isPlaying: Bool = false

    /// 播放错误回调（流媒体加载失败 / 解码失败等）
    ///
    /// - Note: UI 层可订阅此 Publisher 来显示“该音乐无法播放”的 Toast。
    ///         闭包参数为 `NetworkError`（复用网络错误模型，避免额外定义）。
    let onPlaybackError = PassthroughSubject<NetworkError, Never>()

    // MARK: - Private

    /// 音频播放器
    private var player: AVPlayer?

    /// KVO 监听器：`player.timeControlStatus`
    private var timeControlObservation: NSKeyValueObservation?

    /// KVO 监听器：`playerItem.status`
    private var itemStatusObservation: NSKeyValueObservation?

    /// 播放完成通知观察者
    private var playerEndObserver: NSObjectProtocol?

    /// 标记：是否因为系统中断（如来电）而暂停
    ///
    /// - Note: 用于在中断结束后决定是否需要自动恢复播放。
    private var isPausedByInterruption = false

    // MARK: - Public API

    /// 播放指定音乐
    ///
    /// - Parameter song: 待播放的音乐
    ///
    /// - Note:
    ///   - 若 `song.id == currentSong.id`：**继续播放**（不重新加载）
    ///   - 若不同：**切换歌曲**（重新创建 AVPlayer）
    func play(song: MusicSong) {
        // 同一首：从暂停处继续
        if currentSong?.id == song.id {
            player?.play()
            return
        }

        // 不同首：切换
        cleanupPlayer()
        currentSong = song

        guard let urlString = song.audioURL,
              let url = URL(string: urlString) else {
            AppLog.app.error("音频 URL 无效：\(song.audioURL ?? "nil", privacy: .public)")
            onPlaybackError.send(.invalidURL)
            return
        }

        setupAudioSession()

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
                        NSError(domain: "MusicPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "音频加载失败：\(errorMsg)"])
                    )
                    self.onPlaybackError.send(networkError)
                    self.cleanupPlayer()
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
        NotificationCenter.default.addObserver(
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
        NotificationCenter.default.addObserver(
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
            // 中断开始（如来电）
            AppLog.app.debug("音频播放被中断")
            if player?.timeControlStatus == .playing {
                isPausedByInterruption = true
                player?.pause()
            }

        case .ended:
            // 中断结束
            guard let optionsValue = optionsValue else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

            // 如果中断结束且系统允许恢复，并且之前是播放状态，则自动恢复
            if options.contains(.shouldResume) && isPausedByInterruption {
                AppLog.app.debug("中断结束，恢复播放")
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

    /// 配置音频会话（允许后台播放）
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            AppLog.app.error("AVAudioSession 配置失败：\(error.localizedDescription, privacy: .public)")
        }
    }

    /// 播放完成
    private func handlePlayToEnd() {
        // 默认：停止（后续可接入单曲循环 / 播放列表）
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

    deinit {
        // 仅移除播放完成监听，全局的系统中断监听随单例存活，无需手动移除
        if let observer = playerEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

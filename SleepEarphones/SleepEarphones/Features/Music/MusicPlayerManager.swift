//
//  MusicPlayerManager.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/12.
//

import Foundation
import AVFoundation
import Combine

/// 音乐播放管理器（单例）
///
/// ## 职责
/// - 管理唯一 `AVPlayer` 实例
/// - 统一处理音频会话（激活 / 取消激活）
/// - 监听系统中断（来电 / 闹钟）与路由变化（拔耳机）
/// - 向业务层暴露当前播放状态（`@Published`）
///
/// ## 音频会话生命周期（关键）
/// | 时机 | session 状态 |
/// |---|---|
/// | `play(song:)` 开始播放 | **激活** |
/// | `toggle()` 从暂停恢复 | **激活**（幂等） |
/// | 中断结束（`.shouldResume`） | **重新激活** |
/// | 中断开始 | 系统自动停用，标志位同步置 false |
/// | `stop()` 用户主动停止 | **取消激活**（`notifyOthersOnDeactivation`） |
/// | 播放失败（`item.status == .failed`） | **取消激活** |
///
/// - Important: 若 App 只 pause 不 stop，session 仍**保持激活**——
///              这是业界惯例（用户可能随时恢复播放）。
///              但用户**主动 stop** 后，必须取消激活——
///              否则其他 App（如网易云音乐）播放时听不到声音。
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
    /// - Note: UI 层可订阅此 Publisher 来显示"该音乐无法播放"的 Toast。
    ///         闭包参数为 `NetworkError`（复用网络错误模型，避免额外定义）。
    let onPlaybackError = PassthroughSubject<NetworkError, Never>()

    // MARK: - Private（Player）

    /// 音频播放器
    private var player: AVPlayer?

    /// KVO 监听器：`player.timeControlStatus`
    private var timeControlObservation: NSKeyValueObservation?

    /// KVO 监听器：`playerItem.status`
    private var itemStatusObservation: NSKeyValueObservation?

    /// 播放完成通知观察者
    private var playerEndObserver: NSObjectProtocol?

    // MARK: - Private（System Notifications）

    /// 音频中断通知观察者（来电 / 闹钟）
    ///
    /// - Note: `addObserver(forName:object:queue:using:)` 返回的 token
    ///         **必须**保存，否则无法移除（尽管单例不会释放，但规范要求）。
    private var interruptionObserver: NSObjectProtocol?

    /// 音频路由变化通知观察者（拔耳机）
    private var routeChangeObserver: NSObjectProtocol?

    /// 标记：是否因为系统中断（如来电）而暂停
    ///
    /// - Note: 用于在中断结束后决定是否需要自动恢复播放。
    private var isPausedByInterruption = false

    // MARK: - Private（Audio Session）

    /// 当前 App 的音频会话是否已激活
    ///
    /// - Note: 用于避免重复 `setActive(true)`（系统调用有开销）；
    ///         中断时系统会自动停用，本标志位同步置 `false`。
    private var isAudioSessionActive = false

    /// 音频分类是否已配置（`.playback` 只需配置一次）
    private var hasConfiguredCategory = false

    // MARK: - Public API

    /// 播放指定音乐
    ///
    /// - Parameter song: 待播放的音乐
    ///
    /// ## 分支逻辑
    /// | 场景 | 行为 |
    /// |---|---|
    /// | **同一首** 且 `player` 存在 | 确保 session 激活 → 继续播放 |
    /// | **同一首** 但 `player` 已失效 | fall through 重新加载 |
    /// | **不同首** | 清理旧 player → 重新加载 → 播放 |
    ///
    /// - Note: "同一首但 player 已失效"的场景包括：
    ///   - 上次播放失败被 `cleanupPlayer`
    ///   - 用户调用 `stop()` 后想重新播放
    ///   - 极端情况下内存警告释放了 player
    func play(song: MusicSong) {
        // 分支 1：同一首 + player 有效 → 从暂停处继续
        //
        // - Note: `player` 存在性判断是**必须**的——
        //         若只判断 `currentSong?.id`，player 被清理后
        //         `player?.play()` 是 no-op，用户会以为播放成功但实际没声音。
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
    ///
    /// - Note: 从暂停恢复时**重新激活** session——
    ///         session 可能因 `stop()` 或系统中断被停用。
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
    ///
    /// - Important: **不**取消激活 session——
    ///              用户可能随时恢复播放，保持 session 激活可避免"恢复播放时
    ///              第一秒没声音"。
    func pause() {
        player?.pause()
    }

    /// 停止并清空（销毁播放器）
    ///
    /// - Note: 与 `pause()` 的区别是**会取消激活音频会话**——
    ///         允许其他 App（如网易云音乐）恢复音频输出。
    func stop() {
        cleanupPlayer()
        currentSong = nil
        deactivateAudioSession()
    }

    // MARK: - Audio Session Management

    /// 激活音频会话（幂等）
    ///
    /// ## 流程
    /// 1. 首次调用时配置 `category`（`.playback` + 后台播放）
    /// 2. 激活 session
    ///
    /// - Note: 用 `isAudioSessionActive` 标志避免重复系统调用——
    ///         `setActive(true)` 每次都有几百微秒开销。
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
    ///
    /// ## 关键选项
    /// `.notifyOthersOnDeactivation`——通知系统"本 App 不再占用音频"，
    /// 其他 App（如网易云音乐）会立即恢复音频输出。
    ///
    /// - Note: 若**不带**此选项，其他 App 需要等系统超时（数秒）才能恢复——
    ///         用户体验很差。
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
    ///
    /// - Note: `addObserver(forName:object:queue:using:)` 返回的 token
    ///         必须保存到属性，才能在 `deinit` 中移除。
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
    ///
    /// - Note: 默认行为——回到开头并暂停（用户可能想再听一遍）。
    ///         不 deactivate session（用户可能立即重新播放）。
    ///         后续可扩展单曲循环 / 播放列表。
    private func handlePlayToEnd() {
        player?.seek(to: .zero)
        player?.pause()
    }

    /// 销毁播放器及所有监听
    ///
    /// - Important: 本方法**不**处理音频会话——
    ///              会话激活 / 取消激活由调用方（`stop` / `play` / 播放失败）决定。
    ///              这样"切歌"场景不会中断会话（避免重新激活时的中断感）。
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
        // 移除所有通知观察者（AudioSession 与 PlayerEnd）
        //
        // - Note: 单例实际不会走 deinit，但规范要求——
        //         若未来 `shared` 改为可重建（如测试场景），此处保证无泄漏。
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

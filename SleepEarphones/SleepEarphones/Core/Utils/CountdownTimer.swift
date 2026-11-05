//
//  CountdownTimer.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/21.
//

import Foundation
import Combine

/// 倒计时计时器
///
/// ## 调用方法
/// ```swift
/// @MainActor
/// final class SomeViewModel {
///     let timer = CountdownTimer()
///     private var cancellables = Set<AnyCancellable>()
///
///     init() {
///         // 1. 订阅剩余秒数（驱动 UI）
///         timer.$remaining
///             .sink { seconds in
///                 print("剩余 \(seconds) 秒")
///             }
///             .store(in: &cancellables)
///     }
///
///     func sendCode() {
///         // 2. 启动倒计时（默认 60 秒）
///         timer.start(seconds: 60)
///     }
///
///     func reset() {
///         // 3. 取消倒计时
///         timer.cancel()
///     }
/// }
/// ```
///
@MainActor
final class CountdownTimer {

    // MARK: - Output

    /// 剩余秒数
    ///
    /// - 0 表示未启动或已结束
    /// - 每次 tick 减 1，`@Published` 自动通知订阅者
    @Published private(set) var remaining: Int = 0

    // MARK: - Private

    /// 当前运行的倒计时任务
    private var task: Task<Void, Never>?

    // MARK: - Public

    /// 是否正在运行
    ///
    /// - Returns: `remaining > 0` 时为 `true`
    ///
    var isRunning: Bool { remaining > 0 }

    /// 启动倒计时
    ///
    /// - Parameter seconds: 总秒数，默认 60
    ///
    /// - Note:
    ///   - 若已有倒计时在运行，会先取消再重新开始（幂等）
    ///   - `seconds <= 0` 时直接取消，不启动 Task
    func start(seconds: Int = 60) {
        // 非法入参：直接视为"取消"，不创建 Task
        guard seconds > 0 else {
            cancel()
            return
        }

        // 若已有任务，先取消
        cancel()

        remaining = seconds

        // 捕获当前 seconds，因为 `[weak self]` 后 self 可能变 nil
        let totalSeconds = seconds

        task = Task { [weak self] in
            var left = totalSeconds
            while left > 0 {
                // sleep 1 秒
                //
                // 使用 `do-catch`：被取消时 `Task.sleep` 抛 `CancellationError`，
                // 立即退出循环，无需等到下一次唤醒。
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    // 被取消，直接结束（cancel 已清空 task / remaining）
                    return
                }

                left -= 1

                // 因为 Task 创建时继承 @MainActor 隔离，
                // 这里无需 `await MainActor.run`，直接赋值即可。
                self?.remaining = left
            }
            // 归零：清空 task 引用，标记倒计时结束
            self?.task = nil
        }
    }

    /// 取消倒计时
    ///
    /// - Note: 会将 `remaining` 重置为 0，
    ///         保证订阅方立即收到"倒计时结束"通知。
    ///
    func cancel() {
        task?.cancel()
        task = nil
        if remaining != 0 {
            remaining = 0
        }
    }
}

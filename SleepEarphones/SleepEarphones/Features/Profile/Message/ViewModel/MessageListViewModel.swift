//
//  MessageListViewModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import Foundation
import Combine

/// 消息中心视图模型
///
/// ## 数据流
/// ```
/// MessageListViewController
///   ↓ loadMessages()
/// MessageListViewModel（本类）
///   ↓ fetchMessages(categoryId:)
/// MessageRepository
///   ↓ fetchMessageList(categoryId:)
/// MessageService
///   ↓
/// NetworkClient
/// ```
///
/// ## 调用方法
/// ```swift
/// // 1. 初始化
/// let vm = MessageListViewModel()
///
/// // 2. 触发加载
/// vm.loadMessages()
///
/// // 3. 订阅结果
/// vm.$messages
///     .receive(on: DispatchQueue.main)
///     .sink { messages in tableView.reloadData() }
///     .store(in: &cancellables)
///
/// vm.$isLoading
///     .sink { isLoading in /* 控制菊花 */ }
///     .store(in: &cancellables)
///
/// // 4. 弹窗后清除错误
/// vm.clearError()
/// ```
///
/// ## 竞态处理
/// 用单调递增的 `requestToken` 标识"当前有效的请求"：
/// - 每次发起新请求前 `&+= 1`
/// - 回调中比对令牌，过期回调直接丢弃
///
/// ## 关于 `deinit`
/// 本类**不实现** `deinit`。原因：
/// - Swift 6 中 `deinit` 是 `nonisolated`，不能访问 `@MainActor` 属性
/// - `AnyCancellable` 在 VM 释放时随属性一同释放，自动取消订阅
@MainActor
final class MessageListViewModel {

    // MARK: - Output

    /// 消息列表
    @Published private(set) var messages: [MessageModel] = []

    /// 是否正在加载（首屏显示菊花）
    @Published private(set) var isLoading: Bool = false

    /// 错误信息
    @Published private(set) var errorMessage: String?

    /// 空数据状态
    ///
    /// - Returns: 无数据 + 不在加载 + 无错误时为 `true`
    ///
    /// - Note: 计算属性，不占用内存。有错误时返回 `false`——
    ///         弹 Alert 后页面留白，与"空数据"视觉区分。
    var isEmpty: Bool {
        messages.isEmpty && !isLoading && errorMessage == nil
    }

    // MARK: - Private

    private let repository: MessageRepositoryProtocol

    /// 当前进行中的请求（用于取消，避免竞态）
    ///
    /// - Note: 本 VM 只维护**一个**在飞请求，用单独属性持有即可；
    ///         无需 `Set<AnyCancellable>`（后者适用于多订阅场景）。
    private var currentRequest: AnyCancellable?

    /// 请求身份令牌
    private var requestToken: UInt64 = 0

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter repository: 消息仓库，默认 `MessageRepository()`
    init(repository: MessageRepositoryProtocol = MessageRepository()) {
        self.repository = repository
    }

    // MARK: - Input

    /// 加载消息列表
    ///
    /// ## 幂等
    /// 若已在加载中，忽略本次调用（防止重复请求）。
    ///
    /// ## 行为
    /// - 取消旧请求 + 递增令牌（避免竞态）
    /// - 仅首屏（`messages` 为空）时显示菊花
    /// - 成功后更新 `messages`，失败后设置 `errorMessage`
    func loadMessages() {
        guard !isLoading else {
            AppLog.profile.debug("消息列表加载被拦截：已在加载中")
            return
        }

        // 取消旧请求并递增令牌
        currentRequest?.cancel()
        currentRequest = nil
        requestToken &+= 1
        let token = requestToken

        errorMessage = nil

        // 仅首屏（无数据）时显示菊花
        if messages.isEmpty {
            isLoading = true
        }

        AppLog.profile.debug("发起消息列表请求 token=\(token, privacy: .public)")

        currentRequest = repository.fetchMessages(categoryId: MessageAPI.noticeCategoryId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self, self.requestToken == token else {
                        AppLog.profile.debug("丢弃过期消息列表回调 token=\(token, privacy: .public)")
                        return
                    }
                    self.isLoading = false
                    self.currentRequest = nil

                    if case .failure(let error) = completion {
                        if case .cancelled = error { return }
                        AppLog.profile.error(
                            "消息列表加载失败：\(error.logCode, privacy: .public)"
                        )
                        self.errorMessage = error.errorDescription ?? "加载失败，请稍后重试"
                    }
                },
                receiveValue: { [weak self] messages in
                    guard let self, self.requestToken == token else { return }
                    AppLog.profile.debug(
                        "消息列表加载成功：\(messages.count, privacy: .public) 条"
                    )
                    self.messages = messages
                }
            )
    }

    // MARK: - 状态清理

    /// 清除错误
    ///
    /// - Note: UI 层弹完 Alert 后应调用本方法重置状态，
    ///         避免 `$errorMessage` 的 `compactMap` 反复触发。
    func clearError() {
        errorMessage = nil
    }
}

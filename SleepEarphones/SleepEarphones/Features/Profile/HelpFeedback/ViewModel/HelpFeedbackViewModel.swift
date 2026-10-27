//
//  HelpFeedbackViewModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import Foundation
import Combine

/// 帮助与反馈页视图模型
///
/// ## 数据流
/// ```
/// HelpFeedbackViewController
///   ↓ loadFAQs()
/// HelpFeedbackViewModel（本类）
///   ↓ fetchFAQs(categoryId:)
/// HelpRepository
///   ↓ fetchHelpList(categoryId:)
/// HelpService
///   ↓
/// NetworkClient
/// ```
///
/// ## 调用方法
/// ```swift
/// // 1. 初始化
/// let vm = HelpFeedbackViewModel()
///
/// // 2. 触发加载
/// vm.loadFAQs()
///
/// // 3. 订阅结果
/// vm.$items
///     .receive(on: DispatchQueue.main)
///     .sink { items in tableView.reloadData() }
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
final class HelpFeedbackViewModel {

    // MARK: - Output

    /// 帮助文章列表
    @Published private(set) var items: [HelpFAQItem] = []

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
        items.isEmpty && !isLoading && errorMessage == nil
    }

    // MARK: - Private

    private let repository: HelpRepositoryProtocol

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
    /// - Parameter repository: 帮助仓库，默认 `HelpRepository()`
    init(repository: HelpRepositoryProtocol = HelpRepository()) {
        self.repository = repository
    }

    // MARK: - Input

    /// 加载帮助列表
    ///
    /// ## 幂等
    /// 若已在加载中，忽略本次调用（防止重复请求）。
    ///
    /// ## 行为
    /// - 取消旧请求 + 递增令牌（避免竞态）
    /// - 仅首屏（`items` 为空）时显示菊花
    /// - 成功后更新 `items`，失败后设置 `errorMessage`
    func loadFAQs() {
        // 防抖：已在加载中不重复请求
        guard !isLoading else {
            AppLog.profile.debug("帮助列表加载被拦截：已在加载中")
            return
        }

        // 取消旧请求并递增令牌
        currentRequest?.cancel()
        currentRequest = nil
        requestToken &+= 1
        let token = requestToken

        errorMessage = nil

        // 仅首屏（无数据）时显示菊花
        if items.isEmpty {
            isLoading = true
        }

        AppLog.profile.debug("发起帮助列表请求 token=\(token, privacy: .public)")

        currentRequest = repository.fetchFAQs(categoryId: HelpAPI.helpCenterCategoryId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self, self.requestToken == token else {
                        AppLog.profile.debug("丢弃过期帮助列表回调 token=\(token, privacy: .public)")
                        return
                    }
                    self.isLoading = false
                    self.currentRequest = nil

                    if case .failure(let error) = completion {
                        if case .cancelled = error { return }
                        AppLog.profile.error(
                            "帮助列表加载失败：\(error.logCode, privacy: .public)"
                        )
                        self.errorMessage = error.errorDescription ?? "加载失败，请稍后重试"
                    }
                },
                receiveValue: { [weak self] items in
                    guard let self, self.requestToken == token else { return }
                    AppLog.profile.debug(
                        "帮助列表加载成功：\(items.count, privacy: .public) 篇"
                    )
                    self.items = items
                }
            )
    }

    // MARK: - 状态清理

    /// 清除错误
    ///
    /// - Note: UI 层弹完 Alert 后应调用本方法重置状态，
    ///         避免 `$errorMessage` 的 `compactMap` 反复触发。
    func clearError() { errorMessage = nil }
}

//
//  HelpService.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import Foundation
import Combine

// MARK: - 服务协议

/// 帮助服务协议
///
/// ## 职责
/// - 只负责**网络请求**（调用 `NetworkClient`）
/// - 不做缓存 / 不做数据转换 / 不做 UI 逻辑
///
/// ## 调用方法
/// ```swift
/// // 1. 生产环境
/// let service = HelpService()
///
/// // 2. 单元测试（注入 Mock）
/// let service = HelpService(client: MockNetworkClient())
///
/// // 3. 调用
/// service.fetchHelpList(categoryId: HelpAPI.helpCenterCategoryId)
///     .sink(
///         receiveCompletion: { ... },
///         receiveValue: { items in ... }
///     )
///     .store(in: &cancellables)
/// ```
///
/// ## 与 `MessageService` 的关系
/// | 维度 | `HelpService` | `MessageService` |
/// |---|---|---|
/// | 后端接口 | `6729cd8c2190d` | `6729cd8c2190d`（**相同**） |
/// | `operationarticlecate_id` | `2` | `1` |
/// | 返回类型 | `[HelpFAQItem]` | `[MessageModel]` |
///
/// - Note: 两者调用**同一后端接口**，仅靠 `operationarticlecate_id` 区分返回数据。
///
/// ## 关于 `Sendable`
/// 协议要求 `Sendable`——实现方需保证 `client` 属性是 `let`
/// 且类型 `Sendable`。
protocol HelpServiceProtocol: Sendable {

    /// 拉取指定分类下的帮助文章列表
    ///
    /// - Parameter categoryId: 分类 ID（见 `HelpAPI.helpCenterCategoryId`）
    /// - Returns: 文章列表 Publisher
    func fetchHelpList(categoryId: Int) -> AnyPublisher<[HelpFAQItem], NetworkError>
}

// MARK: - 服务实现

/// 帮助服务实现
final class HelpService: HelpServiceProtocol, Sendable {

    // MARK: - Properties

    private let client: NetworkClientProtocol

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter client: 网络客户端，默认 `NetworkClient()`
    init(client: NetworkClientProtocol = NetworkClient()) {
        self.client = client
    }

    // MARK: - Fetch

    /// 拉取帮助文章列表
    ///
    /// - Parameter categoryId: 分类 ID（见 `HelpAPI.helpCenterCategoryId`）
    /// - Returns: 文章列表 Publisher
    func fetchHelpList(categoryId: Int) -> AnyPublisher<[HelpFAQItem], NetworkError> {
        AppLog.profile.debug("拉取帮助列表：categoryId=\(categoryId, privacy: .public)")

        return client.request(
            HelpAPI.list(categoryId: categoryId),
            as: [HelpFAQItem].self
        )
        .eraseToAnyPublisher()
    }
}

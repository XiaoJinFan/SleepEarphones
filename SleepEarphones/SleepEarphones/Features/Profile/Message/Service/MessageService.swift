//
//  MessageService.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import Foundation
import Combine

// MARK: - 服务协议

/// 消息服务协议
///
/// ## 职责
/// - 只负责**网络请求**（调用 `NetworkClient`）
/// - 不做业务判断 / 不做数据转换
///
/// ## 调用方法
/// ```swift
/// // 1. 生产环境（通常由 MessageRepository 内部持有）
/// let service = MessageService()
///
/// // 2. 单元测试（注入 Mock）
/// let service = MessageService(client: MockNetworkClient())
///
/// // 3. 调用
/// service.fetchMessageList(categoryId: MessageAPI.noticeCategoryId)
///     .sink(
///         receiveCompletion: { ... },
///         receiveValue: { messages in ... }
///     )
///     .store(in: &cancellables)
/// ```
///
/// ## 与 `HelpService` 的关系
/// | 维度 | `MessageService` | `HelpService` |
/// |---|---|---|
/// | 后端接口 | `6729cd8c2190d` | `6729cd8c2190d`（**相同**） |
/// | `operationarticlecate_id` | `1` | `2` |
/// | 返回类型 | `[MessageModel]` | `[HelpFAQItem]` |
///
/// - Note: 两者调用**同一后端接口**，仅靠 `operationarticlecate_id` 区分返回数据：
///   - `MessageService` → `categoryId = 1`（平台公告）
///   - `HelpService` → `categoryId = 2`（帮助中心）
///
/// ## 关于 `Sendable`
/// 协议要求 `Sendable`——实现方需保证 `client` 属性是 `let`
/// 且类型 `Sendable`。
protocol MessageServiceProtocol: Sendable {

    /// 拉取指定分类下的消息列表
    ///
    /// - Parameter categoryId: 分类 ID（见 `MessageAPI.noticeCategoryId`）
    /// - Returns: 消息列表 Publisher
    func fetchMessageList(categoryId: Int) -> AnyPublisher<[MessageModel], NetworkError>
}

// MARK: - 服务实现

/// 消息服务实现
final class MessageService: MessageServiceProtocol, Sendable {

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

    /// 拉取消息列表
    ///
    /// - Parameter categoryId: 分类 ID（见 `MessageAPI.noticeCategoryId`）
    /// - Returns: 消息列表 Publisher
    func fetchMessageList(categoryId: Int) -> AnyPublisher<[MessageModel], NetworkError> {
        AppLog.profile.debug("拉取消息列表：categoryId=\(categoryId, privacy: .public)")

        return client.request(
            MessageAPI.list(categoryId: categoryId),
            as: [MessageModel].self
        )
        .eraseToAnyPublisher()
    }
}

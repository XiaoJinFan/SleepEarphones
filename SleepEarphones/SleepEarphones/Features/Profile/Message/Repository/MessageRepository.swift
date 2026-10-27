//
//  MessageRepository.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import Foundation
import Combine

// MARK: - 仓库协议

/// 消息仓库协议
///
/// ## 职责
/// - 委托 `MessageService` 发起网络请求
/// - 未来若有缓存 / 已读状态逻辑，在此实现
///
/// ## 调用方法
/// ```swift
/// // 1. 生产环境（推荐）
/// let repo = MessageRepository()
///
/// // 2. 单元测试（注入 Mock Service）
/// let repo = MessageRepository(service: MockMessageService())
///
/// // 3. 调用
/// repo.fetchMessages(categoryId: MessageAPI.noticeCategoryId)
///     .sink(
///         receiveCompletion: { ... },
///         receiveValue: { messages in ... }
///     )
///     .store(in: &cancellables)
/// ```
///
/// - Note: 当前是纯透传。保留此层是为了与其他模块（Device / Auth / Help）
///         保持**一致的分层结构**，未来扩展时有落点。
protocol MessageRepositoryProtocol: Sendable {

    /// 拉取消息列表
    ///
    /// - Parameter categoryId: 分类 ID（见 `MessageAPI.noticeCategoryId`）
    /// - Returns: 消息列表 Publisher
    func fetchMessages(categoryId: Int) -> AnyPublisher<[MessageModel], NetworkError>
}

// MARK: - 仓库实现

/// 消息仓库实现
///
/// ## 数据流
/// ```
/// ViewModel
///   ↓ fetchMessages(categoryId:)
/// MessageRepository（本类）
///   ↓ 委托
/// MessageService
///   ↓
/// NetworkClient
/// ```
///
/// ## 为什么保留这层"空壳"？
/// 当前不承担额外职责（无缓存 / 无短路 / 无转换），看起来是冗余。
/// 保留的原因：
/// 1. **分层一致性**：与 `DeviceRepository` / `AuthRepository` / `HelpRepository` 对齐
/// 2. **未来落点**：若"已读状态"或"分类过滤"等需求出现，
///    直接在本类内扩展即可，调用方零改动
/// 3. **可测试性**：测试替身直接实现 `MessageRepositoryProtocol`，
///    与生产实现完全隔离
///
/// - Note: 无状态服务类，天然 `Sendable`。
final class MessageRepository: MessageRepositoryProtocol {

    // MARK: - Properties

    private let service: MessageServiceProtocol

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter service: 消息服务，默认 `MessageService()`
    init(service: MessageServiceProtocol = MessageService()) {
        self.service = service
    }

    // MARK: - Fetch

    /// 拉取消息列表
    ///
    /// - Parameter categoryId: 分类 ID（见 `MessageAPI.noticeCategoryId`）
    /// - Returns: 消息列表 Publisher
    func fetchMessages(categoryId: Int) -> AnyPublisher<[MessageModel], NetworkError> {
        service.fetchMessageList(categoryId: categoryId)
            .eraseToAnyPublisher()
    }
}

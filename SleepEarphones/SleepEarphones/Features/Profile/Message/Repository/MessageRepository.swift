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
protocol MessageRepositoryProtocol: Sendable {

    /// 拉取消息列表
    ///
    /// - Parameter categoryId: 分类 ID（见 `MessageAPI.noticeCategoryId`）
    /// - Returns: 消息列表 Publisher
    func fetchMessages(categoryId: Int) -> AnyPublisher<[MessageModel], NetworkError>
}

// MARK: - 仓库实现

/// 消息仓库实现
final class MessageRepository: MessageRepositoryProtocol, Sendable {

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

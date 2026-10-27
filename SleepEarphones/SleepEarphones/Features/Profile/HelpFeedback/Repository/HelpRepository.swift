//
//  HelpRepository.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import Foundation
import Combine

// MARK: - 仓库协议

/// 帮助仓库协议
///
/// ## 职责
/// - 委托 `HelpService` 发起网络请求
/// - 未来若有缓存 / 业务短路逻辑，在此实现
///
/// ## 调用方法
/// ```swift
/// // 1. 生产环境（推荐）
/// let repo = HelpRepository()
///
/// // 2. 单元测试（注入 Mock Service）
/// let repo = HelpRepository(service: MockHelpService())
///
/// // 3. 调用
/// repo.fetchFAQs(categoryId: HelpAPI.helpCenterCategoryId)
///     .sink(
///         receiveCompletion: { ... },
///         receiveValue: { items in ... }
///     )
///     .store(in: &cancellables)
/// ```
///
/// - Note: 当前是纯透传。保留此层是为了与其他模块（Device / Auth / Message）
///         保持**一致的分层结构**，未来扩展时有落点。
protocol HelpRepositoryProtocol: Sendable {

    /// 拉取帮助文章列表
    ///
    /// - Parameter categoryId: 分类 ID
    /// - Returns: 文章列表 Publisher
    func fetchFAQs(categoryId: Int) -> AnyPublisher<[HelpFAQItem], NetworkError>
}

// MARK: - 仓库实现

/// 帮助仓库实现
final class HelpRepository: HelpRepositoryProtocol {

    // MARK: - Properties

    private let service: HelpServiceProtocol

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter service: 帮助服务，默认 `HelpService()`
    init(service: HelpServiceProtocol = HelpService()) {
        self.service = service
    }

    // MARK: - Fetch

    /// 拉取帮助文章列表
    ///
    /// - Parameter categoryId: 分类 ID（见 `HelpAPI.helpCenterCategoryId`）
    /// - Returns: 文章列表 Publisher
    func fetchFAQs(categoryId: Int) -> AnyPublisher<[HelpFAQItem], NetworkError> {
        service.fetchHelpList(categoryId: categoryId)
            .eraseToAnyPublisher()
    }
}

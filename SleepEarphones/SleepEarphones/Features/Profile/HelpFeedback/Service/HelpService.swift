//
//  HelpService.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import Foundation
import Combine

// MARK: - 服务协议

protocol HelpServiceProtocol: Sendable {

    /// 拉取指定分类下的帮助文章列表
    ///
    /// - Parameter categoryId: 分类 ID（见 `HelpAPI.helpCenterCategoryId`）
    /// - Returns: 文章列表 Publisher
    func fetchHelpList(categoryId: Int) -> AnyPublisher<[HelpFAQItem], NetworkError>
}

// MARK: - 服务实现

/// 帮助服务实现
///
/// ## 依赖注入
/// `client` 通过协议注入，默认使用 `NetworkClient()`：
/// - 生产环境：`HelpService()` 使用默认 `NetworkClient`
/// - 单元测试：`HelpService(client: MockNetworkClient())`
///
/// - Note: 无状态服务类，天然 `Sendable`。
final class HelpService: HelpServiceProtocol {

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

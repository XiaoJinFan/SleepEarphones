//
//  AgreementService.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/16.
//

import Foundation
import Combine

// MARK: - 服务协议

/// 协议服务协议（面向 ViewModel / VC 的抽象）
///
/// ## 调用方法
/// ```swift
/// // 1. 生产环境（推荐）
/// let service = AgreementService.shared
///
/// // 2. 单元测试
/// let service = AgreementService(client: MockNetworkClient())
///
/// // 3. 拉取协议内容
/// service.fetchAgreement(columnId: 9)
///     .sink(
///         receiveCompletion: { completion in ... },
///         receiveValue: { content in ... }
///     )
///     .store(in: &cancellables)
/// ```
///
protocol AgreementServiceProtocol: Sendable {

    /// 拉取协议内容
    ///
    /// - Parameter columnId: 单页 KID；不传则返回后端默认协议
    /// - Returns: 协议内容 Publisher
    func fetchAgreement(columnId: Int?) -> AnyPublisher<AgreementContent, NetworkError>
}

// MARK: - 服务实现

/// 协议服务实现
final class AgreementService: AgreementServiceProtocol, Sendable {

    // MARK: - Singleton

    /// 共享实例
    static let shared = AgreementService()

    // MARK: - Properties

    private let client: NetworkClientProtocol

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter client: 网络客户端，默认 `NetworkClient()`
    ///
    init(client: NetworkClientProtocol = NetworkClient()) {
        self.client = client
    }

    // MARK: - Fetch

    /// 拉取协议内容
    ///
    /// - Parameter columnId: 单页 KID；不传则返回后端默认协议
    /// - Returns: 协议内容 Publisher
    ///
    func fetchAgreement(columnId: Int?) -> AnyPublisher<AgreementContent, NetworkError> {
        AppLog.agreement.debug(
            "拉取协议内容：columnId=\(columnId.map(String.init) ?? "nil", privacy: .public)"
        )

        return client.request(
            AgreementAPI.getColumn(columnId: columnId),
            as: AgreementContent.self
        )
        .eraseToAnyPublisher()
    }
}

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
/// ## 职责
/// - 只负责**网络请求**（调用 `NetworkClient`）
/// - 不做缓存 / 不做数据转换 / 不做 UI 逻辑
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
/// - Note: 遵循 `Sendable`：作为无状态服务类，可跨 actor 传递。
protocol AgreementServiceProtocol: Sendable {

    /// 拉取协议内容
    ///
    /// - Parameter columnId: 单页 KID；不传则返回后端默认协议
    /// - Returns: 协议内容 Publisher
    func fetchAgreement(columnId: Int?) -> AnyPublisher<AgreementContent, NetworkError>
}

// MARK: - 服务实现

/// 协议服务实现
///
/// ## 使用方式
/// - **生产环境**：使用 `AgreementService.shared`——所有 VC 共享同一个
///   `NetworkClient` 与 `URLSession`，避免重复创建
/// - **单元测试**：`AgreementService(client: MockNetworkClient())`——
///   注入 mock 替代真实网络
///
/// - Important: 生产代码**不应**直接 `AgreementService()`——
///              那样会绕过 `shared` 创建独立实例。
///
/// ## 日志
/// 使用 `AppLog.agreement` 记录请求参数。
///
/// - Note: 无状态服务类，天然 `Sendable`。
final class AgreementService: AgreementServiceProtocol {

    // MARK: - Singleton

    /// 共享实例
    ///
    /// - Note: 内部使用默认 `NetworkClient()`——
    ///         首次访问时惰性创建，全局仅此一个。
    static let shared = AgreementService()

    // MARK: - Properties

    private let client: NetworkClientProtocol

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter client: 网络客户端，默认 `NetworkClient()`
    ///
    /// - Note: 生产环境建议走 `AgreementService.shared`；
    ///         本 `init` 主要面向单元测试注入 mock。
    init(client: NetworkClientProtocol = NetworkClient()) {
        self.client = client
    }

    // MARK: - Fetch

    /// 拉取协议内容
    ///
    /// - Parameter columnId: 单页 KID；不传则返回后端默认协议
    /// - Returns: 协议内容 Publisher
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

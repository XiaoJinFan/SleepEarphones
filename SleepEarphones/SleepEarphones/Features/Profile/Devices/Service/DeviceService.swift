//
//  DeviceService.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/11.
//

import Foundation
import Combine

// MARK: - 服务协议

/// 设备网络服务协议
///
/// ## 职责
/// - 只负责**网络请求**（调用 `NetworkClient`）
/// - 不做业务短路 / 不做数据转换
///
/// ## 调用方法
/// ```swift
/// // 1. 生产环境
/// let service = DeviceService()
///
/// // 2. 单元测试（注入 Mock）
/// let service = DeviceService(client: MockNetworkClient())
///
/// // 3. 调用
/// service.fetchDeviceList(userId: "3910", page: 1, pageSize: 15)
///     .sink(
///         receiveCompletion: { ... },
///         receiveValue: { data in ... }
///     )
///     .store(in: &cancellables)
/// ```
///
/// ## 关于 `userId` 参数
/// - 本协议**要求 `userId` 非空**——由 `DeviceRepository` 的
///   `isValidUserId(_:)` 保证
/// - `DeviceRepository` 会在调用本协议**之前**短路"未登录"场景
///   （直接返回空列表，不进入本协议）——
///   因此本协议实现**不需要**再处理 `nil` userId
protocol DeviceServiceProtocol: Sendable {

    /// 拉取指定用户的设备列表
    ///
    /// - Parameters:
    ///   - userId: 用户 ID（**必须非空**，由 `DeviceRepository` 保证）
    ///   - page: 页码，从 1 开始
    ///   - pageSize: 每页条数
    /// - Returns: 设备列表数据（**网络模型**，由上层转换为领域模型）
    func fetchDeviceList(userId: String, page: Int, pageSize: Int) -> AnyPublisher<DeviceListData, NetworkError>

    /// 删除设备
    ///
    /// - Parameter aid: 设备 ID
    /// - Returns: 成功时返回 `Void`
    func deleteDevice(aid: String) -> AnyPublisher<Void, NetworkError>
}

// MARK: - 服务实现

/// 设备网络服务实现
final class DeviceService: DeviceServiceProtocol, Sendable {

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

    /// 拉取设备列表
    ///
    /// - Parameters:
    ///   - userId: 用户 ID（**必须非空**）
    ///   - page: 页码
    ///   - pageSize: 每页条数
    /// - Returns: 设备列表数据 Publisher
    func fetchDeviceList(userId: String, page: Int, pageSize: Int) -> AnyPublisher<DeviceListData, NetworkError> {
        AppLog.device.debug(
            "拉取设备列表：userId=\(userId, privacy: .private) page=\(page, privacy: .public) pageSize=\(pageSize, privacy: .public)"
        )

        return client.request(
            DeviceAPI.listByUser(
                userId: userId,
                page: page,
                pageSize: pageSize
            ),
            as: DeviceListData.self
        )
        .eraseToAnyPublisher()
    }

    // MARK: - Delete

    /// 删除设备
    ///
    /// - Parameter aid: 设备 ID（`DeviceModel.id`）
    /// - Returns: 成功时返回 `Void`
    func deleteDevice(aid: String) -> AnyPublisher<Void, NetworkError> {
        AppLog.device.debug("请求删除设备：aid=\(aid, privacy: .private)")

        return client.request(
            DeviceAPI.deleteDevice(aid: aid),
            as: EmptyResponse.self
        )
        .map { _ in () }
        .eraseToAnyPublisher()
    }
}

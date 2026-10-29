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
protocol DeviceServiceProtocol: Sendable {

    /// 拉取指定用户的设备列表
    ///
    /// - Parameters:
    ///   - userId: 用户 ID（**必须非空**，由 `DeviceRepository` 保证）
    ///   - page: 页码，从 1 开始
    ///   - pageSize: 每页条数
    /// - Returns: 设备列表数据
    func fetchDeviceList(userId: String, page: Int, pageSize: Int) -> AnyPublisher<DeviceListData, NetworkError>

    /// 删除设备
    ///
    /// - Parameter aid: 设备 ID
    /// - Returns: 成功时返回 `Void`
    func deleteDevice(aid: String) -> AnyPublisher<Void, NetworkError>
}

// MARK: - 服务实现

/// 设备网络服务实现
///
/// ## 依赖注入
/// `client` 通过协议注入，默认使用 `NetworkClient()`：
/// - 生产环境：直接 `DeviceService()` 使用默认 `NetworkClient`
/// - 单元测试：`DeviceService(client: MockNetworkClient())`
///
/// ## 日志
/// 使用 `AppLog.device` 记录请求参数。
/// - `userId` 用 `privacy: .private`（用户 ID 属于敏感信息）
/// - `page` / `pageSize` / `aid` 用 `privacy: .public` 或 `.private`（视是否敏感）
final class DeviceService: DeviceServiceProtocol {

    // MARK: - Properties

    private let client: NetworkClientProtocol

    // MARK: - Init

    /// 初始化
    /// - Parameter client: 网络客户端，默认 `NetworkClient()`
    init(client: NetworkClientProtocol = NetworkClient()) {
        self.client = client
    }

    // MARK: - Fetch

    func fetchDeviceList(userId: String, page: Int, pageSize: Int) -> AnyPublisher<DeviceListData, NetworkError> {
        AppLog.device.debug(
            "拉取设备列表：userId=\(userId, privacy: .private) page=\(page, privacy: .public) pageSize=\(pageSize, privacy: .public)"
        )

        return client.request(
            DeviceAPI.listByUser(userId: userId, page: page, pageSize: pageSize),
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

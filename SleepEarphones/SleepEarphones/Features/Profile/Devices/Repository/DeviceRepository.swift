//
//  DeviceRepository.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import Foundation
import Combine

// MARK: - 领域模型

/// 设备列表业务结果
struct DeviceListResult: Sendable {

    /// 设备总数
    let total: Int

    /// 设备列表
    let devices: [DeviceModel]

    /// 空结果（未登录 / 无设备场景使用）
    static let empty = DeviceListResult(total: 0, devices: [])
}

// MARK: - 仓库协议

/// 设备仓库协议
protocol DeviceRepositoryProtocol: Sendable {

    /// 拉取某个用户的设备列表
    ///
    /// - Parameters:
    ///   - userId: 用户 ID；传 `nil` 或无效值表示未登录，**直接返回空列表**
    ///   - page: 页码，从 1 开始
    ///   - pageSize: 每页条数
    /// - Returns: 设备列表业务结果
    func fetchDevices(userId: String?, page: Int, pageSize: Int) -> AnyPublisher<DeviceListResult, NetworkError>

    /// 删除设备
    ///
    /// - Parameter aid: 设备 ID
    /// - Returns: 成功时返回 `Void`
    func deleteDevice(aid: String) -> AnyPublisher<Void, NetworkError>
}

// MARK: - 仓库实现

/// 设备仓库实现
final class DeviceRepository: DeviceRepositoryProtocol, Sendable {

    // MARK: - Constants

    /// 后端约定的"未登录 userId"值
    private static let invalidUserId = "0"

    // MARK: - Properties

    private let service: DeviceServiceProtocol

    // MARK: - Init

    /// 初始化
    /// - Parameter service: 设备服务，默认 `DeviceService()`
    init(service: DeviceServiceProtocol = DeviceService()) {
        self.service = service
    }

    // MARK: - Fetch

    /// 拉取设备列表
    ///
    /// - Parameters:
    ///   - userId: 用户 ID；`nil` / 空串 / `"0"` 视为未登录
    ///   - page: 页码
    ///   - pageSize: 每页条数
    /// - Returns: 设备列表业务结果 Publisher
    func fetchDevices(userId: String?, page: Int, pageSize: Int) -> AnyPublisher<DeviceListResult, NetworkError> {

        // 未登录：短路返回空列表，避免把"全部设备"当成"我的设备"
        guard let userId, Self.isValidUserId(userId) else {
            AppLog.device.debug("未登录或 userId 无效，短路返回空设备列表")
            return Just(DeviceListResult.empty)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }

        // 已登录：正常请求 + 数据转换
        // ⚠️ 此处 `userId` 是非可选 `String`（由 `guard let` 绑定）
        return service.fetchDeviceList(
            userId: userId,
            page: page,
            pageSize: pageSize
        )
        .map { data in
            // 网络模型 → 领域模型
            DeviceListResult(
                total: data.total,
                devices: data.list
            )
        }
        .eraseToAnyPublisher()
    }

    /// 删除设备
    ///
    /// - Parameter aid: 设备 ID
    /// - Returns: 成功时返回 `Void`
    func deleteDevice(aid: String) -> AnyPublisher<Void, NetworkError> {
        service.deleteDevice(aid: aid)
    }

    // MARK: - Private Helpers

    /// 判断 userId 是否有效
    ///
    /// - Parameter userId: 用户 ID（已确保非 nil）
    /// - Returns: 是否为有效用户 ID
    private static func isValidUserId(_ userId: String) -> Bool {
        !userId.isEmpty && userId != invalidUserId
    }
}

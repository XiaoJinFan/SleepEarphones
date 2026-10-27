//
//  DeviceViewData.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/22.
//

import Foundation
import LinkcosBluetooth

// MARK: - 电池充电状态（UI 层枚举）
enum BatteryChargingState: Equatable, Sendable {

    /// 充电中
    case charging

    /// 未充电
    case notCharging

    /// 未知（设备未上报 / 数据尚未就绪）
    case unknown
}

// MARK: - 设备视图数据

struct DeviceViewData: Identifiable, Equatable, Sendable {

    // MARK: - 核心字段

    /// 设备唯一标识
    let id: String

    /// 设备名称
    let name: String

    // MARK: - 电量

    /// 左耳电量（0~100）
    let leftBattery: Int

    /// 右耳电量（0~100）
    let rightBattery: Int

    /// 充电盒电量（0~100）
    let boxBattery: Int

    // MARK: - 充电状态

    /// 左耳充电状态
    let leftCharging: BatteryChargingState

    /// 右耳充电状态
    let rightCharging: BatteryChargingState

    /// 充电盒充电状态
    let boxCharging: BatteryChargingState

    // MARK: - 连接 / SDK 状态

    /// 是否已连接
    let isConnected: Bool

    /// 是否正在 SDK 弹窗中
    let isPopping: Bool

    // MARK: - Init

    /// 从 SDK 设备对象构造
    init(device: LCBleDevice, isConnected: Bool) {
        self.id = Self.stableID(for: device)
        self.name = device.name.isEmpty ? "未知设备" : device.name
        self.leftBattery = device.leftBattery
        self.rightBattery = device.rightBattery
        self.boxBattery = device.boxBattery
        self.leftCharging = Self.mapChargingStatus(device.leftChargingStatus)
        self.rightCharging = Self.mapChargingStatus(device.rightChargingStatus)
        self.boxCharging = Self.mapChargingStatus(device.boxEarbudChargingStatus)
        self.isConnected = isConnected
        self.isPopping = device.isPoping
    }

    // MARK: - 展示辅助

    /// 是否有任意一方的电量数据
    ///
    /// - Returns: 任一侧电量 ≥ 0 时为 `true`
    var hasBatteryData: Bool {
        leftBattery >= 0 || rightBattery >= 0 || boxBattery >= 0
    }

    /// 是否有有效名称（非兜底值）
    ///
    /// - Returns: 名称非空且不为兜底值时 `true`
    var hasName: Bool {
        !name.isEmpty && name != "未知设备"
    }

    // MARK: - Private Helpers

    /// 生成稳定的设备 ID
    private static func stableID(for device: LCBleDevice) -> String {
        if !device.uuidStr.isEmpty {
            return device.uuidStr
        }
        if !device.leftMacString.isEmpty {
            return "\(device.name)_\(device.leftMacString)"
        }
        return device.name
    }

    /// SDK 充电状态 → UI 层充电状态
    private static func mapChargingStatus(_ status: ChargingStatus) -> BatteryChargingState {
        switch status.rawValue {
        case 1:  return .charging
        case 0:  return .notCharging
        default: return .unknown
        }
    }
}

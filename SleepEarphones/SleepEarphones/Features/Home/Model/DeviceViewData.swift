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

/// 设备视图数据（UI 层）
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

    let leftCharging: BatteryChargingState
    let rightCharging: BatteryChargingState
    let boxCharging: BatteryChargingState

    // MARK: - 连接 / SDK 状态

    /// 是否已连接
    let isConnected: Bool

    /// 是否正在 SDK 弹窗中
    let isPopping: Bool

    // MARK: - Init

    /// 从 SDK 设备对象构造
    ///
    /// - Parameters:
    ///   - device: SDK 扫描返回的设备对象
    ///   - isConnected: 是否已连接（蓝牙通道是否建立）
    ///   - property: SDK 解析的实时属性快照；`nil` 时回退到 `device` 的初始值
    ///
    init(device: LCBleDevice, isConnected: Bool, property: LCBleDeviceProperty? = nil) {
        self.id = Self.stableID(for: device)
        self.name = device.name.isEmpty ? "未知设备" : device.name

        // MARK: 电量（优先实时值）
        self.leftBattery = Self.resolveBattery(
            realTime: property?.leftBattery,
            fallback: device.leftBattery
        )
        self.rightBattery = Self.resolveBattery(
            realTime: property?.rightBattery,
            fallback: device.rightBattery
        )

        // 充电盒电量特殊处理：0 时用缓存值
        let boxRealTime: Int? = {
            guard let property else { return nil }
            return property.boxBattery == 0 && property.boxCacheBattery > 0
                ? property.boxCacheBattery
                : property.boxBattery
        }()
        self.boxBattery = Self.resolveBattery(
            realTime: boxRealTime,
            fallback: device.boxBattery
        )

        // MARK: 充电状态（`LCBleDeviceProperty` 无对应字段，只能用 `LCBleDevice`）
        self.leftCharging = Self.mapChargingStatus(device.leftChargingStatus)
        self.rightCharging = Self.mapChargingStatus(device.rightChargingStatus)
        self.boxCharging = Self.mapChargingStatus(device.boxEarbudChargingStatus)

        self.isConnected = isConnected
        self.isPopping = device.isPoping
    }

    // MARK: - 展示辅助

    /// 是否有任意一方的电量数据
    var hasBatteryData: Bool {
        leftBattery >= 0 || rightBattery >= 0 || boxBattery >= 0
    }

    /// 是否有有效名称
    var hasName: Bool {
        !name.isEmpty && name != "未知设备"
    }

    // MARK: - Helpers

    /// 生成稳定的设备 ID
    static func stableID(for device: LCBleDevice) -> String {
        if !device.uuidStr.isEmpty {
            return device.uuidStr
        }
        if !device.leftMacString.isEmpty {
            return "\(device.name)_\(device.leftMacString)"
        }
        return device.name
    }

    /// 解析电量值：实时值有效（≥ 0）则用实时值，否则回退
    ///
    /// - Parameters:
    ///   - realTime: `LCBleDeviceProperty` 的实时电量；`nil` 表示尚未读取
    ///   - fallback: `LCBleDevice` 的扫描初始电量
    /// - Returns: 最终用于展示的电量
    private static func resolveBattery(realTime: Int?, fallback: Int) -> Int {
        // SDK 未读取到实时值时返回 -1——此时回退到扫描值
        guard let realTime, realTime >= 0 else {
            return fallback
        }
        return realTime
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

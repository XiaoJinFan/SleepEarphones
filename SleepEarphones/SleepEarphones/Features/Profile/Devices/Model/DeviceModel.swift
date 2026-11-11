import UIKit

public enum DeviceStatus: String, Codable, Sendable {
    case connected
    case disconnected
    case fault

    var title: String {
        switch self {
        case .connected:    return LN("已连接")
        case .disconnected: return LN("未连接")
        case .fault:        return LN("故障")
        }
    }

    var color: UIColor {
        switch self {
        case .connected:    return AppColor.Semantic.success
        case .disconnected: return AppColor.Text.tertiary
        case .fault:        return AppColor.Semantic.error
        }
    }
}

/// 单个设备
struct DeviceModel: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let status: DeviceStatus
    let imageURL: String?
    let mac: String
    let serialNumber: String
    let batteryLevel: String
    let leftBattery: String
    let rightBattery: String
    let hasSleepReport: Bool
    let nickname: String
    let lastConnectionTime: String

    // 提供给 BLE 连接成功时生成新记录
    init(id: String = UUID().uuidString,
         name: String,
         status: DeviceStatus = .connected,
         imageURL: String? = nil,
         mac: String,
         serialNumber: String,
         batteryLevel: String = "--",
         leftBattery: String = "--",
         rightBattery: String = "--",
         hasSleepReport: Bool = false,
         nickname: String = "",
         lastConnectionTime: String = "") {
        self.id = id
        self.name = name
        self.status = status
        self.imageURL = imageURL
        self.mac = mac
        self.serialNumber = serialNumber
        self.batteryLevel = batteryLevel
        self.leftBattery = leftBattery
        self.rightBattery = rightBattery
        self.hasSleepReport = hasSleepReport
        self.nickname = nickname
        self.lastConnectionTime = lastConnectionTime
    }

    var subtitle: String {
        guard !lastConnectionTime.isEmpty else { return LN("暂无连接记录") }
        return LN("最后连接 ") + lastConnectionTime
    }

    var isConnected: Bool { status == .connected }
    
    static func == (lhs: DeviceModel, rhs: DeviceModel) -> Bool {
        lhs.serialNumber == rhs.serialNumber
    }
}

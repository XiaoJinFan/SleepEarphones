//
//  DeviceModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/11.
//

import UIKit

// MARK: - 设备连接状态

enum DeviceStatus: Sendable, CaseIterable {

    /// 已连接
    case connected

    /// 未连接
    case disconnected

    /// 故障
    case fault

    /// 状态标题（UI 展示）
    var title: String {
        switch self {
        case .connected:    return "已连接"
        case .disconnected: return "未连接"
        case .fault:        return "故障"
        }
    }

    /// 状态颜色（走设计系统）
    ///
    /// - Note: 使用 `AppColor.Semantic` 而非硬编码 hex，
    ///         暗黑模式自动适配。
    var color: UIColor {
        switch self {
        case .connected:    return AppColor.Semantic.success
        case .disconnected: return AppColor.Text.tertiary
        case .fault:        return AppColor.Semantic.error
        }
    }
}

extension DeviceStatus: Decodable {

    /// 兼容后端多种返回值：`Int` / `String`
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // 1) Int：1 = 已连接，2 = 故障，其他 = 未连接
        if let intValue = try? container.decode(Int.self) {
            switch intValue {
            case 1: self = .connected
            case 2: self = .fault
            default: self = .disconnected
            }
            return
        }

        // 2) String：支持多种写法（大小写不敏感）
        let stringValue = (try? container.decode(String.self))?.lowercased() ?? ""
        switch stringValue {
        case "1", "connected", "online":
            self = .connected
        case "2", "fault", "error", "broken":
            self = .fault
        default:
            self = .disconnected
        }
    }
}

// MARK: - 设备模型

/// 单个设备
///
/// ## 字段映射
/// | 本属性 | 后端字段 | 说明 |
/// |---|---|---|
/// | `id` | `aid` | 设备 ID |
/// | `name` | `equipment_name` | 设备名称 |
/// | `status` | `status` | 连接状态 |
/// | `imageURL` | `equipment_logo` | 已拼 CDN 前缀 |
/// | `mac` | `mac` | MAC 地址 |
/// | `serialNumber` | `serial_number` | 序列号 |
/// | `batteryLevel` | `quantity_of_electricity` | 电量 |
/// | `leftBattery` | `left_ear_volume` | 左耳电量 |
/// | `rightBattery` | `right_ear_volume` | 右耳电量 |
/// | `hasSleepReport` | `does_it_include_a_sleep_report` | 是否含睡眠报告 |
/// | `nickname` | `user_nickname` | 用户昵称 |
///
struct DeviceModel: Decodable, Identifiable, Sendable {

    // MARK: 核心字段

    /// 设备 ID（对应接口 `aid`）
    let id: String

    /// 设备名称（`equipment_name`）
    let name: String

    /// 连接状态（`status`）
    let status: DeviceStatus

    /// 设备 logo URL（`equipment_logo`，已拼好 CDN 前缀）
    let imageURL: String?

    // MARK: 设备标识

    /// MAC 地址
    let mac: String

    /// 序列号
    let serialNumber: String

    // MARK: 电量

    /// 电量（`quantity_of_electricity`）
    let batteryLevel: String

    /// 左耳电量（`left_ear_volume`）
    let leftBattery: String

    /// 右耳电量（`right_ear_volume`）
    let rightBattery: String

    // MARK: 其他

    /// 是否包含睡眠报告（`does_it_include_a_sleep_report`）
    let hasSleepReport: Bool

    /// 用户昵称（`user_nickname`）
    let nickname: String

    // MARK: - 展示辅助

    /// 副标题：优先 MAC，其次序列号
    var subtitle: String {
        if !mac.isEmpty { return "MAC \(mac)" }
        if !serialNumber.isEmpty { return "SN \(serialNumber)" }
        return ""
    }

    /// 是否已连接（便捷判断）
    var isConnected: Bool {
        status == .connected
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case aid
        case equipmentName  = "equipment_name"
        case status
        case equipmentLogo  = "equipment_logo"
        case mac
        case serialNumber   = "serial_number"
        case batteryLevel   = "quantity_of_electricity"
        case leftBattery    = "left_ear_volume"
        case rightBattery   = "right_ear_volume"
        case hasSleepReport = "does_it_include_a_sleep_report"
        case nickname       = "user_nickname"
    }

    // MARK: - 自定义解码

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // id —— 兼容 String / Int
        if let strID = try? c.decode(String.self, forKey: .aid) {
            self.id = strID
        } else if let intID = try? c.decode(Int.self, forKey: .aid) {
            self.id = String(intID)
        } else {
            self.id = ""
        }

        // 字符串字段 —— 逐个独立解码，缺失时用默认值
        self.name         = Self.string(from: c, forKey: .equipmentName, default: "未知设备")
        self.mac          = Self.string(from: c, forKey: .mac,           default: "")
        self.serialNumber = Self.string(from: c, forKey: .serialNumber,  default: "")
        self.batteryLevel = Self.string(from: c, forKey: .batteryLevel,  default: "")
        self.leftBattery  = Self.string(from: c, forKey: .leftBattery,   default: "")
        self.rightBattery = Self.string(from: c, forKey: .rightBattery,  default: "")
        self.nickname     = Self.string(from: c, forKey: .nickname,      default: "")

        // status —— 解码失败时默认未连接
        self.status = (try? c.decode(DeviceStatus.self, forKey: .status)) ?? .disconnected

        // hasSleepReport —— 兼容 String("1"/"0") / Bool / Int
        self.hasSleepReport = Self.bool(from: c, forKey: .hasSleepReport)

        // equipment_logo —— 拼 CDN 前缀
        let rawLogo = try? c.decodeIfPresent(String.self, forKey: .equipmentLogo)
        self.imageURL = APIConfiguration.imageURL(rawLogo)
    }

    // MARK: - 解码辅助

    /// 解码 `String`，缺失或空串时返回 `defaultValue`
    private static func string(
        from c: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys,
        default defaultValue: String
    ) -> String {
        if let value = try? c.decodeIfPresent(String.self, forKey: key),
           !value.isEmpty {
            return value
        }
        return defaultValue
    }

    /// 解码 `Bool`，兼容 `Bool` / `Int` / `String`
    private static func bool(from c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Bool {
        // Bool
        if let boolVal = try? c.decodeIfPresent(Bool.self, forKey: key) {
            return boolVal
        }
        // Int（0 / 1）
        if let intVal = try? c.decodeIfPresent(Int.self, forKey: key) {
            return intVal != 0
        }
        // String（"1" / "true" / "0" / "false"）
        if let strVal = try? c.decodeIfPresent(String.self, forKey: key) {
            let lower = strVal.lowercased()
            return lower == "1" || lower == "true"
        }
        return false
    }
}

// MARK: - Equatable

extension DeviceModel {

    /// 只比较 `id`：用于列表 diffing
    ///
    /// - Note: 设备名称、状态等可能实时变化（如电量更新），
    ///         但同一个 `id` 视为同一设备。
    ///         若需要比较全部字段，可自定义 `isContentEqual(to:)` 方法。
    static func == (lhs: DeviceModel, rhs: DeviceModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 列表数据

/// 设备列表响应数据
struct DeviceListData: Decodable, Sendable {

    /// 设备列表
    let list: [DeviceModel]

    /// 总数
    let total: Int

    /// 空数据（用于未登录场景）
    static let empty = DeviceListData(list: [], total: 0)

    /// 供上层手动构造
    init(list: [DeviceModel], total: Int) {
        self.list = list
        self.total = total
    }

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        // 列表字段（按优先级：越靠前越新）
        case list, rows, data, records, items
        // 数量字段（按优先级）
        case count, total
    }

    // MARK: - 自定义解码

    init(from decoder: Decoder) throws {
        // 场景 1：`data` 本身就是数组
        if let array = try? [DeviceModel](from: decoder) {
            self.list = array
            self.total = array.count
            return
        }

        // 场景 2：`data` 是分页对象
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let items = Self.findList(in: c)
        self.list = items
        self.total = Self.findTotal(in: c, fallback: items.count)
    }

    // MARK: - Private Helpers

    /// 依次尝试各种列表字段名
    ///
    /// - Note:
    ///   - `try? decodeIfPresent` 在 Swift 5+ 已展平，一次 `if let` 即可拿到值
    ///   - 顺序反映后端字段演进历史，优先匹配新字段
    private static func findList(
        in c: KeyedDecodingContainer<CodingKeys>
    ) -> [DeviceModel] {
        if let v = try? c.decodeIfPresent([DeviceModel].self, forKey: .list)    { return v }
        if let v = try? c.decodeIfPresent([DeviceModel].self, forKey: .rows)    { return v }
        if let v = try? c.decodeIfPresent([DeviceModel].self, forKey: .data)    { return v }
        if let v = try? c.decodeIfPresent([DeviceModel].self, forKey: .records) { return v }
        if let v = try? c.decodeIfPresent([DeviceModel].self, forKey: .items)   { return v }
        return []
    }

    /// 依次尝试 `count` / `total`，缺失时用列表长度兜底
    ///
    /// - Note: `count` 在真实响应里更常见，因此优先匹配。
    ///         若两个都缺失 / 为 0，则用列表实际长度 `fallback`。
    private static func findTotal(
        in c: KeyedDecodingContainer<CodingKeys>,
        fallback: Int
    ) -> Int {
        if let v = try? c.decodeIfPresent(Int.self, forKey: .count), v > 0 { return v }
        if let v = try? c.decodeIfPresent(Int.self, forKey: .total), v > 0 { return v }
        return fallback
    }
}

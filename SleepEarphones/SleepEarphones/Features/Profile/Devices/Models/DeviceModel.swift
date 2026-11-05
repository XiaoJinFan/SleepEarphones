//
//  DeviceModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/11.
//

import UIKit

// MARK: - 设备连接状态

/// 设备连接状态
///
/// ## 关于国际化
enum DeviceStatus: Sendable, CaseIterable {

    /// 已连接
    case connected

    /// 未连接
    case disconnected

    /// 故障
    case fault

    /// 状态标题（UI 展示，**已本地化**）
    var title: String {
        switch self {
        case .connected:    return LN("已连接")
        case .disconnected: return LN("未连接")
        case .fault:        return LN("故障")
        }
    }

    /// 状态颜色（走设计系统）
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
    ///
    /// ## 解码规则
    /// - `Int`：`1` = 已连接，`2` = 故障，其他 = 未连接
    /// - `String`：大小写不敏感匹配 `"1"` / `"connected"` / `"online"` 等
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
/// | `name` | `equipment_name` | 设备名称（**后端已本地化**） |
/// | `status` | `status` | 连接状态 |
/// | `imageURL` | `equipment_logo` | 已拼 CDN 前缀 |
/// | `mac` | `mac` | MAC 地址 |
/// | `serialNumber` | `serial_number` | 序列号 |
/// | `batteryLevel` | `quantity_of_electricity` | 电量 |
/// | `leftBattery` | `left_ear_volume` | 左耳电量 |
/// | `rightBattery` | `right_ear_volume` | 右耳电量 |
/// | `hasSleepReport` | `does_it_include_a_sleep_report` | 是否含睡眠报告 |
/// | `nickname` | `user_nickname` | 用户昵称 |
/// | `lastConnectionTime` | `last_connection_time` | 上一次连接时间 |
struct DeviceModel: Decodable, Identifiable, Sendable {

    // MARK: Constants

    /// 时间字符串长度（`"YYYY-MM-DD HH:mm"` = 16 字符）
    private enum Constants {
        static let minuteTimestampLength = 16
    }

    // MARK: 核心字段

    /// 设备 ID（对应接口 `aid`）
    let id: String

    /// 设备名称（`equipment_name`，**后端已本地化**）
    let name: String

    /// 连接状态（`status`）
    let status: DeviceStatus

    /// 设备 logo URL（`equipment_logo`，已拼好 CDN 前缀）
    let imageURL: String?

    // MARK: 设备标识

    /// MAC 地址（**字符标识，不翻译**）
    let mac: String

    /// 序列号（**字符标识，不翻译**）
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

    /// 用户昵称（`user_nickname`，**用户输入 / 不翻译**）
    let nickname: String

    /// 上一次连接时间（`last_connection_time`）
    let lastConnectionTime: String

    // MARK: - 展示辅助

    /// 副标题：展示"最后连接时间"
    var subtitle: String {
        guard !lastConnectionTime.isEmpty else {
            return LN("暂无连接记录")
        }

        // 后端返回的可能是 "2026-10-30 15:29:10"（带秒）
        // 设计稿要求 "2025-04-12 12:14"（不带秒）
        // 这里做一个安全的截取处理
        var displayTime = lastConnectionTime
        if displayTime.count >= Constants.minuteTimestampLength {
            // 截取到分钟
            let endIndex = displayTime.index(
                displayTime.startIndex,
                offsetBy: Constants.minuteTimestampLength
            )
            displayTime = String(displayTime[..<endIndex])
        }

        return LN("最后连接 ")+displayTime
    }

    /// 是否已连接（便捷判断）
    var isConnected: Bool {
        status == .connected
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case aid
        case equipmentName      = "equipment_name"
        case status
        case equipmentLogo      = "equipment_logo"
        case mac
        case serialNumber       = "serial_number"
        case batteryLevel       = "quantity_of_electricity"
        case leftBattery        = "left_ear_volume"
        case rightBattery       = "right_ear_volume"
        case hasSleepReport     = "does_it_include_a_sleep_report"
        case nickname           = "user_nickname"
        case lastConnectionTime = "last_connection_time"
    }

    // MARK: - 自定义解码

    /// 显式解码，容错处理
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
        self.name               = Self.string(
            from: c, forKey: .equipmentName, default: LN("未知设备")
        )
        self.mac                = Self.string(from: c, forKey: .mac,                default: "")
        self.serialNumber       = Self.string(from: c, forKey: .serialNumber,       default: "")
        self.batteryLevel       = Self.string(from: c, forKey: .batteryLevel,       default: "")
        self.leftBattery        = Self.string(from: c, forKey: .leftBattery,        default: "")
        self.rightBattery       = Self.string(from: c, forKey: .rightBattery,       default: "")
        self.nickname           = Self.string(from: c, forKey: .nickname,           default: "")
        self.lastConnectionTime = Self.string(from: c, forKey: .lastConnectionTime, default: "")

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
    ///
    /// - Parameters:
    ///   - c: 解码容器
    ///   - key: 字段键
    ///   - defaultValue: 缺失 / 空串时的默认值
    ///                   ——**若默认值会被展示给用户，调用方需传入 `LN(...)`
    ///                   已本地化的字符串**；若默认值是 `""`（不展示），直接传字面量
    /// - Returns: 解码结果或默认值
    private static func string(from c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys, default defaultValue: String) -> String {
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

    /// 容错解码
    ///
    /// ## 两种形态
    /// 1. `data` 本身就是数组 → 直接用 `[DeviceModel]` 解码
    /// 2. `data` 是分页对象 → 在多种列表字段名中依次尝试
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
    private static func findList(in c: KeyedDecodingContainer<CodingKeys>) -> [DeviceModel] {
        if let v = try? c.decodeIfPresent([DeviceModel].self, forKey: .list)    { return v }
        if let v = try? c.decodeIfPresent([DeviceModel].self, forKey: .rows)    { return v }
        if let v = try? c.decodeIfPresent([DeviceModel].self, forKey: .data)    { return v }
        if let v = try? c.decodeIfPresent([DeviceModel].self, forKey: .records) { return v }
        if let v = try? c.decodeIfPresent([DeviceModel].self, forKey: .items)   { return v }
        return []
    }

    /// 依次尝试 `count` / `total`，缺失时用列表长度兜底
    private static func findTotal(in c: KeyedDecodingContainer<CodingKeys>, fallback: Int) -> Int {
        if let v = try? c.decodeIfPresent(Int.self, forKey: .count), v > 0 { return v }
        if let v = try? c.decodeIfPresent(Int.self, forKey: .total), v > 0 { return v }
        return fallback
    }
}

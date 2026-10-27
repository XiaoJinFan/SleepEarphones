//
//  DeviceInfo.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import Foundation
import UIKit

/// 设备信息工具
///
/// ## 调用方法
/// ```swift
/// // 1. 设备标识（用于接口 client_id 字段）
/// let clientId = DeviceInfo.idfv
///
/// // 2. 系统信息
/// let source = DeviceInfo.osName         // "IOS"
/// let version = DeviceInfo.systemVersion // "17.0"
/// let model = DeviceInfo.modelIdentifier // "iPhone15,2"
///
/// // 3. App 信息
/// let version = DeviceInfo.appVersion    // "1.0.0"
/// let build = DeviceInfo.buildNumber     // "100"
///
/// // 4. 调试环境判断
/// if DeviceInfo.isSimulator { ... }
/// ```
/// 
enum DeviceInfo {

    // MARK: - Constants

    /// 操作系统标识（用于接口 `user_source` 字段）
    ///
    static let osName = "IOS"

    // MARK: - Vendor Identifier

    /// IDFV（Identifier For Vendor）
    ///
    /// ## 特性
    /// - 同一 Vendor（同一开发者）的所有 App 共享同一个 IDFV
    /// - 用户卸载**该 Vendor 的所有 App** 后才会重置
    /// - 从 App Store / TestFlight / 企业签名安装时，IDFV 稳定
    ///
    /// ## 用途
    /// - 作为接口 `client_id` 字段（部分后端用它做设备维度识别）
    /// - 作为埋点 / 日志的设备维度唯一标识
    ///
    static let idfv: String? = {
        UIDevice.current.identifierForVendor?.uuidString
    }()

    // MARK: - System Info

    /// 系统版本号（如 `"17.0"`）
    static var systemVersion: String {
        UIDevice.current.systemVersion
    }

    /// 系统名称（如 `"iOS"` / `"iPadOS"`）
    ///
    /// - Note: 与 `osName` 区分：
    ///   - `osName`：用于后端接口的**业务枚举值**（"IOS"）
    ///   - `systemName`：系统返回的**真实名称**（"iOS"）
    static var systemName: String {
        UIDevice.current.systemName
    }

    /// 设备类型（粗粒度，如 `"iPhone"` / `"iPad"`）
    ///
    /// - Warning: **不要用于精确识别机型**。`UIDevice.current.model` 在
    ///            iPhone 上恒为 `"iPhone"`，无法区分 iPhone 13 与 iPhone 15。
    ///            如需精确机型用 `modelIdentifier`。
    static var deviceModel: String {
        UIDevice.current.model
    }

    /// 设备机型标识（如 `"iPhone15,2"`，对应 iPhone 14 Pro）
    ///
    /// ## 用途
    /// - 埋点分析设备分布
    /// - 针对特定机型的 UI 适配（如刘海屏检测）
    ///
    static let modelIdentifier: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else {
                return identifier
            }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }()

    // MARK: - App Info

    /// App 版本号（如 `"1.0.0"`，对应 Info.plist 的 `CFBundleShortVersionString`）
    static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    /// App 构建号（如 `"100"`，对应 Info.plist 的 `CFBundleVersion`）
    static var buildNumber: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "0"
    }

    /// App Bundle ID（如 `"com.sleepearphones.app"`）
    static var bundleID: String {
        Bundle.main.bundleIdentifier ?? "unknown"
    }

    // MARK: - Locale

    /// 当前语言（如 `"zh-Hans-CN"`）
    ///
    /// - Note: 用户切换系统语言后会变化；若需固定语言，
    ///         用 `Locale(identifier:)` 显式指定。
    static var language: String {
        Locale.current.identifier
    }

    /// 当前地区（如 `"CN"`）
    static var region: String {
        if #available(iOS 16.0, *) {
            return Locale.current.region?.identifier ?? "unknown"
        } else {
            return Locale.current.regionCode ?? "unknown"
        }
    }

    // MARK: - Debug

    /// 是否运行在模拟器
    ///
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}

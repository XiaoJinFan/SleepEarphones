//
//  AppLog.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import OSLog
@_exported import os

/// 全局日志工厂
///
/// ## 调用方法
/// ```swift
/// // 1. 按模块调用
/// AppLog.network.debug("请求 URL: \(url, privacy: .public)")
/// AppLog.auth.error("登录失败：\(msg, privacy: .public)")
/// AppLog.ui.warning("布局异常")
///
/// // 2. Debug 快速打印（仅 DEBUG 生效）
/// AppLog.trace("用户点击了登录按钮")
/// // 输出：📎 [LoginViewController.swift:88] loginButtonTapped(_:) → 用户点击了登录按钮
/// ```
///
/// ## 隐私级别（重要）
/// - `privacy: .public`：明文输出（适用于 URL、类型名等非敏感信息）
/// - `privacy: .private`：<private> 脱敏（适用于用户 ID、昵称、手机号）
/// - `privacy: .sensitive`：<private> 且不可在系统诊断中查看
/// 
enum AppLog {

    // MARK: - Subsystem

    /// 统一 subsystem（与 Bundle ID 一致，便于 Console.app 过滤）
    ///
    /// - Note: 修改此处即可全站生效，不再散落在各文件的 `Logger(subsystem:)` 中。
    private static let subsystem = "com.sleepearphones.app"

    // MARK: - App

    /// 应用生命周期（AppDelegate / SceneDelegate / AppRouter）
    static let app = Logger(subsystem: subsystem, category: "App")

    // MARK: - Core

    /// 网络层（NetworkClient / API 请求）
    static let network = Logger(subsystem: subsystem, category: "Network")

    /// 缓存管理（CacheManager）
    static let cache = Logger(subsystem: subsystem, category: "Cache")

    /// 本地存储（AuthStore / UserProfileRepository）
    static let storage = Logger(subsystem: subsystem, category: "Storage")

    /// 通用 UI 组件（WebViewController / EmptyStateView / 弹窗）
    static let ui = Logger(subsystem: subsystem, category: "UI")

    // MARK: - Features

    /// 认证（登录 / 注册 / 找回密码）
    static let auth = Logger(subsystem: subsystem, category: "Auth")

    /// 协议（隐私政策 / 用户协议）
    static let agreement = Logger(subsystem: subsystem, category: "Agreement")

    /// 设备
    static let device = Logger(subsystem: subsystem, category: "Device")

    /// 用户资料
    static let profile = Logger(subsystem: subsystem, category: "Profile")
}

// MARK: - Debug 辅助

#if DEBUG
extension AppLog {

    /// 仅 Debug 生效的快速日志
    ///
    /// - Parameters:
    ///   - message: 日志内容（自动闭包，Release 下不求值）
    ///   - file: 文件名（自动填充）
    ///   - function: 方法名（自动填充）
    ///   - line: 行号（自动填充）
    ///
    static func trace(_ message: @autoclosure () -> String, file: String = #fileID, function: String = #function, line: Int = #line) {
        let fileName = file.split(separator: "/").last.map(String.init) ?? file
        print("📎 [\(fileName):\(line)] \(function) → \(message())")
    }
}
#endif

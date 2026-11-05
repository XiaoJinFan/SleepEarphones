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
/// // 2. 性能计时（常用场景，避免手写样板）
/// let elapsed = await AppLog.measure("音乐加载") {
///     await loadMusic()
/// }
///
/// // 3. Debug 快速打印（仅 DEBUG 生效）
/// AppLog.trace("用户点击了登录按钮")
/// // 输出：📎 [LoginViewController.swift:88] loginButtonTapped(_:) → 用户点击了登录按钮
/// ```
///
/// ## 隐私级别（重要）
/// | 级别 | 输出 | 适用场景 |
/// |---|---|---|
/// | `privacy: .public` | 明文 | URL、类型名、枚举值、非敏感 ID |
/// | `privacy: .private` | `<private>` 脱敏 | 用户 ID、昵称、手机号、地址 |
/// | `privacy: .sensitive` | `<private>` 且**系统诊断日志中不可见** | 密码、Token、身份证号 |
///
enum AppLog {

    // MARK: - Subsystem

    /// 统一 subsystem
    private static let subsystem: String = {
        Bundle.main.bundleIdentifier ?? "com.sleepearphones.app"
    }()

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

    /// 设备（BLE 扫描 / 连接 / 属性）
    static let device = Logger(subsystem: subsystem, category: "Device")

    /// 用户资料（我的 / 设置 / 帮助 / 消息）
    static let profile = Logger(subsystem: subsystem, category: "Profile")
}

// MARK: - 性能计时

extension AppLog {

    /// 测量闭包执行耗时并记录到日志
    ///
    /// ## 调用方法
    /// ```swift
    /// // 1. 同步闭包
    /// let elapsed = AppLog.measure("解析 JSON") {
    ///     try JSONDecoder().decode(Model.self, from: data)
    /// }
    /// // 日志输出：⏱ 解析 JSON 耗时 0.003s
    ///
    /// // 2. 异步闭包
    /// let elapsed = await AppLog.measure("加载音乐") {
    ///     await repository.fetchSongs()
    /// }
    ///
    /// // 3. 自定义 Logger（默认用 AppLog.app）
    /// AppLog.measure("登录请求", using: AppLog.auth) {
    ///     await service.login()
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - label: 操作名（用于日志标识）
    ///   - logger: 目标 Logger，默认 `AppLog.app`
    ///   - operation: 要测量的闭包
    /// - Returns: 闭包的返回值
    ///
    @discardableResult
    static func measure<T>(_ label: String, using logger: Logger = AppLog.app, operation: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            logger.debug(
                "⏱ \(label, privacy: .public) 耗时 \(elapsed, format: .fixed(precision: 3))s"
            )
        }
        return try operation()
    }

    /// 异步版本的耗时测量
    ///
    /// - Parameters:
    ///   - label: 操作名
    ///   - logger: 目标 Logger，默认 `AppLog.app`
    ///   - operation: 要测量的异步闭包
    /// - Returns: 闭包的返回值
    @discardableResult
    static func measure<T>(_ label: String, using logger: Logger = AppLog.app, operation: () async throws -> T) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            logger.debug(
                "⏱ \(label, privacy: .public) 耗时 \(elapsed, format: .fixed(precision: 3))s"
            )
        }
        return try await operation()
    }
}

// MARK: - Debug 辅助

#if DEBUG
extension AppLog {

    /// 仅 Debug 生效的快速日志
    ///
    /// ## 调用方法
    /// ```swift
    /// AppLog.trace("用户点击了登录按钮")
    /// // 输出：📎 [LoginViewController.swift:88] loginButtonTapped(_:) → 用户点击了登录按钮
    /// ```
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

//
//  ToastPresenter.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import UIKit
import Toast_Swift

/// Toast 统一展示器
///
/// ## 调用方法
/// ```swift
/// // 1. 全局样式配置（AppDelegate 启动时调用一次）
/// ToastPresenter.configureGlobalStyle()
///
/// // 2. 语义化（推荐）
/// ToastPresenter.success("保存成功")
/// ToastPresenter.error("网络连接失败")
/// ToastPresenter.warning("请检查输入")
/// ToastPresenter.info("已复制到剪贴板")
///
/// // 3. 自定义
/// ToastPresenter.show("自定义消息", duration: 2.0, position: .bottom)
///
/// // 4. 在指定容器内展示
/// ToastPresenter.show("消息", in: someView)
///
/// // 5. 立即隐藏
/// ToastPresenter.hide()
/// ```
@MainActor
enum ToastPresenter {

    // MARK: - Configuration

    /// 配置全局 Toast 样式
    static func configureGlobalStyle() {
        var style = ToastStyle()
        style.backgroundColor = AppColor.Text.primary.withAlphaComponent(0.9)
        style.messageColor = .white
        style.messageFont = AppFont.Body.secondary
        style.messageAlignment = .center
        style.cornerRadius = AppSpacing.Corner.medium
        style.verticalPadding = AppSpacing.sm
        style.horizontalPadding = AppSpacing.md

        ToastManager.shared.style = style
        // 多次 Toast 时直接覆盖，不排队（避免用户连续点击堆积一长串）
        ToastManager.shared.isQueueEnabled = false
    }

    // MARK: - Semantic API（语义化）

    /// 成功提示
    ///
    /// - Parameters:
    ///   - message: 提示文案
    ///   - duration: 停留时长，默认 1.2s
    static func success(_ message: String, duration: TimeInterval = 1.2) {
        show("✅ \(message)", duration: duration)
    }

    /// 错误提示
    ///
    /// - Parameters:
    ///   - message: 提示文案
    ///   - duration: 停留时长，默认 1.8s（错误停留更久便于阅读）
    static func error(_ message: String, duration: TimeInterval = 1.8) {
        show("⚠️ \(message)", duration: duration)
    }

    /// 警告提示
    ///
    /// - Parameters:
    ///   - message: 提示文案
    ///   - duration: 停留时长，默认 1.5s
    static func warning(_ message: String, duration: TimeInterval = 1.5) {
        show("⚡️ \(message)", duration: duration)
    }

    /// 信息提示
    ///
    /// - Parameters:
    ///   - message: 提示文案
    ///   - duration: 停留时长，默认 1.2s
    static func info(_ message: String, duration: TimeInterval = 1.2) {
        show("ℹ️ \(message)", duration: duration)
    }

    // MARK: - Generic API

    /// 展示 Toast（默认在 keyWindow 上）
    ///
    /// - Parameters:
    ///   - message: 提示文案
    ///   - duration: 停留时长，默认 1.2s
    ///   - position: 显示位置，默认居中
    static func show(_ message: String, duration: TimeInterval = 1.2, position: ToastPosition = .center) {
        guard let container = keyWindow else {
            AppLog.ui.error("Toast 无法展示：找不到 keyWindow")
            return
        }
        container.makeToast(message, duration: duration, position: position)
    }

    /// 展示 Toast（在指定的 View 上）
    ///
    /// - Parameters:
    ///   - message: 提示文案
    ///   - view: 目标容器视图；通常在 VC 内部用 `view`
    ///   - duration: 停留时长，默认 1.2s
    ///   - position: 显示位置，默认居中
    static func show(_ message: String, in view: UIView, duration: TimeInterval = 1.2, position: ToastPosition = .center) {
        view.makeToast(message, duration: duration, position: position)
    }

    /// 立即隐藏当前 Toast
    static func hide() {
        keyWindow?.hideToast()
    }

    // MARK: - Private Helpers

    /// 当前 keyWindow
    ///
    /// - Note: 使用 `connectedScenes` 遍历，兼容多场景（iPad 分屏）。
    ///         只返回 `foregroundActive` 场景的 window，
    ///         避免后台场景误接 Toast。
    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first { $0.isKeyWindow }
    }
}

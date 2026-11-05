//
//  SceneDelegate.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/5.
//

import UIKit

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    // MARK: - Properties
    
    var window: UIWindow?

    // MARK: - Scene Lifecycle
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else {
            AppLog.app.error("scene 无法转换为 UIWindowScene")
            return
        }

        // 1. 创建窗口
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        // 2. 交给 AppRouter 决定根控制器（已登录 → TabBar；未登录 → 登录页）
        AppRouter.shared.bind(window: window)
        AppRouter.shared.start()

        // 3. 展示
        window.makeKeyAndVisible()

        // 4. 冷启动若携带 URL / 用户活动，交给深链处理
        handleConnectionOptions(connectionOptions)
    }

    /// Scene 断开连接时调用
    ///
    /// - Parameter scene: 当前场景
    /// 
    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        AppLog.app.debug("sceneDidDisconnect")
    }

    /// Scene 从后台进入前台时调用
    ///
    /// - Parameter scene: 当前场景
    func sceneDidBecomeActive(_ scene: UIScene) {
        // 恢复在非活跃状态下暂停的任务
        AppLog.app.debug("sceneDidBecomeActive")
    }

    /// Scene 即将进入非活跃状态时调用
    ///
    /// - Parameter scene: 当前场景
    func sceneWillResignActive(_ scene: UIScene) {
        // 暂停任务，禁用定时器
        AppLog.app.debug("sceneWillResignActive")
    }

    /// Scene 进入后台时调用
    ///
    /// - Parameter scene: 当前场景
    func sceneDidEnterBackground(_ scene: UIScene) {
        // 保存数据，释放共享资源
        AppLog.app.debug("sceneDidEnterBackground")
    }

    /// Scene 即将从后台进入前台时调用
    ///
    /// - Parameter scene: 当前场景
    func sceneWillEnterForeground(_ scene: UIScene) {
        // 撤销进入后台时的更改
        AppLog.app.debug("sceneWillEnterForeground")
    }

    // MARK: - Deep Link（预留）

    /// 通过 URL Scheme / Universal Link 打开 App
    ///
    /// - Parameters:
    ///   - scene: 当前场景
    ///   - URLContexts: URL 上下文集合
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleDeepLink(.url(url))
    }

    /// 通过用户活动（Handoff / Universal Link）打开 App
    ///
    /// - Parameters:
    ///   - scene: 当前场景
    ///   - userActivity: 用户活动
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        handleDeepLink(.userActivity(userActivity))
    }

    // MARK: - Private

    /// 深链来源
    ///
    /// - Note: 统一 URL 与 `NSUserActivity` 的分发入口，
    ///         未来接入业务跳转时只需在 `handleDeepLink` 内扩展。
    private enum DeepLinkSource {
        case url(URL)
        case userActivity(NSUserActivity)

        /// 日志用的描述文本
        var logDescription: String {
            switch self {
            case .url(let url):
                return "URL: \(url.absoluteString)"
            case .userActivity(let activity):
                return "userActivity: \(activity.activityType)"
            }
        }
    }

    /// 处理冷启动时携带的连接选项
    ///
    /// - Parameter options: 冷启动连接选项
    ///
    private func handleConnectionOptions(_ options: UIScene.ConnectionOptions) {
        if let url = options.urlContexts.first?.url {
            AppLog.app.debug("冷启动 URL: \(url.absoluteString, privacy: .public)")
            handleDeepLink(.url(url))
        }
        if let activity = options.userActivities.first {
            AppLog.app.debug(
                "冷启动 userActivity: \(activity.activityType, privacy: .public)"
            )
            handleDeepLink(.userActivity(activity))
        }
    }

    /// 深链统一分发
    ///
    /// - Parameter source: 深链来源（URL 或 `NSUserActivity`）
    ///
    private func handleDeepLink(_ source: DeepLinkSource) {
        AppLog.app.debug(
            "收到深链：\(source.logDescription, privacy: .public)"
        )
        // TODO: 解析并分发给对应业务模块
    }
}

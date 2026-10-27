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
        //    注意：冷启动时系统不会触发 `scene(_:openURLContexts:)`，
        //         必须在此处手动读取 `connectionOptions`。
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
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        AppLog.app.debug("openURL: \(url.absoluteString, privacy: .public)")
        // TODO: 在此分发到各业务模块（如推送跳转、活动落地页）
    }

    /// 通过用户活动（Handoff / Universal Link）打开 App
    ///
    /// - Parameters:
    ///   - scene: 当前场景
    ///   - userActivity: 用户活动
    ///
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        AppLog.app.debug(
            "continue userActivity: \(userActivity.activityType, privacy: .public)"
        )
        // TODO: 在此处理 NSUserActivity 类型（如 NSUserActivityTypeBrowsingWeb）
    }

    // MARK: - Private

    /// 处理冷启动时携带的连接选项
    ///
    /// - Parameter options: 冷启动连接选项
    ///
    private func handleConnectionOptions(_ options: UIScene.ConnectionOptions) {
        if let url = options.urlContexts.first?.url {
            AppLog.app.debug("冷启动 URL: \(url.absoluteString, privacy: .public)")
            // TODO: 与 openURLContexts 走同一套路由
        }
        if let activity = options.userActivities.first {
            AppLog.app.debug(
                "冷启动 userActivity: \(activity.activityType, privacy: .public)"
            )
            // TODO: 与 continue userActivity 走同一套路由
        }
    }
}

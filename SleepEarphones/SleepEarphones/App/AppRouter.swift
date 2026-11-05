//
//  AppRouter.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import UIKit

/// 应用级路由中心
///
/// ## 调用方法
/// ```swift
/// // 1. SceneDelegate 启动时
/// AppRouter.shared.bind(window: window)
/// AppRouter.shared.start()
///
/// // 2. 登录成功后
/// AppRouter.shared.switchToMain(animated: true)
///
/// // 3. 退出登录时
/// AppRouter.shared.switchToLogin(animated: true)
///
/// // 4. 语言切换 / 主题切换等需要刷新整个 UI 时
/// AppRouter.shared.reloadRoot()
/// ```
///
/// - Important: 本类**只负责根控制器切换**，不负责深链 / 业务路由分发。
///   深链入口统一在 `SceneDelegate` 分发到各 Feature 的 Coordinator。
@MainActor
final class AppRouter {

    // MARK: - Singleton

    static let shared = AppRouter()
    private init() {}

    // MARK: - Storyboard 常量

    /// Storyboard 名称与 VC 标识符集中管理
    ///
    /// - Note: 新增 Storyboard 页面时，请在此处登记，
    ///         避免 `"Main"` 等字符串散落在各 VC 中（当前 `LoginViewController`
    ///         内部也持有 `StoryboardIDs`，未来可迁移到此处统一）。
    private enum Storyboard {
        /// 登录 Storyboard 文件名（无扩展名）
        static let loginName = "LoginViewController"
        /// `LoginViewController` 在 storyboard 内的 identifier
        static let loginID = "LoginViewController"
        /// 主 Storyboard 名称（初始 VC 必须是 `MainTabBarController`）
        static let mainName = "Main"
    }

    // MARK: - Properties

    /// 当前 App 的 key window（由 `SceneDelegate` 注入）
    private weak var window: UIWindow?

    // MARK: - Public

    /// 绑定 window
    ///
    /// - Parameter window: `SceneDelegate` 创建的 key window
    func bind(window: UIWindow) {
        self.window = window
    }

    /// 启动路由：根据登录态决定根控制器
    ///
    /// ## 分支逻辑
    /// - **无 token**：首次安装 / 卸载重装 / 用户登出 → 登录页
    /// - **有 token**：App 正常重启 → 主界面
    func start() {
        let loggedIn = AuthStore.shared.isLoggedIn
        AppLog.app.debug("启动路由 → \(loggedIn ? "主界面" : "登录页", privacy: .public)")

        if loggedIn {
            switchToMain(animated: false)
        } else {
            switchToLogin(animated: false)
        }
    }

    /// 切换到登录页
    ///
    /// - Parameter animated: 是否使用交叉淡入淡出过渡
    func switchToLogin(animated: Bool) {
        guard let window else {
            logMissingWindow(caller: #function)
            return
        }

        let sb = UIStoryboard(name: Storyboard.loginName, bundle: nil)
        guard let loginVC = sb.instantiateViewController(
            withIdentifier: Storyboard.loginID
        ) as? LoginViewController else {
            AppLog.app.error(
                "\(Storyboard.loginID, privacy: .public) 未配置 storyboardIdentifier 或类型不匹配"
            )
            assertionFailure(
                "LoginViewController storyboardIdentifier mismatch — check LoginViewController.storyboard"
            )
            return
        }

        let nav = UINavigationController(rootViewController: loginVC)
        nav.setNavigationBarHidden(true, animated: false)

        setRoot(nav, on: window, animated: animated)
    }

    /// 切换到主界面
    ///
    /// - Parameter animated: 是否使用交叉淡入淡出过渡
    func switchToMain(animated: Bool) {
        guard let window else {
            logMissingWindow(caller: #function)
            return
        }

        let sb = UIStoryboard(name: Storyboard.mainName, bundle: nil)
        guard let mainVC = sb.instantiateInitialViewController() as? MainTabBarController else {
            AppLog.app.error("Main.storyboard 的初始控制器必须是 MainTabBarController")
            assertionFailure(
                "Main.storyboard's initial controller must be MainTabBarController"
            )
            return
        }

        setRoot(mainVC, on: window, animated: animated)
    }

    /// 重建根控制器（用于语言切换、主题切换等需要刷新 UI 的场景）
    func reloadRoot() {
        guard let window else {
            logMissingWindow(caller: #function)
            return
        }

        // 1. 收起键盘
        window.endEditing(true)

        // 2. 一次性销毁所有 presented VC
        if let root = window.rootViewController,
           root.presentedViewController != nil {
            root.dismiss(animated: false)
        }

        // 3. 淡入淡出重建
        UIView.transition(
            with: window,
            duration: 0.3,
            options: [.transitionCrossDissolve, .allowAnimatedContent],
            animations: { [weak self] in
                self?.start()
            },
            completion: nil
        )
    }

    // MARK: - Private

    /// 替换根控制器
    ///
    /// - Parameters:
    ///   - vc: 新的根控制器
    ///   - window: 目标 window
    ///   - animated: 是否使用过渡动画
    private func setRoot(_ vc: UIViewController, on window: UIWindow, animated: Bool) {
        guard animated else {
            window.rootViewController = vc
            window.layoutIfNeeded()
            return
        }

        UIView.transition(
            with: window,
            duration: 0.3,
            options: [.transitionCrossDissolve, .allowAnimatedContent],
            animations: {
                window.rootViewController = vc
                window.layoutIfNeeded()
            },
            completion: nil
        )
    }

    /// 未绑定 window 时的统一日志 + 断言
    private func logMissingWindow(caller: String) {
        AppLog.app.error(
            "\(caller, privacy: .public) 未绑定 window，请先在 SceneDelegate 调用 bind(window:)"
        )
        assertionFailure(
            "AppRouter.window is nil — call bind(window:) from SceneDelegate before any navigation"
        )
    }
}

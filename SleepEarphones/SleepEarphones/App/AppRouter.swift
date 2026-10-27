//
//  AppRouter.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import UIKit

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
@MainActor
final class AppRouter {

    // MARK: - Singleton

    static let shared = AppRouter()
    private init() {}

    // MARK: - Constants

    /// Storyboard 名称与 VC 标识符集中管理
    private enum Storyboard {
        /// 登录 Storyboard 文件名（无扩展名）
        static let loginName = "LoginViewController"
        /// LoginViewController 在 storyboard 内的 storyboardIdentifier
        static let loginID = "LoginViewController"
        /// 主 Storyboard 名称（初始 VC 必须是 MainTabBarController）
        static let mainName = "Main"
    }

    // MARK: - Properties

    /// 当前 App 的 key window（由 `SceneDelegate` 注入）
    private weak var window: UIWindow?

    // MARK: - Public

    /// 绑定 window
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
            assertionFailure("LoginViewController 未配置 storyboardIdentifier")
            return
        }

        // 用 NavigationController 包裹，确保登录页可以 push 到注册 / 找回密码
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
            assertionFailure("Main.storyboard 的初始控制器必须是 MainTabBarController")
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

        // 2. 销毁所有 presented VC
        if let root = window.rootViewController {
            var topPresented: UIViewController? = root.presentedViewController
            while let current = topPresented {
                current.dismiss(animated: false)
                topPresented = current.presentedViewController
            }
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
    
    private func logMissingWindow(caller: String) {
        AppLog.app.error(
            "AppRouter.\(caller, privacy: .public) 未绑定 window，请先在 SceneDelegate 调用 bind(window:)"
        )
        assertionFailure("AppRouter 未绑定 window")
    }
}

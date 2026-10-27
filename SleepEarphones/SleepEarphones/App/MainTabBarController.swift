//
//  MainTabBarController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/5.
//

import UIKit

@MainActor
final class MainTabBarController: UITabBarController {

    // MARK: - Tab 定义
    
    private enum Tab: CaseIterable {
        case home
        case sleep
        case music
        case mine

        /// Storyboard 中的 ViewController 标识符
        var storyboardID: String {
            switch self {
            case .home:  return "HomeViewController"
            case .sleep: return "SleepViewController"
            case .music: return "MusicViewController"
            case .mine:  return "MyViewController"
            }
        }

        /// Tab 标题
        var title: String {
            switch self {
            case .home:  return "首页"
            case .sleep: return "记录"
            case .music: return "音乐"
            case .mine:  return "我的"
            }
        }

        /// Tab 图标（默认态与选中态使用同一张图）
        ///
        /// - Note: 资源缺失时 `AppImage.image(named:)` 会输出日志并返回
        ///         1x1 透明图，避免崩溃。
        var image: UIImage {
            switch self {
            case .home:  return AppImage.Local.tabHome
            case .sleep: return AppImage.Local.tabSleep
            case .music: return AppImage.Local.tabMusic
            case .mine:  return AppImage.Local.tabMine
            }
        }
    }

    // MARK: - Storyboard

    /// 主 Storyboard 名称（与 `AppRouter` 保持一致）
    private static let storyboardName = "Main"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewControllers()
    }

    // MARK: - Setup

    /// 组装所有 Tab
    private func setupViewControllers() {
        let storyboard = UIStoryboard(name: Self.storyboardName, bundle: nil)

        viewControllers = Tab.allCases.map { tab in
            let vc = instantiate(from: storyboard, tab: tab)
            return makeNavigationController(root: vc, tab: tab)
        }

        selectedIndex = 0

        AppLog.app.debug("MainTabBarController 已装配 \(Tab.allCases.count) 个 Tab")
    }

    /// 从 Storyboard 实例化指定 Tab 的根控制器
    ///
    /// - Parameters:
    ///   - storyboard: 主 Storyboard
    ///   - tab: Tab 元信息
    /// - Returns: 实例化的 VC
    private func instantiate(from storyboard: UIStoryboard, tab: Tab) -> UIViewController {
        let vc = storyboard.instantiateViewController(withIdentifier: tab.storyboardID)
        AppLog.app.debug(
            "已实例化 \(tab.storyboardID, privacy: .public) (\(type(of: vc)))"
        )
        return vc
    }

    /// 为根控制器创建带 Tab 项的 `UINavigationController`
    ///
    /// - Parameters:
    ///   - root: Tab 的根控制器
    ///   - tab: Tab 元信息
    /// - Returns: 配置好 Tab 项的导航控制器
    private func makeNavigationController(root: UIViewController, tab: Tab) -> UINavigationController {
        let nav = UINavigationController(rootViewController: root)

        nav.tabBarItem = UITabBarItem(
            title: tab.title,
            image: tab.image,
            selectedImage: tab.image
        )

        return nav
    }
}

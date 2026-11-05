//
//  AppDelegate.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/5.
//

import UIKit
import Alamofire
import IQKeyboardManagerSwift

/// 应用入口
///
/// ## 启动初始化顺序（重要，不要随意调整）
/// 1. **语言**——必须最先应用，确保后续所有 `L()` 调用拿到正确文案
/// 2. **Toast 全局样式**——依赖 `AppColor` / `AppFont`，与语言无关，但应在首次 Toast 前配置
/// 3. **键盘管理**——纯 UI 工具，无时序依赖
/// 4. **网络监测**——纯后台逻辑，无时序依赖
/// 5. **HTML 模板预热**——提前生成 CSS，避免首次打开协议页卡顿
///
@main
@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: - Properties

    /// 网络可达性监听器
    private(set) var reachabilityManager: NetworkReachabilityManager?

    // MARK: - Application Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // 1. 语言（**必须先**，后续所有 L() 依赖它）
        LanguageManager.shared.applySavedLanguage()

        // 2. Toast 全局样式（首次展示 Toast 前必须配置）
        ToastPresenter.configureGlobalStyle()

        // 3. 键盘管理
        configureKeyboardManager()

        // 4. 网络监测
        configureReachability()

        // 5. HTML 模板预热（提前生成 CSS，避免协议页首次打开卡顿）
        AgreementHTMLTemplate.warmUp()

        return true
    }

    // MARK: - UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // 当前无场景级资源需要清理。
        //
        // - Note: 若未来引入"分屏 / 多窗口"支持，需在此释放被丢弃场景
        //         持有的资源（如独立的 AVPlayer 实例、独立的 BLE 连接）。
        //         iPhone 上系统不会触发本方法，仅在 iPad 多任务场景下可能调用。
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // 停止监听并释放：避免 App 退出后仍有回调触发
        reachabilityManager?.stopListening()
        reachabilityManager = nil
    }

    // MARK: - Setup

    /// 配置 IQKeyboardManager
    ///
    /// - 启用键盘自动避让（输入框不被键盘遮挡）
    /// - 点击空白处收起键盘
    private func configureKeyboardManager() {
        IQKeyboardManager.shared.isEnabled = true
        IQKeyboardManager.shared.resignOnTouchOutside = true
    }

    /// 配置网络可达性监听
    ///
    /// - Note: 当前仅在状态变化时输出日志，未做 UI 提示。
    ///         若未来需要在断网时显示横幅，可在此处扩展（如通过 Notification）。
    private func configureReachability() {
        reachabilityManager = NetworkReachabilityManager.default
        reachabilityManager?.startListening { status in
            let message: String
            switch status {
            case .unknown:
                message = "网络状态：未知"
            case .notReachable:
                message = "网络状态：无网络"
            case .reachable(.cellular):
                message = "网络状态：蜂窝数据"
            case .reachable(.ethernetOrWiFi):
                message = "网络状态：Wi-Fi"
            }
            AppLog.app.debug("\(message, privacy: .public)")
        }
    }
}

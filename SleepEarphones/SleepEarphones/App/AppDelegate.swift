//
//  AppDelegate.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/5.
//

import UIKit
import Alamofire
import IQKeyboardManagerSwift

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: - Properties
    var reachabilityManager: NetworkReachabilityManager?

    // MARK: - Application Lifecycle
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // ✅ 应用已保存的语言（必须在其他 UI 初始化之前调用）
        LanguageManager.shared.applySavedLanguage()

        // 键盘管理
        IQKeyboardManager.shared.isEnabled = true
        IQKeyboardManager.shared.resignOnTouchOutside = true

        // 网络监测
        configureReachability()

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
        // 清理被丢弃的场景特定资源（当前无资源需清理）
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        reachabilityManager?.stopListening()
        reachabilityManager = nil
    }

    // MARK: - Private

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

//
//  AuthStore.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/17.
//

import Foundation

/// 登录凭证 / 用户信息的本地存储
///
/// ## 存储分工
/// - **Token** → Keychain（敏感信息，需加密）
/// - **userId / nickname / avatar / mobile / email** → UserDefaults（非敏感，读写频繁）
///
/// ## 调用方法
/// ```swift
/// // 1. 查询登录态
/// if AuthStore.shared.isLoggedIn { ... }
/// let token = AuthStore.shared.token
/// let userId = AuthStore.shared.userId
///
/// // 2. 保存登录结果（由 AuthRepository 自动调用）
/// AuthStore.shared.save(loginResult)
///
/// // 3. 局部更新用户资料（由 UserProfileViewModel 调用）
/// AuthStore.shared.updateProfile(nickname: "新昵称", avatarURL: "https://...")
/// AuthStore.shared.updateRealAccount(realMobile: "183...", realEmail: nil)
///
/// // 4. 退出登录
/// AuthStore.shared.clear()
/// ```
///
final class AuthStore: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = AuthStore()

    // MARK: - Keys

    /// 当前 key（Keychain + UserDefaults）
    private enum Keys {
        static let token      = "auth.token"
        static let userId     = "auth.userId"
        static let nickname   = "auth.nickname"
        static let avatar     = "auth.avatar"
        static let loginType  = "auth.loginType"
        static let mobile     = "auth.mobile"
        static let email      = "auth.email"
        /// 真实手机号（未脱敏）
        static let realMobile = "auth.realMobile"
        /// 真实邮箱
        static let realEmail  = "auth.realEmail"
    }

    /// 旧 key（用于迁移）
    private enum LegacyKeys {
        static let token = "auth.token"
    }

    /// "是否已启动过"标记
    ///
    /// ## 为什么用 UserDefaults 存？
    /// - `UserDefaults` 卸载时**会**清除
    /// - `Keychain` 卸载时**不会**清除
    ///
    /// 两者差异正好可以检测"首次启动 / 卸载重装"。
    private static let hasLaunchedKey = "app.hasLaunchedBefore"

    // MARK: - Properties

    private let userDefaults: UserDefaults

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter userDefaults: 便于单元测试注入 `UserDefaults(suiteName:)`
    ///
    /// - Important: init 时先检测"首次启动"，**必须在读取任何 token 之前完成**。
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // ✅ 关键：init 时先检测"首次启动"，
        //    必须在读取任何 token 之前完成
        clearKeychainIfNewInstall()
    }

    // MARK: - First Launch Detection

    /// 检测"首次启动 / 卸载重装"，若是则清空 Keychain
    ///
    /// ## 卸载重装的完整时序
    /// ```
    /// 1. 用户安装 App
    ///    → UserDefaults 里无 hasLaunchedBefore
    ///    → 清空 Keychain（此时为空，无操作）
    ///    → 设置 hasLaunchedBefore = true
    /// 2. 用户登录
    ///    → token 存 Keychain
    ///    → userId / nickname / avatar 存 UserDefaults
    /// 3. 用户卸载 App
    ///    → UserDefaults 被系统清空
    ///    → Keychain 保留（token 还在）
    /// 4. 用户重新安装 App
    ///    → UserDefaults 里无 hasLaunchedBefore（被卸载清空了）
    ///    → 清空 Keychain（token 被清除）✅
    ///    → 设置 hasLaunchedBefore = true
    ///    → 进入登录页 ✅
    /// ```
    ///
    private func clearKeychainIfNewInstall() {
        let hasLaunchedBefore = userDefaults.bool(forKey: Self.hasLaunchedKey)

        guard !hasLaunchedBefore else { return }   // 非首次启动，不动 Keychain

        AppLog.storage.info("检测到首次启动（或卸载重装），清空 Keychain 残留")

        // 清空当前 App 的所有 Keychain 项
        KeychainStore.removeAll()

        // 清理可能残留的旧 UserDefaults key（保险起见）
        userDefaults.removeObject(forKey: LegacyKeys.token)

        // 标记已启动
        userDefaults.set(true, forKey: Self.hasLaunchedKey)
    }

    // MARK: - Read

    /// 当前 token（对应后端 `user_token`）
    ///
    /// - Returns: token 字符串；未登录时返回 `nil`
    ///
    /// - Note: 首次读取时会尝试从 `UserDefaults` 迁移旧 token
    ///         （兼容历史版本把 token 存 UserDefaults 的场景）。
    ///         迁移只发生一次（迁移后旧值被清空）。
    var token: String? {
        // 1. 优先从 Keychain 读
        if let keychainToken = KeychainStore.get(Keys.token),
           !keychainToken.isEmpty {
            return keychainToken
        }

        // 2. Keychain 无值：尝试迁移 UserDefaults 旧值
        if let legacyToken = userDefaults.string(forKey: LegacyKeys.token),
           !legacyToken.isEmpty {
            AppLog.storage.info("迁移 token：UserDefaults → Keychain")
            KeychainStore.set(legacyToken, forKey: Keys.token)
            userDefaults.removeObject(forKey: LegacyKeys.token)
            return legacyToken
        }

        // 3. 都没有：未登录
        return nil
    }

    /// 是否已登录
    ///
    /// - Returns: token 非空时为 `true`
    var isLoggedIn: Bool {
        guard let token, !token.isEmpty else { return false }
        return true
    }

    /// 当前用户 ID
    ///
    /// - Returns: 未登录时返回 `0`
    var userId: Int { userDefaults.integer(forKey: Keys.userId) }

    /// 租户 ID（来源：`APIConfiguration`，与登录结果无关）
    var memberId: String { APIConfiguration.memberId }

    /// 昵称（登录 / 注册时缓存）
    var nickname: String? { userDefaults.string(forKey: Keys.nickname) }

    /// 头像 URL（登录 / 注册时缓存）
    var avatar: String? { userDefaults.string(forKey: Keys.avatar) }

    /// 登录账号对应的手机号（脱敏，如 `"183****1021"`）
    var mobile: String? { userDefaults.string(forKey: Keys.mobile) }

    /// 登录账号对应的邮箱
    var email: String? { userDefaults.string(forKey: Keys.email) }

    /// 真实手机号（未脱敏，如 `"18384891021"`）
    ///
    /// - Note: 从 `user/get_user_info` 的 `_mobile` 字段获取。
    ///         **用于发送验证码**——脱敏号无法用于此目的。
    var realMobile: String? { userDefaults.string(forKey: Keys.realMobile) }

    /// 真实邮箱
    var realEmail: String? { userDefaults.string(forKey: Keys.realEmail) }

    /// 缓存的登录类型（用于"账号与安全"页决定菜单顺序）
    var cachedLoginType: LoginAccountMode {
        get {
            let raw = userDefaults.integer(forKey: Keys.loginType)
            return LoginAccountMode(rawValue: raw) ?? .phone
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Keys.loginType)
        }
    }

    // MARK: - Write

    /// 保存登录 / 注册结果
    ///
    /// - Parameter result: 登录 / 注册接口返回的 `LoginResult`
    ///
    /// - Note: 只写入后端实际返回的字段，缺失的字段**不覆盖**已有值。
    func save(_ result: LoginResult) {
        // Token 单独存 Keychain
        if let token = result.userToken, !token.isEmpty {
            KeychainStore.set(token, forKey: Keys.token)
        }

        // 非敏感字段存 UserDefaults
        if let userId = result.userId {
            userDefaults.set(userId, forKey: Keys.userId)
        }
        if let nickname = result.nickname, !nickname.isEmpty {
            userDefaults.set(nickname, forKey: Keys.nickname)
        }
        if let avatar = result.avatar, !avatar.isEmpty {
            userDefaults.set(avatar, forKey: Keys.avatar)
        }
        if let mobile = result.mobile, !mobile.isEmpty {
            userDefaults.set(mobile, forKey: Keys.mobile)
        }
        if let email = result.email, !email.isEmpty {
            userDefaults.set(email, forKey: Keys.email)
        }

        AppLog.storage.debug("已保存登录凭证 userId=\(result.userId ?? -1, privacy: .public)")
    }

    /// 清除登录状态
    ///
    /// - Note:
    ///   - Keychain 中的 token 通过 `remove` 删除（而非 `removeAll`，
    ///     避免误删其他模块将来可能存入 Keychain 的数据）
    ///   - UserDefaults 中的旧 token 也一并清理，避免残留
    ///
    /// - Important: **不**清空 `hasLaunchedKey`——
    ///              登出 ≠ 卸载重装，不应触发 Keychain 清空逻辑
    func clear() {
        KeychainStore.remove(Keys.token)
        userDefaults.removeObject(forKey: LegacyKeys.token)
        userDefaults.removeObject(forKey: Keys.userId)
        userDefaults.removeObject(forKey: Keys.nickname)
        userDefaults.removeObject(forKey: Keys.avatar)
        userDefaults.removeObject(forKey: Keys.loginType)
        userDefaults.removeObject(forKey: Keys.mobile)
        userDefaults.removeObject(forKey: Keys.email)
        userDefaults.removeObject(forKey: Keys.realMobile)
        userDefaults.removeObject(forKey: Keys.realEmail)

        AppLog.storage.debug("已清除登录凭证")
    }

    // MARK: - Update（局部更新，用于"修改资料"场景）

    /// 更新本地缓存的昵称 / 头像
    ///
    /// - Parameters:
    ///   - nickname: 新昵称；传 nil 表示不修改
    ///   - avatarURL: 新头像 URL；传 nil 表示不修改
    ///
    /// ## 使用场景
    /// 用户在"我的资料"页修改昵称 / 头像并**服务端保存成功后**，
    /// 需要同步更新 `AuthStore` 里的缓存——
    /// 否则换设备登录时会加载到旧的头像 URL。
    /// 
    func updateProfile(nickname: String?, avatarURL: String?) {
        if let nickname, !nickname.isEmpty {
            userDefaults.set(nickname, forKey: Keys.nickname)
        }
        if let avatarURL, !avatarURL.isEmpty {
            userDefaults.set(avatarURL, forKey: Keys.avatar)
        }
        AppLog.storage.debug("已更新本地缓存：nickname=\(nickname ?? "未改", privacy: .private)")
    }

    /// 更新真实手机号 / 邮箱
    ///
    /// - Parameters:
    ///   - realMobile: 真实手机号（未脱敏）
    ///   - realEmail: 真实邮箱
    ///
    /// ## 使用场景
    /// `UserProfileViewModel.refresh()` 从 `user/get_user_info` 拉到数据后，
    /// 把 `_mobile` / `email` 写入本地——
    /// **"账号与安全"页发送验证码时使用**。
    func updateRealAccount(realMobile: String?, realEmail: String?) {
        if let realMobile, !realMobile.isEmpty {
            userDefaults.set(realMobile, forKey: Keys.realMobile)
        }
        if let realEmail, !realEmail.isEmpty {
            userDefaults.set(realEmail, forKey: Keys.realEmail)
        }
        AppLog.storage.debug("已更新真实账号信息")
    }
}

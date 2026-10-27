//
//  KeychainStore.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import Foundation
import Security

/// Keychain 存储工具
///
/// 用于安全存储 token、密码等敏感信息。
///
/// ## 调用方法
/// ```swift
/// // 1. 保存（空字符串等同于删除）
/// KeychainStore.set("token_xxx", forKey: "auth.token")
///
/// // 2. 读取（不存在时返回 nil）
/// let token = KeychainStore.get("auth.token")
///
/// // 3. 删除单项
/// KeychainStore.remove("auth.token")
///
/// // 4. 清空所有项（仅用于登出 / 重置）
/// KeychainStore.removeAll()
/// ```
/// 
enum KeychainStore {

    // MARK: - Service

    /// Keychain 服务标识
    ///
    /// - Note:
    ///   - 同一个 App 内所有 key 共享此 service，通过不同 `account`（即 `key`）区分。
    ///   - 使用 Bundle ID 作为 service，避免与其他 App 冲突。
    private static let service = Bundle.main.bundleIdentifier ?? "com.sleepearphones.app"

    // MARK: - Public API

    /// 保存字符串到 Keychain（若已存在则覆盖）
    ///
    /// - Parameters:
    ///   - value: 待保存的字符串；空字符串等同于删除
    ///   - key: 存储键（对应 `kSecAttrAccount`）
    /// - Returns: 是否成功
    ///
    @discardableResult
    static func set(_ value: String, forKey key: String) -> Bool {
        // 空字符串视为删除，避免存储无意义数据
        guard !value.isEmpty else {
            remove(key)
            return true
        }
        guard let data = value.data(using: .utf8) else {
            AppLog.storage.error("Keychain 编码失败 key=\(key, privacy: .public)")
            return false
        }

        // 1. 删除旧值（不存在也不报错）
        let deleteQuery: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // 2. 添加新值
        let addQuery: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData   as String: data,
            // 设备首次解锁后可访问，且不参与 iCloud 同步与备份迁移
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)

        if status != errSecSuccess {
            AppLog.storage.error(
                "Keychain 写入失败 key=\(key, privacy: .public) status=\(status)"
            )
            return false
        }
        return true
    }

    /// 从 Keychain 读取字符串
    ///
    /// - Parameter key: 存储键
    /// - Returns: 读取到的字符串；不存在或解码失败时返回 `nil`
    ///
    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData  as String: true,
            kSecMatchLimit  as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    /// 从 Keychain 删除指定键
    ///
    /// - Parameter key: 存储键
    ///
    static func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)

        // errSecItemNotFound 是幂等场景，不算错误
        if status != errSecSuccess && status != errSecItemNotFound {
            AppLog.storage.error(
                "Keychain 删除失败 key=\(key, privacy: .public) status=\(status)"
            )
        }
    }

    /// 清空当前 App 的所有 Keychain 项
    ///
    /// - Warning: 会删除当前 `service` 下所有 key。
    ///            仅用于登出 / 重置 App / 测试场景。
    ///
    static func removeAll() {
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            AppLog.storage.error("Keychain 清空失败 status=\(status)")
        }
    }
}

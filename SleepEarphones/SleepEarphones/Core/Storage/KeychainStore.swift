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

        // 1. 定位条件（key 唯一标识一项）
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        // 2. 尝试更新
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )

        if updateStatus == errSecSuccess {
            return true
        }

        // 3. 不存在 → 添加
        if updateStatus == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass          as String: kSecClassGenericPassword,
                kSecAttrService    as String: service,
                kSecAttrAccount    as String: key,
                kSecValueData      as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

            if addStatus == errSecSuccess {
                return true
            }

            // 4. 极端场景：Add 报 duplicate（并发窗口内另一线程刚好插入）
            //    → 回退到 Update 重试一次
            if addStatus == errSecDuplicateItem {
                AppLog.storage.warning(
                    "Keychain 添加时发现已存在（并发窗口），回退为更新 key=\(key, privacy: .public)"
                )
                return SecItemUpdate(
                    query as CFDictionary,
                    attributes as CFDictionary
                ) == errSecSuccess
            }

            AppLog.storage.error(
                "Keychain 写入失败 key=\(key, privacy: .public) status=\(addStatus)"
            )
            return false
        }

        // 5. 其他错误
        AppLog.storage.error(
            "Keychain 更新失败 key=\(key, privacy: .public) status=\(updateStatus)"
        )
        return false
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
            // 未找到不算错误（正常的"未登录"场景）
            if status != errSecItemNotFound {
                AppLog.storage.error(
                    "Keychain 读取失败 key=\(key, privacy: .public) status=\(status)"
                )
            }
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

//
//  UserProfileRepository.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import UIKit

// MARK: - 仓库协议

/// 用户资料仓库协议
protocol UserProfileRepositoryProtocol: Sendable {

    /// 异步加载头像
    ///
    /// - Returns: 解码后的 `UIImage`；无数据或解码失败时返回 `nil`
    func loadAvatar() async -> UIImage?

    /// 同步读取昵称
    ///
    /// - Returns: 昵称；未设置时返回 `nil`
    func loadNickname() -> String?

    /// 保存头像与昵称（**覆盖式**）
    ///
    /// - Parameters:
    ///   - avatar: 新头像；传 nil 表示**清除**头像
    ///   - nickname: 新昵称
    func save(avatar: UIImage?, nickname: String)

    /// 仅更新头像（**不影响昵称**）
    ///
    /// - Parameter avatar: 新头像
    func updateAvatar(_ avatar: UIImage)

    /// 仅更新昵称（**不影响头像**）
    ///
    /// - Parameter nickname: 新昵称
    func updateNickname(_ nickname: String)
}

// MARK: - 实现

/// 用户资料仓库实现
final class UserProfileRepository: UserProfileRepositoryProtocol {

    // MARK: - Keys

    /// UserDefaults 存储键（**仅用于昵称**）
    private enum Keys {
        static let nickname = "userNicknameKey"
        /// ⚠️ 旧键——头像数据曾存这里，现已迁移到文件。
        ///    保留该常量仅用于**一次性迁移清理**。
        static let legacyAvatar = "userAvatarKey"
    }

    // MARK: - Constants

    /// 头像 JPEG 压缩质量
    ///
    /// - 0.8 是体积与画质的平衡点：视觉几乎无差异，体积约为原图的 1/5
    private let avatarCompressionQuality: CGFloat = 0.8

    // MARK: - Properties

    /// 用户偏好存储，添加nonisolated(unsafe) 是为了消除警告
    nonisolated(unsafe) private let userDefaults: UserDefaults

    /// 串行队列：用于「压缩 / 文件读写」等后台 IO
    private let ioQueue = DispatchQueue(
        label: "com.sleepearphones.profile.io",
        qos: .utility
    )

    /// 头像文件 URL（延迟计算，缓存）
    ///
    /// - Returns: `{Application Support}/SleepEarphones/avatar.jpg`
    private let avatarFileURL: URL

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter userDefaults: 便于单元测试注入 `UserDefaults(suiteName:)`
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // 计算头像文件路径
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let appDir = appSupport.appendingPathComponent(
            Bundle.main.bundleIdentifier ?? "SleepEarphones",
            isDirectory: true
        )

        // 创建目录（若不存在）
        try? FileManager.default.createDirectory(
            at: appDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        self.avatarFileURL = appDir.appendingPathComponent("avatar.jpg")
    }

    // MARK: - Load

    /// 异步加载头像
    func loadAvatar() async -> UIImage? {
        await withCheckedContinuation { continuation in
            ioQueue.async { [weak self] in
                guard let self else {
                    // self 已释放——仍需 resume，否则调用方的 await 永久悬挂
                    continuation.resume(returning: nil)
                    return
                }

                // 1. 迁移旧数据（在 ioQueue 上，不阻塞调用者）
                self.migrateLegacyAvatarIfNeeded()

                // 2. 读取文件
                guard let data = try? Data(contentsOf: self.avatarFileURL) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: UIImage(data: data))
            }
        }
    }

    /// 同步读取昵称
    ///
    /// - Returns: 昵称字符串；未设置时返回 `nil`
    func loadNickname() -> String? {
        userDefaults.string(forKey: Keys.nickname)
    }

    // MARK: - Save

    /// 保存头像与昵称（**覆盖式**）
    ///
    /// - Important: `avatar == nil` 会**清空**本地头像
    ///
    /// - Parameters:
    ///   - avatar: 新头像；传 nil 表示清除头像
    ///   - nickname: 新昵称
    func save(avatar: UIImage?, nickname: String) {
        // 昵称：复用 updateNickname
        updateNickname(nickname)

        // 头像：依"有无"分派到 updateAvatar / deleteAvatarFile
        if let avatar {
            updateAvatar(avatar)
        } else {
            deleteAvatarFile()
        }
    }

    /// 仅更新头像
    ///
    /// - Parameter avatar: 新头像
    func updateAvatar(_ avatar: UIImage) {
        writeAvatarFile(avatar)
    }

    /// 仅更新昵称
    ///
    /// - Parameter nickname: 新昵称
    func updateNickname(_ nickname: String) {
        userDefaults.set(nickname, forKey: Keys.nickname)
    }

    // MARK: - Private Helpers（文件操作）

    /// 后台写入头像文件
    ///
    /// - Parameter avatar: 待写入的头像
    private func writeAvatarFile(_ avatar: UIImage) {
        let quality = avatarCompressionQuality
        let url = avatarFileURL

        ioQueue.async {
            autoreleasepool {
                guard let data = avatar.jpegData(compressionQuality: quality) else {
                    AppLog.profile.error("头像 JPEG 压缩失败")
                    return
                }
                do {
                    try data.write(to: url, options: .atomic)
                    AppLog.profile.debug(
                        "头像已写入文件：size=\(data.count, privacy: .public) bytes"
                    )
                } catch {
                    AppLog.profile.error(
                        "头像写入文件失败：\(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }
    }

    /// 后台删除头像文件
    private func deleteAvatarFile() {
        let url = avatarFileURL
        ioQueue.async {
            try? FileManager.default.removeItem(at: url)
            AppLog.profile.debug("头像文件已删除")
        }
    }

    /// 一次性迁移：把老版本存在 `UserDefaults` 里的头像数据搬到文件系统
    private func migrateLegacyAvatarIfNeeded() {
        // 一次读取 → 同时用于「存在性判断」与「写入文件」
        guard let legacyData = userDefaults.data(forKey: Keys.legacyAvatar) else {
            // 旧键不存在（大多数用户已迁移或从未用过老版本）
            return
        }

        // 写文件
        do {
            try legacyData.write(to: avatarFileURL, options: .atomic)
            AppLog.profile.info(
                "迁移 UserDefaults 头像到文件：\(legacyData.count, privacy: .public) bytes"
            )
        } catch {
            AppLog.profile.error(
                "迁移头像失败：\(error.localizedDescription, privacy: .public)"
            )
            // 迁移失败 → 保留旧键，下次再试
            return
        }

        // 迁移成功 → 删除旧键（**关键：释放 UserDefaults 空间**）
        userDefaults.removeObject(forKey: Keys.legacyAvatar)
    }
}

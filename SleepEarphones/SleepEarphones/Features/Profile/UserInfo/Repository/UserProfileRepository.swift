//
//  UserProfileRepository.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import UIKit

// MARK: - 仓库协议

/// 用户资料仓库协议
///
/// ## 职责
/// - 读写用户头像 / 昵称的本地存储
/// - **不做**优先级判断（本地 → 登录信息 → 默认值 的回退逻辑在 ViewModel 层）
/// - **不做** UI 相关处理
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
///
/// ## 线程安全说明（`Sendable` 合规性）
/// 本类满足 `protocol Sendable`，所有存储属性均为 `let` + `Sendable` 类型：
/// - `UserDefaults`：系统标注 `@unchecked Sendable`，内部有锁，**任意线程读写安全**
/// - `DispatchQueue`：`Sendable`
/// - `URL` / `CGFloat`：值类型 `Sendable`
///
/// - Important: 原代码用 `nonisolated(unsafe) private let userDefaults`——
///              **不必要**。现代 SDK 的 `UserDefaults` 已是 `@unchecked Sendable`，
///              额外标注属于"防御过度"，反而会误导维护者
///              （以为需要手动保证线程安全）。
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
    ///
    /// - Note: `DispatchQueue` 本身是 `Sendable`——
    ///         所有对 `avatarFileURL` 的读写都经过此队列串行化。
    private let ioQueue = DispatchQueue(
        label: "com.sleepearphones.profile.io",
        qos: .utility
    )

    /// 头像文件 URL（延迟计算，缓存）
    ///
    /// - Returns: `{Application Support}/SleepEarphones/avatar.jpg`
    ///
    /// - Note: `init` 中计算一次后不可变；对它的**文件操作**都在
    ///         `ioQueue` 上串行执行。
    private let avatarFileURL: URL

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter userDefaults: 便于单元测试注入 `UserDefaults(suiteName:)`
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // 计算头像文件路径
        //
        // - `Application Support` 目录在 iOS 上**可能不存在**（首次安装未创建）——
        //   需要手动创建。若创建失败，回退到 `Documents`（几乎必然存在）。
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
    ///
    /// - Note: 在 `ioQueue` 上执行文件读取 + 迁移旧数据，
    ///         主线程调用者通过 `await` 等待结果，不阻塞 UI。
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
    ///
    /// - Note: `UserDefaults.string(forKey:)` 是**内存 + 缓存**操作——
    ///         极快（微秒级）——**无需**异步。
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
    ///
    /// - Note: **不阻塞**调用者——压缩 + 写入在后台 `ioQueue` 执行。
    ///         若写入失败（如磁盘满），仅输出日志——
    ///         内存中的头像仍有效，下次进入时可能显示旧头像。
    func updateAvatar(_ avatar: UIImage) {
        writeAvatarFile(avatar)
    }

    /// 仅更新昵称
    ///
    /// - Parameter nickname: 新昵称
    ///
    /// - Note: `UserDefaults` 的 `set` 是同步的——几微秒完成——
    ///         **无需**异步。
    func updateNickname(_ nickname: String) {
        userDefaults.set(nickname, forKey: Keys.nickname)
    }

    // MARK: - Private Helpers（文件操作）

    /// 后台写入头像文件
    ///
    /// - Parameter avatar: 待写入的头像
    ///
    /// - Note: `autoreleasepool` 显式包裹——大图解码占用内存较多，
    ///         写到文件后即可立即释放中间的 `Data` / `CGImage` 对象，
    ///         避免内存峰值堆积。
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
    ///
    /// - Note: **必须**在 `ioQueue` 上调用（`loadAvatar` 内部已保证）——
    ///         迁移涉及文件 IO，在主线程执行会阻塞 UI。
    ///
    /// - 迁移成功后**删除旧键**：释放 `UserDefaults` 的空间（旧头像是
    ///   base64 / Data 形式，可能占用数百 KB，长期留存是浪费）。
    private func migrateLegacyAvatarIfNeeded() {
        // 一次读取 → 同时用于「存在性判断」与「写入文件」
        //
        // - Note: 原代码读两次（一次判空、一次取 Data），
        //         虽然 `UserDefaults` 读取极快，但一次读取更简洁。
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

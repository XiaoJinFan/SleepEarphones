//
//  UserProfileViewModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/7.
//

import UIKit
import Combine
import Kingfisher

/// 用户资料视图模型
///
@MainActor
final class UserProfileViewModel {

    // MARK: - Constants

    /// 默认昵称（所有来源都无值时使用）
    private static let defaultNickname = "五彩斑斓的黑"

    /// 头像 JPEG 压缩质量（上传时使用）
    ///
    /// - Note: 0.8 是体积与画质的平衡点——视觉几乎无差异，体积约为原图的 1/5。
    private static let avatarUploadQuality: CGFloat = 0.8

    // MARK: - Published 属性（UI 订阅）

    /// 用户头像
    @Published private(set) var avatarImage: UIImage?

    /// 用户昵称
    @Published private(set) var nickname: String = ""

    /// 保存中（用于禁用保存按钮 + 显示 loading）
    @Published private(set) var isSaving: Bool = false

    /// 刷新中（用于未来可能的"下拉刷新"UI）
    @Published private(set) var isRefreshing: Bool = false

    // MARK: - Private

    private let repository: UserProfileRepositoryProtocol
    private let service: UserProfileServiceProtocol

    /// 头像加载任务（用于在 VM 释放时取消）
    private nonisolated(unsafe) var avatarLoadTask: Task<Void, Never>?

    // MARK: - Initializer（依赖注入）

    /// 初始化
    ///
    /// - Parameters:
    ///   - repository: 本地存储仓库
    ///   - service: 网络服务
    ///
    init(
        repository: UserProfileRepositoryProtocol = UserProfileRepository(),
        service: UserProfileServiceProtocol = UserProfileService()
    ) {
        self.repository = repository
        self.service = service
        loadNickname()
        loadAvatarAsync()
    }

    deinit {
        // 取消正在进行的头像加载（`Task.cancel()` 线程安全）
        avatarLoadTask?.cancel()
    }

    // MARK: - 数据加载

    /// 同步加载昵称
    ///
    /// ## 优先级
    /// 1. 本地设置（用户在"我的资料"页改过的）
    /// 2. `AuthStore` 缓存的（登录时写入）
    /// 3. 默认值（`defaultNickname`）
    private func loadNickname() {
        if let local = repository.loadNickname(), !local.isEmpty {
            AppLog.profile.debug("昵称来源：本地设置 → \(local, privacy: .private)")
            nickname = local
            return
        }
        if let auth = AuthStore.shared.nickname, !auth.isEmpty {
            AppLog.profile.debug("昵称来源：登录信息 → \(auth, privacy: .private)")
            nickname = auth
            return
        }
        AppLog.profile.debug("昵称来源：默认值")
        nickname = Self.defaultNickname
    }

    /// 加载头像（优先级：本地设置 → 登录信息（远程下载）→ nil）
    ///
    private func loadAvatarAsync() {
        avatarLoadTask = Task { [weak self] in
            guard let self else { return }

            // 1. 优先本地（用户主动选过的）
            if let local = await self.repository.loadAvatar() {
                if Task.isCancelled { return }
                AppLog.profile.debug("头像来源：本地设置")
                self.avatarImage = local
                return
            }

            // 2. 回退到登录时缓存的远程 URL
            if let avatarURL = AuthStore.shared.avatar, !avatarURL.isEmpty {
                AppLog.profile.debug(
                    "头像来源：登录信息（远程下载）URL=\(avatarURL, privacy: .public)"
                )
                let remote = await Self.downloadAvatar(urlString: avatarURL)
                if Task.isCancelled { return }
                self.avatarImage = remote
                return
            }

            // 3. 无头像
            AppLog.profile.debug("头像来源：无（将展示占位图）")
            self.avatarImage = nil
        }
    }

    /// 下载远程头像（静态方法，不依赖 VM 状态）
    ///
    /// - Parameter urlString: 头像 URL
    /// - Returns: 下载成功的图片；失败时返回 `nil`（不抛错——头像是非关键数据）
    ///
    private static func downloadAvatar(urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else {
            AppLog.profile.error("头像 URL 非法：\(urlString, privacy: .public)")
            return nil
        }
        do {
            let result = try await KingfisherManager.shared.retrieveImage(with: url)
            return result.image
        } catch {
            AppLog.profile.error(
                "下载头像失败：\(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    // MARK: - 刷新（进入「我的」Tab 时调用）

    /// 从服务端拉取最新的用户信息并更新 UI
    ///
    func refresh() async {
        // 未登录：跳过（防御性——正常流程下 MyViewController 只在登录后出现）
        guard AuthStore.shared.isLoggedIn else {
            AppLog.profile.debug("未登录，跳过用户信息刷新")
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let info = try await fetchUserInfo()

            AppLog.profile.debug(
                "用户信息刷新成功：nickname=\(info.nickname ?? "nil", privacy: .private) hasAvatar=\(info.hasAvatar, privacy: .public)"
            )

            // 1. 更新 AuthStore 缓存（昵称 / 头像 URL）
            //
            // - 用途：换设备登录 / 重启 App 时能加载到最新值。
            AuthStore.shared.updateProfile(
                nickname: info.nickname,
                avatarURL: info.avatar
            )

            // 2. 写入真实手机号 / 邮箱（供"账号与安全"页发送验证码使用）
            AuthStore.shared.updateRealAccount(
                realMobile: info.realMobile,
                realEmail: info.email
            )

            // 3. 更新昵称（内存 + 本地存储）
            if let newNickname = info.nickname, !newNickname.isEmpty {
                self.nickname = newNickname
                repository.updateNickname(newNickname)
                AppLog.profile.debug("昵称来源：服务端刷新 → \(newNickname, privacy: .private)")
            }

            // 4. 更新头像（**服务端优先**）
            if let avatarURL = info.avatar, !avatarURL.isEmpty,
               let remote = await Self.downloadAvatar(urlString: avatarURL) {
                self.avatarImage = remote
                repository.updateAvatar(remote)
                AppLog.profile.debug("头像来源：服务端刷新 → \(avatarURL, privacy: .public)")
            } else {
                AppLog.profile.debug("服务端未返回头像 URL，保持本地")
            }

        } catch {
            AppLog.profile.debug(
                "用户信息刷新失败：\((error as? NetworkError)?.logCode ?? "unknown", privacy: .public)"
            )
        }
    }

    // MARK: - 数据保存（异步 + 远程同步）

    /// 保存用户资料（本地立即 + 远程异步）
    ///
    /// - Parameters:
    ///   - avatar: 新头像；`nil` 表示**不改头像**（保留当前）
    ///   - nickname: 新昵称
    ///
    func save(avatar: UIImage?, nickname: String) async throws {

        // 1. 立即进入"保存中"状态（UI 立即禁用按钮）
        isSaving = true
        defer { isSaving = false }

        // 2. 内存更新
        //
        // - Note: 若 avatar == nil 表示"不改头像"，
        //         此时保留 self.avatarImage 的原值。
        if let avatar {
            self.avatarImage = avatar
        }
        self.nickname = nickname

        // 3. 本地持久化（分字段更新）
        if let avatar {
            repository.updateAvatar(avatar)
        }
        repository.updateNickname(nickname)

        AppLog.profile.debug(
            "保存用户资料：昵称长度=\(nickname.count, privacy: .public) 头像=\(avatar != nil ? "新头像" : "未变更", privacy: .public)"
        )

        // 4. 远程同步（可能抛错——本地已保存，见上方 tradeoff 说明）
        do {
            // 4.1 若头像变更 → 先上传，拿 URL
            var remoteAvatarURL: String?
            if let avatar {
                guard let imageData = avatar.jpegData(
                    compressionQuality: Self.avatarUploadQuality
                ) else {
                    // 压缩失败——几乎不可能发生，但仍需处理
                    // 用 `NetworkError.decoding` 包装（语义：数据转换失败）
                    throw NetworkError.decoding(
                        NSError(
                            domain: "UserProfile",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "头像压缩失败"]
                        )
                    )
                }

                // 文件名带 UUID——避免后端 OSS 覆盖同名文件
                let fileName = "avatar_\(UUID().uuidString).jpg"
                remoteAvatarURL = try await uploadAvatar(
                    imageData: imageData,
                    fileName: fileName
                )
                AppLog.profile.debug(
                    "头像上传成功：URL=\(remoteAvatarURL ?? "", privacy: .public)"
                )
            }

            // 4.2 调修改资料接口（昵称 + 头像 URL）
            
            try await editProfile(
                nickname: nickname,
                avatarURL: remoteAvatarURL
            )

            // 4.3 成功后更新 AuthStore 缓存（换设备登录时用）
            AuthStore.shared.updateProfile(
                nickname: nickname,
                avatarURL: remoteAvatarURL
            )

            AppLog.profile.debug("用户资料远程同步成功")
        } catch {
            AppLog.profile.error(
                "用户资料远程同步失败：\((error as? NetworkError)?.logCode ?? "unknown", privacy: .public)"
            )
            // 向上层抛出——`PersonalViewController` 会展示 Alert
            throw error
        }
    }

    // MARK: - Private Async Wrappers

    /// 拉取用户详情（Combine → async 桥接）
    private func fetchUserInfo() async throws -> UserDetailInfo {
        try await service.fetchUserInfo().firstValue()
    }

    /// 上传头像（Combine → async 桥接）
    ///
    /// - Parameters:
    ///   - imageData: JPEG 二进制
    ///   - fileName: 文件名
    /// - Returns: 上传成功后的完整 URL
    private func uploadAvatar(imageData: Data, fileName: String) async throws -> String {
        try await service.uploadAvatar(
            imageData: imageData,
            fileName: fileName
        ).firstValue()
    }

    /// 修改用户资料（Combine → async 桥接）
    ///
    /// - Parameters:
    ///   - nickname: 新昵称；`nil` 表示不修改
    ///   - avatarURL: 新头像 URL；`nil` 表示不修改
    private func editProfile(nickname: String?, avatarURL: String?) async throws {
        // 返回值是 Void——`firstValue()` 拿到 `()` 后丢弃即可
        _ = try await service.editProfile(
            nickname: nickname,
            avatarURL: avatarURL
        ).firstValue()
    }
}

// MARK: - Publisher → async 桥接

extension Publisher where Failure == NetworkError {

    /// 将 Publisher 转换为 async 单值返回
    ///
    /// - Returns: 第一个 value
    /// - Throws: `NetworkError`——网络失败或 Publisher 提前完成但无 value
    ///
    func firstValue() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            let state = ResumeState()

            let cancellable = receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        // 若已 resume（正常路径下 value 已发出），直接忽略
                        guard state.tryMarkResumed() else { return }

                        switch completion {
                        case .failure(let error):
                            continuation.resume(throwing: error)

                        case .finished:
                            // 防御性处理：Publisher 完成但无 value 发出
                            AppLog.profile.warning(
                                "Publisher 完成但无 value 发出，抛出 emptyData 避免悬挂"
                            )
                            continuation.resume(throwing: NetworkError.emptyData)
                        }
                    },
                    receiveValue: { value in
                        // 同一 Publisher 发送多个 value 时只取第一个
                        guard state.tryMarkResumed() else { return }
                        continuation.resume(returning: value)
                    }
                )

            // 把订阅句柄交给 state 持有，直到流结束（由 `tryMarkResumed` 清空）
            state.attach(cancellable)
        }
    }
}

// MARK: - ResumeState

private final class ResumeState: @unchecked Sendable {

    private let lock = NSLock()
    private var hasResumed = false
    private var cancellable: AnyCancellable?

    /// 尝试标记为"已 resume"
    ///
    /// - Returns: 首次调用返回 `true`；再次调用返回 `false`
    ///
    func tryMarkResumed() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !hasResumed else { return false }
        hasResumed = true
        // 流已结束，释放订阅避免泄漏
        cancellable = nil
        return true
    }

    /// 附加订阅句柄
    ///
    /// - Parameter c: `sink` 返回的 `AnyCancellable`
    /// 
    func attach(_ c: AnyCancellable) {
        lock.lock()
        if hasResumed {
            lock.unlock()
            c.cancel()
            return
        }
        cancellable = c
        lock.unlock()
    }
}

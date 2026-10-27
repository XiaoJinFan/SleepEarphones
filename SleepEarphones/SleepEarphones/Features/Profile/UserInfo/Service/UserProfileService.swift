//
//  UserProfileService.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/30.
//

import Foundation
import Combine
import Network

// MARK: - 服务协议

/// 用户资料网络服务协议
///
/// ## 职责
/// - 只负责**网络请求**（调用 `NetworkClient`）
/// - 不做本地存储 / 不做 UI 逻辑
///
/// ## 分层说明
/// ```
/// ViewModel
///   ↓
/// UserProfileService（本协议 + 实现）
///   ↓
/// NetworkClient
///
protocol UserProfileServiceProtocol: Sendable {

    /// 修改用户资料
    ///
    /// - Parameters:
    ///   - nickname: 新昵称；nil 或空串表示不修改
    ///   - avatarURL: 头像 URL；nil 或空串表示不修改
    /// - Returns: 成功时返回 Void
    func editProfile(nickname: String?, avatarURL: String?) -> AnyPublisher<Void, NetworkError>

    /// 拉取当前用户的详细信息
    ///
    /// - Returns: 用户详情（含昵称、头像 URL 等）
    ///
    /// - Note: 服务端通过 `user-token` 请求头识别当前用户，无需额外参数。
    func fetchUserInfo() -> AnyPublisher<UserDetailInfo, NetworkError>

    /// 上传头像文件
    ///
    /// - Parameters:
    ///   - imageData: JPEG 二进制
    ///   - fileName: 文件名
    /// - Returns: 上传成功后的文件 URL（完整 URL，可直接用于 `editProfile`）
    func uploadAvatar(imageData: Data, fileName: String) -> AnyPublisher<String, NetworkError>
}

// MARK: - 服务实现

/// 用户资料网络服务实现
///
final class UserProfileService: UserProfileServiceProtocol {

    // MARK: - Properties

    private let client: NetworkClientProtocol

    // MARK: - Init

    init(client: NetworkClientProtocol = NetworkClient()) {
        self.client = client
    }

    // MARK: - 修改资料

    /// 修改用户资料（昵称 / 头像）
    ///
    /// - Note: 后端 `5cb54af125f1c` 接口——
    ///         `data` 层返回空对象，用 `EmptyResponse` 宽容解码。
    ///
    /// ## 参数语义
    /// - `nickname == nil` / 空串 → **不修改**昵称
    /// - `avatarURL == nil` / 空串 → **不修改**头像
    /// - 两者都为 nil → 理论上无意义调用——后端会返回"无参数"错误
    ///   （实际调用方 `UserProfileViewModel.save` 保证至少有一个非 nil）
    ///
    func editProfile(nickname: String?, avatarURL: String?) -> AnyPublisher<Void, NetworkError> {
        AppLog.profile.debug(
            "修改资料：nickname=\(nickname ?? "nil", privacy: .private) avatarURL=\(avatarURL ?? "nil", privacy: .public)"
        )

        return client.request(
            UserProfileAPI.editProfile(nickname: nickname, avatarURL: avatarURL),
            as: EmptyResponse.self
        )
        .map { _ in () }
        .eraseToAnyPublisher()
    }

    // MARK: - 拉取用户信息

    /// 拉取用户详情
    ///
    /// - Note: 只用于"刷新显示"——失败时上层会静默忽略，
    ///         不清空已展示的本地数据。
    ///
    func fetchUserInfo() -> AnyPublisher<UserDetailInfo, NetworkError> {
        
        let userId = AuthStore.shared.userId

        AppLog.profile.debug(
            "拉取用户详情：userId=\(userId, privacy: .private)"
        )

        return client.request(
            UserProfileAPI.fetchUserInfo,
            as: UserDetailInfo.self
        )
        .eraseToAnyPublisher()
    }

    // MARK: - 上传头像

    /// 上传头像
    ///
    /// ## 完整流程
    /// ```
    /// 1. POST multipart/form-data → upload/uploadFileOss
    ///    ├─ 表单字段名：file
    ///    └─ 文件类型：image/jpeg
    /// 2. 后端返回：{ data: { data: { file: "https://..." } } }
    /// 3. 本方法解出 file URL 并返回
    ///
    /// ## 关于返回结构
    /// `UploadResult` 会解开 `data.data.file` 嵌套结构——
    /// 详见 `UploadResult` 的注释。
    ///
    /// - Parameters:
    ///   - imageData: JPEG 压缩后的二进制数据
    ///   - fileName: 文件名（用于 `Content-Disposition`）
    /// - Returns: 上传成功后的完整文件 URL
    func uploadAvatar(imageData: Data, fileName: String) -> AnyPublisher<String, NetworkError> {
        // ⚠️ 用 info 级别——上传有成本（流量 + 存储），生产应可见
        AppLog.profile.info(
            "📤 上传头像：fileName=\(fileName, privacy: .public) size=\(imageData.count, privacy: .public) bytes"
        )

        return client.request(
            UserProfileAPI.uploadAvatar(
                imageData: imageData,
                fileName: fileName,
                fieldName: "file",       // ⚠️ 后端约定的表单字段名（不可改）
                mimeType: "image/jpeg"
            ),
            as: UploadResult.self
        )
        .tryMap { result in
            // ✅ 关键：从 `fileURL` 取值（对应 `data.data.file`）——
            //         不是 `result.url`（那是旧结构）。
            guard let url = result.fileURL, !url.isEmpty else {
                AppLog.profile.error("上传成功但未返回 file URL")
                // 抛出 NetworkError——与上游错误类型一致
                throw NetworkError.emptyData
            }

            AppLog.profile.debug(
                "上传成功：fileURL=\(url, privacy: .public) fileID=\(result.fileID ?? -1, privacy: .public)"
            )
            return url
        }
        .mapError { error in
            (error as? NetworkError) ?? .underlying(error)
        }
        .eraseToAnyPublisher()
    }
}

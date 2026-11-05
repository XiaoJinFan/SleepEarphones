//
//  MusicRepository.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/10.
//

import Foundation
import Combine

// MARK: - 仓库协议

protocol MusicRepositoryProtocol: Sendable {

    /// 拉取顶部横幅轮播
    func fetchBanners() -> AnyPublisher<[MusicBanner], NetworkError>

    /// 拉取音乐分类列表（含音乐数据）
    func fetchCategories() -> AnyPublisher<[MusicCategory], NetworkError>

    /// 拉取音乐列表
    ///
    /// - Parameters:
    ///   - freemusicsubcategory_id: 子分类 ID；传 `nil` 不过滤
    ///   - customWhiteNoise: 是否只拉自定义白噪音
    func fetchSongs(freemusicsubcategory_id: String?, customWhiteNoise: Bool?) -> AnyPublisher<[MusicSong], NetworkError>

    /// 拉取自定义白噪音列表
    func fetchCustomNoises() -> AnyPublisher<[MusicSong], NetworkError>
}

// MARK: - 仓库实现

/// 音乐仓库实现
final class MusicRepository: MusicRepositoryProtocol, Sendable {

    // MARK: - Singleton

    /// 共享实例
    static let shared = MusicRepository()

    // MARK: - Properties

    private let service: MusicServiceProtocol

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter service: 音乐服务，默认 `MusicService.shared`
    init(service: MusicServiceProtocol = MusicService.shared) {
        self.service = service
    }

    // MARK: - Fetch Banners

    func fetchBanners() -> AnyPublisher<[MusicBanner], NetworkError> {
        service.fetchBanners()
            .eraseToAnyPublisher()
    }

    // MARK: - Fetch Categories

    func fetchCategories() -> AnyPublisher<[MusicCategory], NetworkError> {
        service.fetchCategories()
            .eraseToAnyPublisher()
    }

    // MARK: - Fetch Songs

    func fetchSongs(freemusicsubcategory_id: String?, customWhiteNoise: Bool?) -> AnyPublisher<[MusicSong], NetworkError> {
        service.fetchSongs(
            freemusicsubcategory_id: freemusicsubcategory_id,
            customWhiteNoise: customWhiteNoise
        )
        .eraseToAnyPublisher()
    }

    // MARK: - Fetch Custom Noises

    /// 拉取自定义白噪音列表
    func fetchCustomNoises() -> AnyPublisher<[MusicSong], NetworkError> {
        service.fetchSongs(
            freemusicsubcategory_id: nil,
            customWhiteNoise: true
        )
        .eraseToAnyPublisher()
    }
}

// MARK: - 匹配便捷方法

/// 统一"拉取 → 匹配"逻辑
extension MusicRepositoryProtocol {

    /// 拉取并匹配指定子分类的音乐
    ///
    /// - Parameters:
    ///   - subCategoryId: 子分类 ID（来自 `MusicCardItem.id`）
    ///   - customWhiteNoise: 是否只拉自定义白噪音；`nil` 表示不过滤
    /// - Returns: 匹配到的音乐（匹配失败用第一条兜底）；无数据时抛 `.emptyData`
    func fetchMatchedSong(subCategoryId: String, customWhiteNoise: Bool? = nil) -> AnyPublisher<MusicSong, NetworkError> {
        fetchSongs(
            freemusicsubcategory_id: subCategoryId,
            customWhiteNoise: customWhiteNoise
        )
        .tryMap { songs -> MusicSong in
            // 防御性：空列表直接抛错（原实现隐式通过 `?? songs.first` 处理）
            guard !songs.isEmpty else {
                throw NetworkError.emptyData
            }

            // 若 subCategoryId 不是数字字符串，跳过匹配直接用第一条
            guard let targetId = Int(subCategoryId) else {
                AppLog.app.debug(
                    "fetchMatchedSong：subCategoryId 非数字（\(subCategoryId, privacy: .public)），使用第一条"
                )
                return songs[0]
            }

            // 优先匹配 targetId，未命中用第一条兜底
            let matched = songs.first(where: { $0.subCategoryId == targetId })
                ?? songs[0]

            AppLog.app.debug(
                "fetchMatchedSong：targetId=\(targetId, privacy: .public) → song.aid=\(matched.id, privacy: .public)（匹配成功=\(matched.subCategoryId == targetId)）"
            )
            return matched
        }
        .mapError { ($0 as? NetworkError) ?? .underlying($0) }
        .eraseToAnyPublisher()
    }
}

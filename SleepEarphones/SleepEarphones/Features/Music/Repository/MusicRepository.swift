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

final class MusicRepository: MusicRepositoryProtocol {

    // MARK: - Singleton

    /// 共享实例
    ///
    /// - Note: 单例 + `MusicService.shared` 双重保证，
    ///         整个 App 内 Session / 网络配置只有一份。
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
///
/// ## 背景
/// `MusicViewController.fetchAndPlaySong` 与
/// `MusicListViewController.playSong` 都做同样的事：
/// 1. 拉取指定子分类的歌曲列表
/// 2. 用 `subCategoryId` 匹配目标
/// 3. 匹配失败时用第一条兜底
///
/// 抽到此处后，2 个调用方只需一行 `fetchMatchedSong`。
extension MusicRepositoryProtocol {

    /// 拉取并匹配指定子分类的音乐
    ///
    /// - Parameters:
    ///   - subCategoryId: 子分类 ID（来自 `MusicCardItem.id`）
    ///   - customWhiteNoise: 是否只拉自定义白噪音；`nil` 表示不过滤
    /// - Returns: 匹配到的音乐（匹配失败用第一条兜底）；无数据时抛 `.emptyData`
    func fetchMatchedSong(subCategoryId: String, customWhiteNoise: Bool? = nil) -> AnyPublisher<MusicSong, NetworkError> {
        fetchSongs(freemusicsubcategory_id: subCategoryId, customWhiteNoise: customWhiteNoise)
            .tryMap { songs -> MusicSong in
                let targetId = Int(subCategoryId)
                guard let song = songs.first(where: { $0.subCategoryId == targetId })
                    ?? songs.first else {
                    throw NetworkError.emptyData
                }
                return song
            }
            .mapError { ($0 as? NetworkError) ?? .underlying($0) }
            .eraseToAnyPublisher()
    }
}

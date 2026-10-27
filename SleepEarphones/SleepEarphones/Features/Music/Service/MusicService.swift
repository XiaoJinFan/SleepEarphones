//
//  MusicService.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/10.
//

import Foundation
import Combine

/// 音乐网络服务协议
protocol MusicServiceProtocol: Sendable {

    /// 拉取顶部横幅轮播
    func fetchBanners() -> AnyPublisher<[MusicBanner], NetworkError>

    /// 拉取音乐分类列表
    func fetchCategories() -> AnyPublisher<[MusicCategory], NetworkError>

    /// 拉取音乐列表
    ///
    /// - Parameters:
    ///   - freemusicsubcategory_id: 子分类 ID；传 `nil` 不过滤
    ///   - customWhiteNoise: 是否只拉自定义白噪音
    func fetchSongs(freemusicsubcategory_id: String?, customWhiteNoise: Bool?) -> AnyPublisher<[MusicSong], NetworkError>
}

// MARK: - 服务实现

final class MusicService: MusicServiceProtocol {

    // MARK: - Singleton

    static let shared = MusicService()

    // MARK: - Properties

    private let client: NetworkClientProtocol

    // MARK: - Init

    init(client: NetworkClientProtocol = NetworkClient()) {
        self.client = client
    }

    // MARK: - Fetch Banners

    func fetchBanners() -> AnyPublisher<[MusicBanner], NetworkError> {
        AppLog.app.debug("拉取音乐页横幅")

        return client.request(
            MusicAPI.bannerList,
            as: [MusicBanner].self
        )
        .eraseToAnyPublisher()
    }

    // MARK: - Fetch Categories

    func fetchCategories() -> AnyPublisher<[MusicCategory], NetworkError> {
        AppLog.app.debug("拉取音乐分类（含音乐数据）")

        return client.request(
            MusicAPI.categoryList,
            as: [MusicCategory].self
        )
        .eraseToAnyPublisher()
    }

    // MARK: - Fetch Songs

    func fetchSongs(freemusicsubcategory_id: String?, customWhiteNoise: Bool?) -> AnyPublisher<[MusicSong], NetworkError> {
        AppLog.app.debug(
            "拉取音乐列表：freemusicsubcategory_id=\(freemusicsubcategory_id ?? "全部", privacy: .public) customWhiteNoise=\(customWhiteNoise == true ? "1" : "nil", privacy: .public)"
        )

        return client.request(
            MusicAPI.songList(
                freemusicsubcategory_id: freemusicsubcategory_id,
                customWhiteNoise: customWhiteNoise
            ),
            as: [MusicSong].self
        )
        .eraseToAnyPublisher()
    }
}

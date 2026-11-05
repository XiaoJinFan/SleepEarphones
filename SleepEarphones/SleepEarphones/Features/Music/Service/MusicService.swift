//
//  MusicService.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/10.
//

import Foundation
import Combine

// MARK: - 服务协议

/// 音乐网络服务协议
///
/// ## 职责
/// - 只负责**网络请求**（调用 `NetworkClient`）
/// - 不做缓存 / 不做业务判断 / 不做数据转换
///
/// ## 调用方法
/// ```swift
/// // 1. 生产环境
/// let service = MusicService.shared
///
/// // 2. 单元测试（注入 Mock）
/// let service = MusicService(client: MockNetworkClient())
///
/// // 3. 调用
/// service.fetchCategories()
///     .sink(
///         receiveCompletion: { ... },
///         receiveValue: { categories in ... }
///     )
///     .store(in: &cancellables)
/// ```
protocol MusicServiceProtocol: Sendable {

    /// 拉取顶部横幅轮播
    func fetchBanners() -> AnyPublisher<[MusicBanner], NetworkError>

    /// 拉取音乐分类列表（**含每类下的音乐**）
    func fetchCategories() -> AnyPublisher<[MusicCategory], NetworkError>

    /// 拉取音乐列表
    ///
    /// - Parameters:
    ///   - freemusicsubcategory_id: 子分类 ID；传 `nil` 不过滤
    ///   - customWhiteNoise: 是否只拉自定义白噪音
    ///     - `true`：加 `custom_white_noise=1` 过滤
    ///     - `false` / `nil`：不加该字段（返回全部）
    func fetchSongs(freemusicsubcategory_id: String?, customWhiteNoise: Bool?) -> AnyPublisher<[MusicSong], NetworkError>
}

// MARK: - 服务实现

/// 音乐网络服务实现
final class MusicService: MusicServiceProtocol, Sendable {

    // MARK: - Singleton

    /// 共享实例
    static let shared = MusicService()

    // MARK: - Properties

    private let client: NetworkClientProtocol

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter client: 网络客户端，默认 `NetworkClient()`
    init(client: NetworkClientProtocol = NetworkClient()) {
        self.client = client
    }

    // MARK: - Fetch Banners

    /// 拉取音乐页横幅
    ///
    /// - Returns: Banner 数组 Publisher
    func fetchBanners() -> AnyPublisher<[MusicBanner], NetworkError> {
        AppLog.app.debug("拉取音乐页横幅")

        return client.request(
            MusicAPI.bannerList,
            as: [MusicBanner].self
        )
        .eraseToAnyPublisher()
    }

    // MARK: - Fetch Categories

    /// 拉取音乐分类（含音乐数据）
    ///
    /// - Returns: 分类数组 Publisher
    func fetchCategories() -> AnyPublisher<[MusicCategory], NetworkError> {
        AppLog.app.debug("拉取音乐分类（含音乐数据）")

        return client.request(
            MusicAPI.categoryList,
            as: [MusicCategory].self
        )
        .eraseToAnyPublisher()
    }

    // MARK: - Fetch Songs

    /// 拉取音乐列表
    ///
    /// - Parameters:
    ///   - freemusicsubcategory_id: 子分类 ID；`nil` 不过滤
    ///   - customWhiteNoise: 是否只拉自定义白噪音
    /// - Returns: 音乐列表 Publisher
    func fetchSongs(freemusicsubcategory_id: String?, customWhiteNoise: Bool?) -> AnyPublisher<[MusicSong], NetworkError> {
        AppLog.app.debug(
            "拉取音乐列表：freemusicsubcategory_id=\(freemusicsubcategory_id ?? "nil", privacy: .public) customWhiteNoise=\(customWhiteNoise == true ? "1" : "nil", privacy: .public)"
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

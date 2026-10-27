//
//  MusicViewModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/10.
//

import Foundation
import Combine

@MainActor
final class MusicViewModel {

    // MARK: - Output

    /// 顶部横幅列表
    @Published private(set) var banners: [MusicBanner] = []

    /// 音乐分组列表（含标题 + 每个分组下的音乐）
    @Published private(set) var sections: [MusicSection] = []

    /// 是否正在加载（首屏显示菊花）
    @Published private(set) var isLoading: Bool = false

    /// 错误信息
    @Published private(set) var errorMessage: String?

    /// 空数据状态
    ///
    /// - Returns: 无数据 + 不在加载 + 无错误时为 `true`
    var isEmpty: Bool {
        sections.isEmpty && !isLoading && errorMessage == nil
    }

    // MARK: - Private

    private let repository: MusicRepositoryProtocol

    /// 当前进行中的请求（用于取消，避免竞态）
    private var currentRequest: AnyCancellable?

    /// 请求身份令牌
    private var requestToken: UInt64 = 0

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter repository: 音乐仓库，默认 `MusicRepository()`
    init(repository: MusicRepositoryProtocol = MusicRepository()) {
        self.repository = repository
    }

    // MARK: - Input

    /// 加载音乐页全部数据
    func loadData() {
        // 防抖
        guard !isLoading else {
            AppLog.app.debug("音乐页加载被拦截：已在加载中")
            return
        }

        // 取消旧请求并递增令牌
        currentRequest?.cancel()
        currentRequest = nil
        requestToken &+= 1
        let token = requestToken

        errorMessage = nil
        isLoading = true

        AppLog.app.debug("发起音乐页数据请求 token=\(token, privacy: .public)")

        // 并发拉取 banners + categories
        let bannersPublisher = repository.fetchBanners()
            .catch { error -> Just<[MusicBanner]> in
                AppLog.app.error("Banner 加载失败，降级为空：\(error.logCode, privacy: .public)")
                return Just([])
            }
            .setFailureType(to: NetworkError.self)
            .eraseToAnyPublisher()

        let categoriesPublisher = repository.fetchCategories()
            .eraseToAnyPublisher()

        currentRequest = Publishers.Zip(bannersPublisher, categoriesPublisher)
            .receive(on: DispatchQueue.main) // 确保后续状态更新在主线程
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self, self.requestToken == token else {
                        AppLog.app.debug("丢弃过期音乐页回调 token=\(token, privacy: .public)")
                        return
                    }
                    self.isLoading = false
                    self.currentRequest = nil

                    if case .failure(let error) = completion {
                        if case .cancelled = error { return }
                        AppLog.app.error(
                            "音乐页加载失败：\(error.logCode, privacy: .public)"
                        )
                        self.errorMessage = error.errorDescription ?? "加载失败，请稍后重试"
                    }
                },
                receiveValue: { [weak self] banners, categories in
                    guard let self, self.requestToken == token else { return }

                    // 将 categories 直接转换为 sections
                    let sections = Self.makeSections(from: categories)

                    AppLog.app.debug(
                        "音乐页加载成功：\(banners.count, privacy: .public) 个横幅，\(sections.count, privacy: .public) 个分组"
                    )
                    self.banners = banners
                    self.sections = sections
                }
            )
    }

    /// 拉取指定子分类下的音乐（用于点击卡片时获取音频 URL）
    ///
    /// - Parameters:
    ///   - freemusicsubcategory_id: 子分类 ID（来自 `MusicCardItem.id`）
    ///   - customWhiteNoise: 是否只拉取自定义白噪音
    /// - Returns: 音乐列表 Publisher
    func fetchSongs(freemusicsubcategory_id: String, customWhiteNoise: Bool? = nil) -> AnyPublisher<[MusicSong], NetworkError> {
        repository.fetchSongs(freemusicsubcategory_id: freemusicsubcategory_id, customWhiteNoise: customWhiteNoise)
    }

    /// 拉取并匹配目标子分类的音乐（**VC 层点击卡片后调用**）
    ///
    /// - Parameters:
    ///   - subCategoryId: 子分类 ID（来自 `MusicCardItem.id`）
    ///   - customWhiteNoise: 是否只拉自定义白噪音；`nil` 表示不过滤
    /// - Returns: 匹配到的音乐（匹配失败用第一条兜底）；无数据时抛 `.emptyData`
    func fetchMatchedSong(subCategoryId: String, customWhiteNoise: Bool? = nil) -> AnyPublisher<MusicSong, NetworkError> {
        repository.fetchMatchedSong(
            subCategoryId: subCategoryId,
            customWhiteNoise: customWhiteNoise
        )
    }

    /// 清除错误
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Helpers

    /// 将网络分类模型转换为 UI 分组模型（**过滤空分组**）
    /// 
    /// - Parameter categories: 接口返回的分类列表
    /// - Returns: 可用于 UI 的分组列表
    private static func makeSections(from categories: [MusicCategory]) -> [MusicSection] {
        categories.map { category in
            MusicSection(
                id: category.id,
                title: category.name,
                items: category.items
            )
        }
        .filter { !$0.items.isEmpty }
    }
}

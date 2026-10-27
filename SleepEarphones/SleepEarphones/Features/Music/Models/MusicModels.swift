//
//  MusicModels.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/10.
//

import Foundation

// MARK: - 顶部横幅

/// 音乐页顶部横幅
struct MusicBanner: Decodable, Identifiable, Sendable {

    /// 横幅 ID（接口未返回，用 UUID 兜底）
    let id: String

    /// 横幅名称（如"音乐"）
    let name: String

    /// 图片 URL（后端 `thumb` 字段）
    let imageURL: String?

    /// 跳转链接（后端 `href` 字段）
    let linkURL: String?

    /// 链接类型（后端 `link_type` 字段）
    let linkType: String?

    /// 背景色（后端 `bg_color` 字段）
    let bgColor: String?

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case name
        case thumb
        case linkType = "link_type"
        case href
        case bgColor  = "bg_color"
    }

    // MARK: - 自定义解码

    /// 容错解码：字段缺失 / 空串时使用默认值
    ///
    /// - Parameter decoder: 解码器
    /// - Throws: `DecodingError`
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // id：接口未返回，用 UUID 兜底
        self.id = UUID().uuidString

        // name
        self.name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""

        // thumb（后端返回的已是完整 URL，无需拼 CDN）
        let rawThumb = try? c.decodeIfPresent(String.self, forKey: .thumb)
        self.imageURL = APIConfiguration.imageURL(rawThumb)

        // href
        self.linkURL = try? c.decodeIfPresent(String.self, forKey: .href)

        // link_type
        self.linkType = try? c.decodeIfPresent(String.self, forKey: .linkType)

        // bg_color
        self.bgColor = try? c.decodeIfPresent(String.self, forKey: .bgColor)
    }
}

// MARK: - 功能入口

/// 音乐页功能入口（自定义白噪音 / 内置音频）
///
/// - Note: 入口是**客户端固定配置**，不来自接口。
enum MusicEntry: CaseIterable {

    /// 自定义白噪音
    case customWhiteNoise

    /// 内置音频
    case builtInAudio

    /// 显示标题
    var title: String {
        switch self {
        case .customWhiteNoise: return "自定义白噪音"
        case .builtInAudio:     return "内置音频"
        }
    }

    /// SF Symbols 图标名
    var iconName: String {
        switch self {
        case .customWhiteNoise: return "waveform"
        case .builtInAudio:     return "airpods"
        }
    }

    /// 卡片渐变背景起始色（左上）
    var gradientStartColorHex: String {
        switch self {
        case .customWhiteNoise: return "#7B5DD6"
        case .builtInAudio:     return "#8895C9"
        }
    }

    /// 卡片渐变背景结束色（右下）
    var gradientEndColorHex: String {
        switch self {
        case .customWhiteNoise: return "#A688E8"
        case .builtInAudio:     return "#A8B3D9"
        }
    }
}

// MARK: - 音乐卡片

/// 音乐卡片（单张音频封面 + 标题）
///
/// ## 后端字段映射（音乐分类接口 `687720427240a` 的 `datas` 数组）
/// | 本属性 | 后端字段 | 说明 |
/// |---|---|---|
/// | `id` | `aid` | 音乐 ID |
/// | `title` | `name` | 音乐名称（如"篝火夜宴"） |
/// | `coverURL` | `thumb` | 封面图（完整 URL） |
/// | `categoryId` | `pid` | 分类 ID |
/// | `categoryName` | `pid_name` | 分类名（如"推荐白噪音"） |
struct MusicCardItem: Decodable, Identifiable, Sendable {

    /// 音乐 ID
    let id: String

    /// 音乐名称
    let title: String

    /// 封面图 URL
    let coverURL: String?

    /// 分类 ID
    let categoryId: Int?

    /// 分类名
    let categoryName: String

    // MARK: - 便捷判断

    /// 是否有封面图
    var hasCover: Bool {
        guard let coverURL, !coverURL.isEmpty else { return false }
        return true
    }

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case aid
        case name
        case thumb
        case pid
        case pidName = "pid_name"
    }

    // MARK: - 自定义解码

    /// 容错解码：`id` 兼容 Int / String
    ///
    /// - Parameter decoder: 解码器
    /// - Throws: `DecodingError`
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // id：兼容 Int / String
        if let intID = try? c.decode(Int.self, forKey: .aid) {
            self.id = String(intID)
        } else if let strID = try? c.decode(String.self, forKey: .aid) {
            self.id = strID
        } else {
            self.id = UUID().uuidString
        }

        // name
        self.title = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "未命名"

        // thumb（完整 URL）
        let rawThumb = try? c.decodeIfPresent(String.self, forKey: .thumb)
        self.coverURL = APIConfiguration.imageURL(rawThumb)

        // pid
        self.categoryId = try? c.decodeIfPresent(Int.self, forKey: .pid)

        // pid_name
        self.categoryName = (try? c.decodeIfPresent(String.self, forKey: .pidName)) ?? ""
    }
}

// MARK: - 音乐分类（含音乐列表）

/// 音乐分类（`musicType` 接口返回的顶层元素）
///
/// ## 后端字段映射（`687720427240a`）
/// | 本属性 | 后端字段 | 说明 |
/// |---|---|---|
/// | `id` | `aid` | 分类 ID |
/// | `name` | `name` | 分类名（如"推荐白噪音" / "自然"） |
/// | `items` | `datas` | 该分类下的音乐列表 |
///
/// ## 调用方法
/// ```swift
/// // 通常由 MusicService.fetchCategories 返回数组，业务层无需直接构造。
/// // ViewModel 层直接使用：
/// sections = categories.map { MusicSection(id: $0.id, title: $0.name, items: $0.items) }
/// ```
struct MusicCategory: Decodable, Identifiable, Sendable {

    /// 分类 ID
    let id: Int

    /// 分类名
    let name: String

    /// 该分类下的音乐列表
    let items: [MusicCardItem]

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case aid
        case name
        case datas
    }

    // MARK: - 自定义解码

    /// 容错解码：`id` 兼容 Int / String，`datas` 缺失时返回空数组
    ///
    /// - Parameter decoder: 解码器
    /// - Throws: `DecodingError`
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // id：兼容 Int / String
        if let intID = try? c.decode(Int.self, forKey: .aid) {
            self.id = intID
        } else if let strID = try? c.decode(String.self, forKey: .aid),
                  let parsed = Int(strID) {
            self.id = parsed
        } else {
            self.id = 0
        }

        // name
        self.name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""

        // datas（缺失 / 类型不符 → 空数组）
        self.items = (try? c.decodeIfPresent([MusicCardItem].self, forKey: .datas)) ?? []
    }
}

// MARK: - 分组

/// 音乐分组（ViewModel 组装用）
///
/// ## 调用方法
/// ```swift
/// let section = MusicSection(id: 1, title: "推荐白噪音", items: [card1, card2])
/// ```
struct MusicSection: Sendable {

    /// 分类 ID
    let id: Int

    /// 分组标题
    let title: String

    /// 该分组下的音乐卡片
    let items: [MusicCardItem]
}

// MARK: - 音乐歌曲（指定分类下的音频）

/// 音乐歌曲（`6874cfc814dde` 接口返回的单条音频）
///
/// ## 后端字段映射
/// | 本属性 | 后端字段 | 说明 |
/// |---|---|---|
/// | `id` | `aid` | 音乐 ID（兼容 Int / String） |
/// | `title` | `freemusiccategory_classification_name` | 音乐名（如"篝火夜宴"） |
/// | `coverURL` | `music_image` | 封面图 URL |
/// | `audioURL` | `resource_path` | 音频文件 URL |
/// | `categoryName` | `freemusicclassification_musictypename` | 分类名（如"推荐白噪音"） |
/// | `categoryId` | `freemusicclassification_id` | 分类 ID |
/// | `subCategoryName` | `freemusiccategory_classification_name` | 子分类名（与 title 相同） |
/// | `subCategoryId` | `freemusicsubcategory_id` | 子分类 ID |
/// | `isCustomWhiteNoise` | `custom_white_noise` | 是否自定义白噪音 |
/// | `isOrdinaryAudio` | `ordinary_audio` | 是否普通音频 |
///
/// ## 调用方法
/// ```swift
/// let playerVC = MusicPlayerViewController(song: song)
/// navigationController?.pushViewController(playerVC, animated: true)
/// ```
struct MusicSong: Decodable, Identifiable, Sendable {

    // MARK: - 核心字段

    /// 音乐 ID
    let id: String

    /// 音乐名（如"篝火夜宴"）
    let title: String

    /// 封面图 URL
    let coverURL: String?

    /// 音频文件 URL（**播放用**）
    let audioURL: String?

    /// 分类名（如"推荐白噪音"）
    let categoryName: String

    /// 分类 ID
    let categoryId: Int?

    /// 子分类名（如"篝火夜宴"）
    let subCategoryName: String?

    /// 子分类 ID
    let subCategoryId: Int?

    /// 是否自定义白噪音
    let isCustomWhiteNoise: Bool

    /// 是否普通音频
    let isOrdinaryAudio: Bool

    // MARK: - 便捷判断

    /// 是否可播放（音频 URL 有效）
    var canPlay: Bool {
        guard let audioURL, !audioURL.isEmpty, URL(string: audioURL) != nil else {
            return false
        }
        return true
    }

    /// 是否有封面
    var hasCover: Bool {
        guard let coverURL, !coverURL.isEmpty else { return false }
        return true
    }

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case aid
        /// 音乐名（后端字段 `music_name`，如"篝火"）
        case title                = "music_name"
        /// 封面图
        case musicImage           = "music_image"
        /// 音频 URL
        case resourcePath         = "resource_path"
        /// 分类名（如"推荐白噪音"）
        case categoryName         = "freemusicclassification_musictypename"
        /// 分类 ID
        case categoryId           = "freemusicclassification_id"
        /// 子分类名（如"篝火夜宴"）
        case subCategoryName      = "freemusicsubcategory_classification_name"
        /// 子分类 ID
        case subCategoryId        = "freemusicsubcategory_id"
        /// 是否自定义白噪音
        case isCustomWhiteNoise   = "custom_white_noise"
        /// 是否普通音频
        case isOrdinaryAudio      = "ordinary_audio"
    }

    // MARK: - 自定义解码

    /// 容错解码：`id` 兼容 Int / String，布尔值兼容 Int / Bool
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // id：兼容 Int / String
        if let intID = try? c.decode(Int.self, forKey: .aid) {
            self.id = String(intID)
        } else if let strID = try? c.decode(String.self, forKey: .aid) {
            self.id = strID
        } else {
            self.id = UUID().uuidString
        }

        // 字符串字段
        self.title           = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        self.categoryName    = (try? c.decodeIfPresent(String.self, forKey: .categoryName)) ?? ""
        self.subCategoryName = try? c.decodeIfPresent(String.self, forKey: .subCategoryName)

        // 图片 URL（后端返回完整 URL）
        let rawCover = try? c.decodeIfPresent(String.self, forKey: .musicImage)
        self.coverURL = APIConfiguration.imageURL(rawCover)

        // 音频 URL（后端返回完整 URL）
        let rawAudio = try? c.decodeIfPresent(String.self, forKey: .resourcePath)
        self.audioURL = rawAudio

        // 数值字段
        self.categoryId    = try? c.decodeIfPresent(Int.self, forKey: .categoryId)
        self.subCategoryId = try? c.decodeIfPresent(Int.self, forKey: .subCategoryId)

        // 布尔字段（兼容 Int / Bool）
        self.isCustomWhiteNoise = Self.bool(from: c, forKey: .isCustomWhiteNoise)
        self.isOrdinaryAudio    = Self.bool(from: c, forKey: .isOrdinaryAudio)
    }

    // MARK: - Private Helpers

    /// 解码 Bool，兼容 Bool / Int
    private static func bool(from c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Bool {
        if let boolVal = try? c.decodeIfPresent(Bool.self, forKey: key) {
            return boolVal
        }
        if let intVal = try? c.decodeIfPresent(Int.self, forKey: key) {
            return intVal != 0
        }
        return false
    }
}

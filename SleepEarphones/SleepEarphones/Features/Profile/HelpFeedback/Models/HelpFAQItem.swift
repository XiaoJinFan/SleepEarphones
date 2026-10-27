//
//  HelpFAQItem.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import Foundation

/// 帮助文章
///
/// ## 字段映射
/// | 本属性 | 后端字段 | 说明 |
/// |---|---|---|
/// | `id` | `aid` | 文章 ID（兼容 Int / String） |
/// | `categoryName` | `operationarticlecate_name` | 分类名（如"用户端-帮助中心"） |
/// | `title` | `title` | 文章标题（列表展示） |
/// | `imageURL` | `img_url` | 缩略图（已拼 CDN 前缀） |
/// | `synopsis` | `synopsis` | 简介（列表副标题） |
/// | `createTime` | `create_time` | 创建日期（字符串 `"2025-07-23"`） |
/// | `content` | `content` | 正文 HTML 片段（详情页展示） |
///
/// ## 调用方法
/// ```swift
/// // 通常由 HelpService.fetchHelpList 返回数组，业务层无需直接构造。
/// // 详情页使用：
/// let detailVC = HelpFAQDetailViewController(item: faqItem)
///
/// // 列表 Cell 使用：
/// cell.configure(title: item.title, subtitle: item.synopsis)
/// ```
///
/// ## 容错
/// 所有字段缺失时使用默认值兜底，任何单字段解码失败都不会影响整体。
struct HelpFAQItem: Decodable, Identifiable, Sendable {

    // MARK: - 核心字段

    /// 文章 ID（后端字段 `aid`）
    ///
    /// - Note: 后端返回 `Int`，此处统一转 `String` 便于 `Identifiable` 使用。
    let id: String

    /// 分类名（`operationarticlecate_name`）
    ///
    /// - Note: 当前未在 UI 展示（列表里都是同分类）。
    ///         保留便于未来按分类分组展示。
    let categoryName: String

    /// 文章标题（`title`）
    ///
    /// - 使用场景：列表主标题、详情页导航栏标题
    let title: String

    /// 缩略图 URL（`img_url`，已拼 CDN 前缀）
    ///
    /// - Note: 当前列表未使用（FAQCell 无图）。
    ///         保留便于未来列表增加缩略图。
    let imageURL: String?

    /// 简介（`synopsis`）
    ///
    /// - 使用场景：列表副标题（可选）
    let synopsis: String

    /// 创建日期（`create_time`）
    ///
    /// - Note: 后端返回格式为 `"2025-07-23"`。
    ///         若未来需要显示为相对时间，可在 UI 层格式化。
    let createTime: String

    /// 正文 HTML 片段（`content`）
    ///
    /// - Note: 是 HTML 片段（不是完整文档），
    ///         需用 `AgreementHTMLTemplate.wrap(_:)` 包装后加载到 WKWebView。
    let content: String

    // MARK: - 便捷判断

    /// 是否有正文内容
    ///
    /// - Returns: `content` 非空时为 `true`
    ///
    /// - Note: 详情页据此判断"无内容时是否跳转"。
    var hasContent: Bool {
        !content.isEmpty
    }

    /// 是否有简介（列表副标题）
    ///
    /// - Returns: `synopsis` 非空时为 `true`
    ///
    /// - Note: 与 `MessageModel.hasSubtitle` 语义一致，
    ///         命名沿用「synopsis → hasSynopsis」以免混淆。
    var hasSynopsis: Bool {
        !synopsis.isEmpty
    }

    /// 是否有缩略图
    ///
    /// - Returns: `imageURL` 非空时为 `true`
    var hasImage: Bool {
        guard let imageURL, !imageURL.isEmpty else { return false }
        return true
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case aid
        case operationarticlecateName = "operationarticlecate_name"
        case title
        case imgUrl                   = "img_url"
        case synopsis
        case createTime               = "create_time"
        case content
    }

    // MARK: - 自定义解码

    /// 显式解码，容错处理
    ///
    /// - Parameter decoder: 解码器
    /// - Throws: `DecodingError`（仅当根容器构造失败时）
    ///
    /// ## 容错语义
    /// - `id` 兼容 `Int` / `String`
    /// - 其余字段独立解码，缺失 / 类型不符均用默认值兜底
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // id —— 兼容 Int / String
        if let intID = try? c.decode(Int.self, forKey: .aid) {
            self.id = String(intID)
        } else if let strID = try? c.decode(String.self, forKey: .aid) {
            self.id = strID
        } else {
            self.id = ""
        }

        // 字符串字段 —— 逐个独立解码，缺失时用默认值
        //
        // - Note: `title` 默认值由 "帮助详情" 改为 "未命名文章"——
        //         前者在多条数据同时缺失时会全部显示同一个文案，识别度低。
        self.categoryName = Self.string(from: c, forKey: .operationarticlecateName, default: "")
        self.title        = Self.string(from: c, forKey: .title,                 default: "未命名文章")
        self.synopsis     = Self.string(from: c, forKey: .synopsis,              default: "")
        self.createTime   = Self.string(from: c, forKey: .createTime,            default: "")
        self.content      = Self.string(from: c, forKey: .content,               default: "")

        // img_url —— 拼 CDN 前缀
        let rawImg = try? c.decodeIfPresent(String.self, forKey: .imgUrl)
        self.imageURL = APIConfiguration.imageURL(rawImg)
    }

    // MARK: - Private Helpers

    /// 解码 `String`，缺失或空串时返回 `defaultValue`
    ///
    /// - Parameters:
    ///   - c: 解码容器
    ///   - key: 字段键
    ///   - defaultValue: 缺失 / 空串时的默认值
    /// - Returns: 解码结果或默认值
    private static func string(from c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys, default defaultValue: String) -> String {
        if let value = try? c.decodeIfPresent(String.self, forKey: key),
           !value.isEmpty {
            return value
        }
        return defaultValue
    }
}

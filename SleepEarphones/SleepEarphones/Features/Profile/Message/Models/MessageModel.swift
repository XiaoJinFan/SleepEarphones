//
//  MessageModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import UIKit
import Foundation

/// 消息模型（平台公告）
///
/// ## 字段映射
/// | 本属性 | 后端字段 | 说明 |
/// |---|---|---|
/// | `id` | `aid` | 消息 ID（兼容 Int / String） |
/// | `categoryName` | `operationarticlecate_name` | 分类名（如"用户端-平台公告"） |
/// | `title` | `title` | 消息标题 |
/// | `imageURL` | `img_url` | 缩略图（已拼 CDN 前缀） |
/// | `synopsis` | `synopsis` | 摘要（列表副标题，可能为空） |
/// | `createTime` | `create_time` | 创建时间 |
/// | `content` | `content` | 正文 HTML 片段（详情页展示） |
///
/// ## 调用方法
/// ```swift
/// // 通常由 MessageService.fetchMessageList 返回数组，业务层无需直接构造。
/// // 列表 Cell 使用：
/// if message.hasImage {
///     // 用 MessageImageCell（大卡片）
/// } else {
///     // 用 MessageCell（小卡片）
/// }
///
/// // 详情页使用：
/// let detailVC = MessageDetailViewController(message: message)
/// ```
///
/// ## 容错
/// 所有字段缺失时使用默认值兜底。
///
/// ## Sendable 说明
/// 本类型声明 `Sendable`：所有存储属性均为 `let` + 值类型 / `String?`。
/// `iconColor` 是**计算属性**（返回 `UIColor`），不参与 `Sendable` 检查——
/// 它每次调用都新建 / 从静态常量取色，不持有可变状态。
struct MessageModel: Decodable, Identifiable, Sendable {

    // MARK: - 核心字段

    /// 消息 ID（`aid`）
    ///
    /// - Note: 后端返回 `Int`，此处统一转 `String` 便于 `Identifiable` 使用。
    let id: String

    /// 分类名（`operationarticlecate_name`）
    let categoryName: String

    /// 消息标题（`title`）
    let title: String

    /// 缩略图 URL（`img_url`，已拼 CDN 前缀）
    ///
    /// - Note: 有图时列表用"大卡片"样式（`MessageImageCell`），
    ///         无图时用"小卡片"样式（`MessageCell`）。
    let imageURL: String?

    /// 摘要（`synopsis`）
    ///
    /// - Important: **可能为空字符串**（如"星曼睡眠耳机平台公告"）。
    ///              UI 层需**根据是否为空决定显隐副标题**，
    ///              不要用 `content` 顶替——那是详情页的职责。
    let synopsis: String

    /// 创建时间（`create_time`）
    let createTime: String

    /// 正文 HTML 片段（`content`）
    let content: String

    // MARK: - 展示辅助

    /// 是否有副标题
    ///
    /// - Returns: `synopsis` 非空时为 `true`
    ///
    /// - Note: `MessageImageCell` 据此隐藏副标题 label。
    var hasSubtitle: Bool {
        !synopsis.isEmpty
    }

    /// 是否为"有图"消息
    ///
    /// - Returns: `imageURL` 非空时为 `true`
    var hasImage: Bool {
        guard let imageURL, !imageURL.isEmpty else { return false }
        return true
    }

    /// 是否有正文内容
    ///
    /// - Returns: `content` 非空时为 `true`
    var hasContent: Bool {
        !content.isEmpty
    }

    // MARK: - 图标辅助（按分类映射）

    /// 分类对应的 SF Symbols 图标名
    ///
    /// - Returns: 如 `"bell.fill"` / `"questionmark.circle.fill"`
    var iconSymbolName: String {
        icon.symbolName
    }

    /// 分类对应的图标背景色
    ///
    /// - Returns: 走设计系统的语义色
    var iconColor: UIColor {
        icon.color
    }

    // MARK: - 图标映射

    /// 消息分类图标
    ///
    /// ## 判断规则（按 `categoryName` 关键字，大小写敏感）
    /// - 含"公告" → `bell.fill` / warning 橙
    /// - 含"帮助" → `questionmark.circle.fill` / info 蓝
    /// - 含"消息" → `envelope.fill` / success 绿
    /// - 其他 → `bell.fill` / warning 橙（兜底）
    ///
    private enum MessageIcon {
        case notice
        case help
        case message

        /// 从分类名推断图标类型
        ///
        /// - Parameter categoryName: 分类名
        /// - Returns: 匹配的图标类型；未匹配时返回 `.notice`（兜底）
        static func from(categoryName: String) -> MessageIcon {
            if categoryName.contains("公告") { return .notice }
            if categoryName.contains("帮助") { return .help }
            if categoryName.contains("消息") { return .message }
            return .notice   // 兜底
        }

        /// SF Symbols 图标名
        var symbolName: String {
            switch self {
            case .notice:  return "bell.fill"
            case .help:    return "questionmark.circle.fill"
            case .message: return "envelope.fill"
            }
        }

        /// 图标背景色（走设计系统的语义色，自动适配暗黑模式）
        var color: UIColor {
            switch self {
            case .notice:  return AppColor.Semantic.warning
            case .help:    return AppColor.Semantic.info
            case .message: return AppColor.Semantic.success
            }
        }
    }

    /// 当前消息对应的图标
    private var icon: MessageIcon {
        MessageIcon.from(categoryName: categoryName)
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

        // 字符串字段
        self.categoryName = Self.string(from: c, forKey: .operationarticlecateName, default: "平台公告")
        self.title        = Self.string(from: c, forKey: .title,                 default: "未命名消息")
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

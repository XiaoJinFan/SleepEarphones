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
/// | `categoryName` | `operationarticlecate_name` | 分类名（如 `"用户端-平台公告"`，**后端已本地化**） |
/// | `title` | `title` | 消息标题（**后端已本地化**） |
/// | `imageURL` | `img_url` | 缩略图（已拼 CDN 前缀） |
/// | `synopsis` | `synopsis` | 摘要（列表副标题，**后端已本地化**） |
/// | `createTime` | `create_time` | 创建时间 |
/// | `content` | `content` | 正文 HTML 片段（**后端已本地化**） |
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
struct MessageModel: Decodable, Identifiable, Sendable {

    // MARK: - 核心字段

    /// 消息 ID（`aid`）
    let id: String

    /// 分类名（`operationarticlecate_name`，**后端已本地化**）
    let categoryName: String

    /// 消息标题（`title`，**后端已本地化**）
    let title: String

    /// 缩略图 URL（`img_url`，已拼 CDN 前缀）
    let imageURL: String?

    /// 摘要（`synopsis`，**后端已本地化**）
    let synopsis: String

    /// 创建时间（`create_time`）
    let createTime: String

    /// 正文 HTML 片段（`content`，**后端已本地化**）
    let content: String

    // MARK: - 展示辅助

    /// 是否有副标题
    ///
    /// - Returns: `synopsis` 非空时为 `true`
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

    /// 分类对应的 SF Symbols 图标名（**不参与国际化**——图标本身无语言）
    ///
    /// - Returns: 如 `"bell.fill"` / `"questionmark.circle.fill"`
    var iconSymbolName: String {
        icon.symbolName
    }

    /// 分类对应的图标背景色（**不参与国际化**——颜色无语言）
    ///
    /// - Returns: 走设计系统的语义色
    var iconColor: UIColor {
        icon.color
    }

    // MARK: - 图标映射

    /// 消息分类图标
    private enum MessageIcon {
        case notice
        case help
        case message

        /// 从分类名推断图标类型
        ///
        /// - Parameter categoryName: 分类名（**后端已本地化**）
        /// - Returns: 匹配的图标类型；未匹配时返回 `.notice`（兜底）
        static func from(categoryName: String) -> MessageIcon {
            let lower = categoryName.lowercased()

            // 帮助（多语言关键字）
            let helpKeywords = ["帮助", "help", "aide", "ヘルプ", "hilfe"]
            if helpKeywords.contains(where: { lower.contains($0) }) {
                return .help
            }

            // 消息（多语言关键字）
            let messageKeywords = [
                "消息", "message", "nachricht", "メッセージ", "notification"
            ]
            if messageKeywords.contains(where: { lower.contains($0) }) {
                return .message
            }

            // 公告（多语言关键字）
            let noticeKeywords = [
                "公告", "announcement", "annonce", "お知らせ", "ankündigung"
            ]
            if noticeKeywords.contains(where: { lower.contains($0) }) {
                return .notice
            }

            // 兜底
            return .notice
        }

        /// SF Symbols 图标名（**不参与国际化**）
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

        // 字符串字段（**兜底文案用 LN 本地化**）
        self.categoryName = Self.string(
            from: c,
            forKey: .operationarticlecateName,
            default: LN("平台公告")
        )
        self.title = Self.string(
            from: c,
            forKey: .title,
            default: LN("未命名消息")
        )
        self.synopsis   = Self.string(from: c, forKey: .synopsis,   default: "")
        self.createTime = Self.string(from: c, forKey: .createTime, default: "")
        self.content    = Self.string(from: c, forKey: .content,    default: "")

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
    ///                   ——**若默认值会被展示给用户，调用方需传入 `LN(...)`
    ///                   已本地化的字符串**；若默认值是 `""`（不展示），直接传字面量
    /// - Returns: 解码结果或默认值
    private static func string(from c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys, default defaultValue: String) -> String {
        if let value = try? c.decodeIfPresent(String.self, forKey: key),
           !value.isEmpty {
            return value
        }
        return defaultValue
    }
}

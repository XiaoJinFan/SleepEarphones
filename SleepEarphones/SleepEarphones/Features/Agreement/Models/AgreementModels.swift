//
//  AgreementModels.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/16.
//

import Foundation

/// 协议 / 单页内容
///
/// ## 后端返回示例
/// ```json
/// {
///   "aid": 123,
///   "name": "用户注册协议",
///   "thumb_img": "uploads/thumb/xxx.jpg",
///   "content": "<p>欢迎使用...</p>",
///   "introduce": "用户注册协议摘要"
/// }
/// ```
///
/// ## 字段用途
/// | 字段 | 用途 |
/// |---|---|
/// | `aid` | 文章 ID（备用） |
/// | `name` | 页面标题（用于替换导航栏标题，**后端已按 Accept-Language 本地化**） |
/// | `thumbImg` | 缩略图路径（未使用，预留） |
/// | `content` | HTML 正文（核心字段，**后端已本地化**） |
/// | `introduce` | 简介（未使用，预留） |
///
/// ## 调用方法
/// ```swift
/// // 通常由 AgreementService.fetchAgreement 返回，业务层无需直接构造。
/// if content.hasContent {
///     webView.loadHTMLString(AgreementHTMLTemplate.wrap(content.content ?? ""), baseURL: nil)
/// }
/// if content.hasName { title = content.name }
/// ```
struct AgreementContent: Decodable, Sendable {

    // MARK: - Fields

    /// 文章 ID
    let aid: Int?

    /// 页面标题
    let name: String?

    /// 缩略图路径
    let thumbImg: String?

    /// 正文（HTML 片段）
    let content: String?

    /// 简介
    let introduce: String?

    // MARK: - 展示辅助

    /// 缩略图的完整 URL
    ///
    /// - Returns: 拼接 CDN 前缀后的完整 URL；`thumbImg` 为空时返回 nil
    ///
    var thumbImageURL: String? {
        APIConfiguration.imageURL(thumbImg)
    }

    /// 是否有标题
    ///
    /// - Returns: `name` 非空时为 `true`
    ///
    var hasName: Bool {
        guard let name else { return false }
        return !name.isEmpty
    }

    /// 是否有正文内容
    ///
    /// - Returns: `content` 非空时为 `true`
    ///
    var hasContent: Bool {
        guard let content else { return false }
        return !content.isEmpty
    }

    /// 是否有简介
    ///
    /// - Returns: `introduce` 非空时为 `true`
    ///
    var hasIntroduce: Bool {
        guard let introduce else { return false }
        return !introduce.isEmpty
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case aid
        case name
        case thumbImg = "thumb_img"
        case content
        case introduce
    }

    // MARK: - 自定义解码

    /// 显式解码，容错处理
    ///
    /// - Parameter decoder: 解码器
    /// - Throws: `DecodingError`（仅当 `keyedContainer` 构造失败时）
    ///
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // aid —— 兼容 Int / String
        if let intID = try? c.decode(Int.self, forKey: .aid) {
            self.aid = intID
        } else if let strID = try? c.decode(String.self, forKey: .aid),
                  let parsed = Int(strID) {
            self.aid = parsed
        } else {
            self.aid = nil
        }

        // 其余字段：逐个独立解码，缺失 / 类型不符均置 nil
        self.name      = try? c.decodeIfPresent(String.self, forKey: .name)
        self.thumbImg  = try? c.decodeIfPresent(String.self, forKey: .thumbImg)
        self.content   = try? c.decodeIfPresent(String.self, forKey: .content)
        self.introduce = try? c.decodeIfPresent(String.self, forKey: .introduce)
    }
}

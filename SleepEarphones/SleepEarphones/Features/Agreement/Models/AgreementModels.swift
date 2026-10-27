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
/// | `name` | 页面标题（用于替换导航栏标题） |
/// | `thumbImg` | 缩略图路径（未使用，预留） |
/// | `content` | HTML 正文（核心字段） |
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
    ///
    /// - Note: 兼容后端 `Int` / `String` 两种格式。
    ///         PHP 后端常把数字序列化成字符串，这层适配是必需的。
    let aid: Int?

    /// 页面标题
    ///
    /// - Note: `AgreementViewController` 用它替换导航栏标题。
    ///         若为空则保留进入页面时的 `customTitle`。
    let name: String?

    /// 缩略图路径
    ///
    /// - Note: 后端返回的是**相对路径**（如 `uploads/thumb/xxx.jpg`），
    ///         使用前需经 `thumbImageURL` 拼成完整 URL。
    let thumbImg: String?

    /// 正文（HTML 片段）
    ///
    /// - Note: 由 `AgreementHTMLTemplate.wrap(_:)` 包裹后加载到 `WKWebView`。
    ///         后端返回的是 **HTML 片段**（不是完整 HTML 文档）。
    let content: String?

    /// 简介
    ///
    /// - Note: 当前未使用（预留给未来的"协议摘要"展示）。
    let introduce: String?

    // MARK: - 展示辅助

    /// 缩略图的完整 URL
    ///
    /// - Returns: 拼接 CDN 前缀后的完整 URL；`thumbImg` 为空时返回 nil
    ///
    /// - Note: 复用 `APIConfiguration.imageURL(_:)`：
    ///   - `thumbImg` 为 nil / 空 → 返回 nil
    ///   - `thumbImg` 已是完整 URL → 原样返回
    ///   - `thumbImg` 是相对路径 → 拼接 CDN 前缀并 URL 编码
    var thumbImageURL: String? {
        APIConfiguration.imageURL(thumbImg)
    }

    /// 是否有标题
    ///
    /// - Returns: `name` 非空时为 `true`
    var hasName: Bool {
        guard let name else { return false }
        return !name.isEmpty
    }

    /// 是否有正文内容
    ///
    /// - Returns: `content` 非空时为 `true`
    ///
    /// - Note: 用于判断是否需要展示"暂无内容"占位。
    var hasContent: Bool {
        guard let content else { return false }
        return !content.isEmpty
    }

    /// 是否有简介
    ///
    /// - Returns: `introduce` 非空时为 `true`
    ///
    /// - Note: 预留给未来的"协议摘要"展示。
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
    /// ## 容错语义（重要）
    /// 使用 `try? c.decodeIfPresent(...)` 而非严格 `try`：
    /// - 字段**缺失** → 返回 `nil`（正常情况）
    /// - 字段**存在但类型不符**（如后端把 `name` 返回为数组）→ 也返回 `nil`
    ///
    /// 这是**有意的容错**——某个字段解码失败不应拖垮整个模型。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // aid —— 兼容 Int / String
        //
        // 优先级：Int > String（与后端实际返回频率、其他模型一致）
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

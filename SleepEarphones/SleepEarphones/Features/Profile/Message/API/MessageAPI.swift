//
//  MessageAPI.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import Foundation
import Alamofire

/// 消息中心接口
///
/// ## 接口说明
/// 后端 `6729cd8c2190d`（对应 `APIEndpoint.helpList`）是**通用文章列表接口**，
/// 通过 `operationarticlecate_id` 区分不同分类：
/// - `1` = 用户端-平台公告（本模块使用）
/// - `2` = 用户端-帮助中心（`HelpAPI` 使用）
///
/// - Important: 本接口与 `HelpAPI` **共用同一后端接口**（同一 `path`），
///              仅靠 `operationarticlecate_id` 区分返回内容。
///              若未来后端拆分接口，只需改各自的 `path`。
///
/// ## 返回结构
/// `data` 是**数组**（不是分页对象），每项是一条公告：
/// ```json
/// {
///   "aid": 32,
///   "title": "星曼睡眠耳机平台公告",
///   "synopsis": "",
///   "img_url": "https://...",
///   "content": "<p>...</p>",
///   "create_time": "2025-07-23",
///   "operationarticlecate_name": "用户端-平台公告"
/// }
/// ```
///
/// ## 调用方法
/// ```swift
/// // 1. 通过 Service 调用（推荐）
/// MessageService().fetchMessageList(categoryId: MessageAPI.noticeCategoryId)
///
/// // 2. 直接构造 API（单元测试 / 特殊场景）
/// let api = MessageAPI.list(categoryId: MessageAPI.noticeCategoryId)
/// client.request(api, as: [MessageModel].self)
/// ```
enum MessageAPI: APIRequest {

    // MARK: - Constants

    /// 平台公告分类 ID
    ///
    /// - Note: 后端返回的 `operationarticlecate_name: "用户端-平台公告"`
    ///         对应这个 ID。
    ///
    /// - Important: 该 ID 与 `HelpAPI.helpCenterCategoryId` **来自同一套后端分类表**——
    ///              若后端调整分类 ID，两处需同步更新。
    ///              未来若分类变多，可考虑抽到共享的 `ArticleCategory` 枚举。
    static let noticeCategoryId = 1

    // MARK: - Cases

    /// 拉取指定分类下的消息列表
    ///
    /// - Parameter categoryId: 分类 ID（见上方常量）
    case list(categoryId: Int)

    // MARK: - APIRequest

    /// 接口路径（与 `HelpAPI` 共用）
    var path: String {
        switch self {
        case .list:
            // 与 `HelpAPI.list` 共用同一接口，仅参数不同
            return APIEndpoint.helpList.rawValue
        }
    }

    /// HTTP 方法（后端约定用 POST，虽为查询语义）
    var method: HTTPMethod { .post }

    /// JSON body
    var encoding: ParameterEncoding { JSONEncoding.default }

    /// 请求参数
    ///
    /// - Returns: `["operationarticlecate_id": "N"]`
    ///
    /// - Note: ⚠️ 后端期望 String 类型（Postman 实测 body 是 `"1"` 而非 `1`）。
    var parameters: [String: Any]? {
        switch self {
        case .list(let categoryId):
            return ["operationarticlecate_id": "\(categoryId)"]
        }
    }
}

//
//  HelpAPI.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import Foundation
import Alamofire

/// 帮助中心接口
///
/// ## 接口说明
/// 后端 `6729cd8c2190d`（对应 `APIEndpoint.helpList`）是**通用文章列表接口**，
/// 通过 `operationarticlecate_id` 区分不同分类：
/// - `1` = 用户端-平台公告（`MessageAPI` 使用）
/// - `2` = 用户端-帮助中心（本模块使用）
///
/// - Important: 本接口与 `MessageAPI` **共用同一后端接口**（同一 `path`），
///              仅靠 `operationarticlecate_id` 区分返回内容。
///              若未来后端拆分接口，只需改各自的 `path`。
///
/// ## 返回结构
/// `data` 是**数组**（不是分页对象），每项是一篇帮助文章：
/// ```json
/// {
///   "aid": 31,
///   "title": "耳机充电盒使用帮助",
///   "synopsis": "耳机充电盒",
///   "img_url": "https://...",
///   "content": "<p>...</p>",
///   "create_time": "2025-07-23",
///   "operationarticlecate_name": "用户端-帮助中心"
/// }
/// ```
///
/// ## 调用方法
/// ```swift
/// // 1. 通过 Service 调用（推荐）
/// HelpService().fetchHelpList(categoryId: HelpAPI.helpCenterCategoryId)
///
/// // 2. 直接构造 API（单元测试 / 特殊场景）
/// let api = HelpAPI.list(categoryId: HelpAPI.helpCenterCategoryId)
/// client.request(api, as: [HelpFAQItem].self)
/// ```
enum HelpAPI: APIRequest {

    // MARK: - Constants

    /// 帮助中心分类 ID
    ///
    /// - Note: 后端返回的 `operationarticlecate_name: "用户端-帮助中心"`
    ///         对应这个 ID。若未来新增分类（如"设备故障"），在此追加常量。
    static let helpCenterCategoryId = 2

    // MARK: - Cases

    /// 拉取指定分类下的帮助文章列表
    ///
    /// - Parameter categoryId: 分类 ID（见上方常量）
    case list(categoryId: Int)

    // MARK: - APIRequest

    /// 接口路径（与 `MessageAPI` 共用）
    var path: String {
        switch self {
        case .list:
            // 与 `MessageAPI.list` 共用同一接口，仅参数不同
            return APIEndpoint.helpList.rawValue
        }
    }

    /// HTTP 方法（后端约定用 POST，虽为查询语义）
    var method: HTTPMethod { .post }

    /// JSON body（Postman 实测）
    var encoding: ParameterEncoding { JSONEncoding.default }

    /// 请求参数
    ///
    /// - Returns: `["operationarticlecate_id": "N"]`
    ///
    /// - Note: ⚠️ 后端期望 String 类型（Postman 实测 body 是 `"2"` 而非 `2`）。
    var parameters: [String: Any]? {
        switch self {
        case .list(let categoryId):
            return ["operationarticlecate_id": "\(categoryId)"]
        }
    }
}

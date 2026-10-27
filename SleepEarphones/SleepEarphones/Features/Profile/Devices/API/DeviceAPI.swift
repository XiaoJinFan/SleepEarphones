//
//  DeviceAPI.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/11.
//

import Foundation
import Alamofire
import Network

/// 设备相关接口
///
/// ## 字段命名
/// - 用户 ID：`user_id`（与后端约定）
/// - 分页：`page` / `list_rows`（不是 `pageSize`）
/// - 排序：`sort_field` / `sort_type`
///
enum DeviceAPI: APIRequest {

    // MARK: - Cases

    /// 查询指定用户的设备列表
    ///
    /// - Parameters:
    ///   - userId: 用户 ID（来自 `AuthStore.userId`，String 类型）
    ///   - page: 页码，从 1 开始
    ///   - pageSize: 每页条数，默认 15
    ///   
    case listByUser(userId: String, page: Int, pageSize: Int)

    // MARK: - APIRequest

    var path: String {
        switch self {
        case .listByUser:
            // 历史遗留：接口名是 "checkDevice" 但语义是"设备列表"
            // 后端未提供单独的 list 接口，此处沿用
            return APIEndpoint.checkDevice.rawValue
        }
    }

    var method: HTTPMethod { .get }

    var parameters: [String: Any]? {
        switch self {
        case .listByUser(let userId, let page, let pageSize):
            return [
                "user_id":    userId,
                "page":       page,
                "list_rows":  pageSize,        // ⚠️ 后端字段是 list_rows，不是 pageSize
                "sort_field": Self.defaultSortField,
                "sort_type":  Self.defaultSortType
            ]
        }
    }

    // MARK: - Constants

    /// 默认排序字段
    ///
    /// - Note: `aid` 是设备主键，按主键倒序 = 最新添加的在前
    private static let defaultSortField = "aid"

    /// 默认排序方向
    ///
    /// - Note: `desc` = 倒序（最新在前）
    private static let defaultSortType = "desc"
}

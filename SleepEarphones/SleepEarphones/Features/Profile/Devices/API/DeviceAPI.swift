//
//  DeviceAPI.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/11.
//

import Foundation
import Alamofire

/// 设备相关接口
///
/// ## 字段命名
/// - 用户 ID：`user_id`（与后端约定）
/// - 分页：`page` / `list_rows`（不是 `pageSize`）
/// - 排序：`sort_field` / `sort_type`
///
/// ## 认证（重要）
/// - **删除设备**（`auto/Freedevices/delete_devices`）：
///   后端网关要求必填 `user-token` Header，缺失会返回业务码 `-201`。
/// - **设备列表**（`auto/Freedevices/check_devices`）：
///   当前后端接受 `user_id` 参数识别用户，未强制要求 token——
///   为最小改动保持原样。若未来后端统一鉴权，把 `listByUser` 也改为
///   走 `authHeaders` 即可（见 `headers` 注释）。
enum DeviceAPI: APIRequest {

    // MARK: - Cases

    /// 查询指定用户的设备列表
    ///
    /// - Parameters:
    ///   - userId: 用户 ID（来自 `AuthStore.userId`，String 类型）
    ///   - page: 页码，从 1 开始
    ///   - pageSize: 每页条数，默认 15
    case listByUser(userId: String, page: Int, pageSize: Int)

    /// 删除设备
    ///
    /// - Parameter aid: 设备 ID（对应 `DeviceModel.id`）
    ///
    /// - Important: 后端要求必填 Header `user-token`——
    ///              由 `headers` 属性统一注入。
    case deleteDevice(aid: String)

    // MARK: - APIRequest

    var path: String {
        switch self {
        case .listByUser:
            // 历史遗留：接口名是 "checkDevice" 但语义是"设备列表"
            // 后端未提供单独的 list 接口，此处沿用
            return APIEndpoint.checkDevice.rawValue
        case .deleteDevice:
            return APIEndpoint.deleteDevice.rawValue
        }
    }

    var method: HTTPMethod {
        switch self {
        case .listByUser:
            return .get
        case .deleteDevice:
            // 后端物理地址 `auto/Freedevices/delete_devices` 使用 POST
            return .post
        }
    }

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
        case .deleteDevice(let aid):
            return ["aid": aid]
        }
    }

    /// 请求头（按 case 分派）
    /// 
    /// - **删除设备**：后端网关强制要求 `user-token`（见接口截图"必填"标记）
    /// - **设备列表**：后端当前用 `user_id` 参数识别用户，未强制 token
    ///
    var headers: HTTPHeaders? {
        switch self {
        case .listByUser:
            return nil

        case .deleteDevice:
            guard let token = AuthStore.shared.token, !token.isEmpty else {
                AppLog.device.debug(
                    "DeviceAPI.deleteDevice 未携带 user-token（本地无登录凭证）"
                )
                return nil
            }
            return ["user-token": token]
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

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
/// ## 字段命名（后端约定，与常规不同）
/// - 用户 ID：`user_id`（与后端约定）
/// - 分页：`page` / **`list_rows`**（不是 `pageSize`）
/// - 排序：`sort_field` / `sort_type`
///
/// ## 认证（重要：两个接口不同）
/// | 接口 | 认证方式 |
/// |---|---|
/// | **设备列表**（`auto/Freedevices/check_devices`） | `user_id` 参数识别用户，**未强制要求 token** |
/// | **删除设备**（`auto/Freedevices/delete_devices`） | **强制要求** `user-token` header（缺失会返回 `-201`） |
///
/// - Important: 这个差异是**后端当前接口契约**决定的，不是设计缺陷——
///              若未来后端统一鉴权，只需修改 `headers` 的实现。
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
            // 查询语义 → GET
            return .get

        case .deleteDevice:
            // 后端物理地址 `auto/Freedevices/delete_devices` 使用 POST
            // （虽为删除语义，但后端设计为 POST）
            return .post
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .listByUser(let userId, let page, let pageSize):
            return [
                "user_id":    userId,
                "page":       page,
                // ⚠️ 后端字段是 `list_rows` 而非 `pageSize`——
                //    这是后端历史遗留，**不要**改为 `pageSize`
                "list_rows":  pageSize,
                "sort_field": Self.defaultSortField,
                "sort_type":  Self.defaultSortType
            ]

        case .deleteDevice(let aid):
            return ["aid": aid]
        }
    }

    /// 请求头（按 case 分派）
    var headers: HTTPHeaders? {
        switch self {
        case .listByUser:
            // 当前后端接受 `user_id` 参数识别用户，不强制 token
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
    private static let defaultSortField = "aid"

    /// 默认排序方向
    private static let defaultSortType = "desc"
}

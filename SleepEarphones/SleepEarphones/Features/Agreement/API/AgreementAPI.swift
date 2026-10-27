//
//  AgreementAPI.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/16.
//

import Foundation
import Alamofire

/// 协议 / 单页内容接口
///
/// ## 职责
/// 后端所有单页（用户协议、隐私政策、未来可能新增的其他协议）
/// **共用同一接口**（`APIEndpoint.privacyPolicy`），
/// 通过 `column_id` 参数区分返回内容。
///
/// ## 调用方法
/// ```swift
/// // 1. 通过 Service 调用（推荐）
/// AgreementService.shared.fetchAgreement(columnId: 9)
///
/// // 2. 直接构造 API 请求（单元测试 / 特殊场景）
/// let api = AgreementAPI.getColumn(columnId: 9)
/// client.request(api, as: AgreementContent.self)
/// ```
///
/// ## 相关文件
/// - `AgreementAPI.ColumnID`：column_id 数值的**唯一来源**
/// - `AgreementLinks`：协议 URL 拼装（从 `ColumnID` 取数值）
/// - `AgreementNavigation`：URL 反查 column_id + 标题映射
///
/// - Important: **新增协议类型的操作清单**：
///   1. 在 `ColumnID` 增加常量（与后端确认数值）
///   2. 在 `AgreementLinks` 增加对应 URL 拼装
///   3. 在 `AgreementNavigation.meta(for:)` 的 switch 里增加标题分支
///
/// 三处必须同步，否则 URL 解析 / 标题映射会出现不一致。
enum AgreementAPI: APIRequest {

    // MARK: - Column ID

    /// 单页 ID 常量
    ///
    /// - Note: 数值需与后端约定一致。
    ///
    /// - Important: **本项目 column_id 的唯一来源**。
    ///              `AgreementLinks` 与 `AgreementNavigation` 都引用本枚举，
    ///              不要在其他地方硬编码 column_id 数值。
    enum ColumnID {

        /// 用户注册协议
        static let userAgreement = 9

        /// 隐私政策
        static let privacyPolicy = 10
    }

    // MARK: - Cases

    /// 获取协议 / 单页内容
    ///
    /// - Parameter columnId: 单页 KID；传 `nil` 时后端返回默认协议
    case getColumn(columnId: Int?)

    // MARK: - APIRequest

    /// 接口路径（所有单页共用同一后端接口）
    var path: String {
        switch self {
        case .getColumn:
            // 后端所有单页共用同一接口，通过 column_id 区分
            return APIEndpoint.privacyPolicy.rawValue
        }
    }

    /// HTTP 方法
    ///
    /// - Note: 后端约定用 **POST**（虽为查询语义但接口设计如此）。
    ///         **不要**改为 GET——会返回 405。
    var method: HTTPMethod { .post }

    /// 参数编码方式
    ///
    /// - Note: 与 `method = .post` 配套，使用 JSON body。
    ///         参数结构：`{"column_id": 9}`
    var encoding: ParameterEncoding { JSONEncoding.default }

    /// 请求参数
    ///
    /// - Returns: 当 `columnId` 非 nil 时返回 `["column_id": N]`；否则返回 `nil`
    ///
    /// - Note: `columnId` 为 nil 时**不传** `column_id` 字段——
    ///         后端将返回默认协议；若传空值后端可能报参数校验错误。
    var parameters: [String: Any]? {
        switch self {
        case .getColumn(let columnId):
            guard let columnId else { return nil }
            return ["column_id": columnId]
        }
    }
}

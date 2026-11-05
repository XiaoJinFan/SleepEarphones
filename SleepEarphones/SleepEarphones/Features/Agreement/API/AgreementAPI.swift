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
enum AgreementAPI: APIRequest {

    // MARK: - Column ID

    /// 单页 ID 常量
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
    var method: HTTPMethod { .post }

    /// 参数编码方式
    var encoding: ParameterEncoding { JSONEncoding.default }

    /// 请求参数
    ///
    /// - Returns: 当 `columnId` 非 nil 时返回 `["column_id": N]`；否则返回 `nil`
    ///
    var parameters: [String: Any]? {
        switch self {
        case .getColumn(let columnId):
            guard let columnId else { return nil }
            return ["column_id": columnId]
        }
    }
}

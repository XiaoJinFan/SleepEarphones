//
//  AccountCancelAPI.swift
//  SleepEarphones
//

import Foundation
import Alamofire
import Combine

enum AccountCancelAPI: APIRequest {
    /// 获取注销状态
    case getStatus
    /// 获取注销原因列表
    case getReasons
    /// 提交注销申请
    case submit(cancelType: String, cancelReason: String)
    /// 撤销注销申请
    case cancelSubmit
    
    var path: String {
        switch self {
        case .getStatus:   return APIEndpoint.getUserCancel.rawValue
        case .getReasons:  return APIEndpoint.logoutReason.rawValue
        case .submit:      return APIEndpoint.logoutSubmit.rawValue
        case .cancelSubmit: return APIEndpoint.cancelLogout.rawValue
        }
    }
    
    var method: HTTPMethod { .post }
    var encoding: ParameterEncoding { JSONEncoding.default }
    
    var parameters: [String: Any]? {
        switch self {
        case .getStatus, .getReasons, .cancelSubmit:
            return nil
            
        case .submit(let cancelType, let cancelReason):
            return [
                "cancel_type": cancelType,
                "cancel_reason": cancelReason,
                "type": "user" // ✅ 修复：补充图4要求的必填参数
            ]
        }
    }
    
    var headers: HTTPHeaders? {
        guard let token = AuthStore.shared.token, !token.isEmpty else { return nil }
        return ["user-token": token]
    }
}

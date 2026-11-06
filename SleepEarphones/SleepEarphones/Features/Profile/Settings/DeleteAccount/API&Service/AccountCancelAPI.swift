//
//  AccountCancelAPI.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/11/5.
//

import Foundation
import Alamofire
import Combine

enum AccountCancelAPI: APIRequest {
    /// 获取注销状态
    case getStatus
    /// 获取注销原因列表（复用已有的 logoutReason）
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
                "cancel_reason": cancelReason
            ]
        }
    }
    
    var headers: HTTPHeaders? {
        guard let token = AuthStore.shared.token, !token.isEmpty else { return nil }
        return ["user-token": token]
    }
}

// MARK: - Service

protocol AccountCancelServiceProtocol: Sendable {
    func fetchStatus() -> AnyPublisher<AccountCancelInfo?, NetworkError>
    func fetchReasons() -> AnyPublisher<[String], NetworkError> // 假设返回字符串数组
    func submit(cancelType: String, cancelReason: String) -> AnyPublisher<Void, NetworkError>
    func cancelSubmit() -> AnyPublisher<Void, NetworkError>
}

final class AccountCancelService: AccountCancelServiceProtocol, Sendable {
    private let client: NetworkClientProtocol
    
    init(client: NetworkClientProtocol = NetworkClient()) {
        self.client = client
    }
    
    func fetchStatus() -> AnyPublisher<AccountCancelInfo?, NetworkError> {
        // 注意：如果接口没数据，可能返回 null，这里用 Optional 包装
        client.request(AccountCancelAPI.getStatus, as: AccountCancelInfo?.self)
            .eraseToAnyPublisher()
    }
    
    func fetchReasons() -> AnyPublisher<[String], NetworkError> {
        // ⚠️ TODO: 根据实际 logoutReason 接口返回格式修改，这里假设返回纯字符串数组
        client.request(AccountCancelAPI.getReasons, as: [String].self)
            .eraseToAnyPublisher()
    }
    
    func submit(cancelType: String, cancelReason: String) -> AnyPublisher<Void, NetworkError> {
        client.request(AccountCancelAPI.submit(cancelType: cancelType, cancelReason: cancelReason), as: EmptyResponse.self)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    func cancelSubmit() -> AnyPublisher<Void, NetworkError> {
        client.request(AccountCancelAPI.cancelSubmit, as: EmptyResponse.self)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}

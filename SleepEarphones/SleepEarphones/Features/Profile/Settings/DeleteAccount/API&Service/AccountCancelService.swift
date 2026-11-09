//
//  AccountCancelService.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/11/6.
//

import Foundation
import Combine

protocol AccountCancelServiceProtocol: Sendable {
    func fetchStatus() -> AnyPublisher<AccountCancelInfo?, NetworkError>
    func fetchReasons() -> AnyPublisher<[CancelReason], NetworkError>
    func submit(cancelType: String, cancelReason: String) -> AnyPublisher<Void, NetworkError>
    func cancelSubmit() -> AnyPublisher<Void, NetworkError>
}

final class AccountCancelService: AccountCancelServiceProtocol, Sendable {
    private let client: NetworkClientProtocol
    
    init(client: NetworkClientProtocol = NetworkClient()) {
        self.client = client
    }
    
    func fetchStatus() -> AnyPublisher<AccountCancelInfo?, NetworkError> {
        // 接口可能无数据返回 null，用 Optional 包装
        client.request(AccountCancelAPI.getStatus, as: AccountCancelInfo?.self)
            .eraseToAnyPublisher()
    }
    
    func fetchReasons() -> AnyPublisher<[CancelReason], NetworkError> {
        // ✅ 修复：使用规范的原因模型
        client.request(AccountCancelAPI.getReasons, as: [CancelReason].self)
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

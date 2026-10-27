//
//  APIResponse.swift
//  Network
//
//  Created by 肖进凡 on 2026/9/11.
//

import Foundation

/// 后端统一响应结构
///
/// ## 调用方法
/// ```swift
/// // 通常由 NetworkClient 内部使用，业务层无需直接构造。
/// let response: APIResponse<UserModel> = ...
/// if response.isSuccess { use(response.data) }
/// if response.isTokenExpired { logout() }
/// if let err = response.decodeError { log(err) }
/// ```
public struct APIResponse<T: Decodable>: Decodable {

    // MARK: - Fields

    /// 业务状态码（已统一为 Int）
    public let code: Int

    /// 业务消息
    public let msg: String?

    /// 业务数据（解码成功时非 nil）
    public let data: T?

    /// 数据解码错误（仅当 `data` 字段存在但解码失败时非 nil）
    ///
    /// - Note: 这个字段**不参与** Decodable 解码，仅作为诊断信息向上层暴露。
    ///         上层可据此区分"空数据"与"解码失败"。
    ///
    /// - Important: 类型是 `any Error`，Swift 6 下不是 `Sendable`。
    ///              但本字段只作为诊断用，不参与跨 actor 的逻辑判断，
    ///              因此 `APIResponse` 用 `@unchecked Sendable` 声明。
    public let decodeError: Error?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case code, msg, data
    }

    // MARK: - 自定义解码

    /// 从 JSON 解码，兼容多种 `code` 格式
    ///
    /// - Parameter decoder: Swift 解码器
    /// - Throws: 无（本方法内部容错，不抛出）
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 1. code —— 兼容 Int / String / Bool / Double
        self.code = Self.decodeCode(from: container)

        // 2. msg —— 可能为 null、空字符串或缺失
        self.msg = try? container.decodeIfPresent(String.self, forKey: .msg)

        // 3. data —— 区分「缺失」与「解码失败」两种情况
        if container.contains(.data) {
            do {
                self.data = try container.decodeIfPresent(T.self, forKey: .data)
                self.decodeError = nil
            } catch {
                self.data = nil
                self.decodeError = error
            }
        } else {
            self.data = nil
            self.decodeError = nil
        }
    }

    // MARK: - 便捷判断

    /// 是否请求成功（成功码从 `APIConfiguration.successCodes` 读取）
    public var isSuccess: Bool {
        APIConfiguration.successCodes.contains(code)
    }

    /// 是否为 Token 失效
    public var isTokenExpired: Bool {
        code == APIConfiguration.tokenErrorCode
    }

    // MARK: - Private Helpers

    /// 统一解析 `code` 字段
    ///
    /// - Parameter container: 解码容器
    /// - Returns: 解析后的 Int 值；全部失败时返回 -1
    ///
    /// - Note: 解码优先级 `Int → String → Bool → Double`，
    ///         与后端实际返回值频率一致。
    ///         返回 -1 是为了走业务失败分支（而非成功码）。
    private static func decodeCode(from container: KeyedDecodingContainer<CodingKeys>) -> Int {
        // 1. Int（最常见）
        if let intCode = try? container.decode(Int.self, forKey: .code) {
            return intCode
        }
        // 2. String（PHP 接口常序列化成字符串）
        if let strCode = try? container.decode(String.self, forKey: .code),
           let parsed = Int(strCode) {
            return parsed
        }
        // 3. Bool（部分新接口）
        if let boolCode = try? container.decode(Bool.self, forKey: .code) {
            return boolCode ? 1 : 0
        }
        // 4. Double（偶发：1.0 / 200.0）
        if let doubleCode = try? container.decode(Double.self, forKey: .code) {
            return Int(doubleCode)
        }
        // 5. 极端情况：code 缺失或类型完全不符，标记为 -1（走业务失败分支）
        return -1
    }
}

// MARK: - Sendable

extension APIResponse: @unchecked Sendable where T: Sendable {}

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
///
/// ## 与后台错误码表的对应
/// | code | 含义 | 本类判断 |
/// |---|---|---|
/// | `1` | 操作成功 | `isSuccess == true` |
/// | `0` | 操作失败 | `isSuccess == false` |
/// | `-201` | 缺少 UserToken | `isTokenExpired == true` |
/// | `-202` | UserToken 无效 | `isTokenExpired == true` |
/// | `-203` | UserToken 过期 | `isTokenExpired == true` |
/// | `-300` | 异地登录 | `isTokenExpired == true` |
/// | `-800` | 没有数据 | `isNoData == true` |
/// | `-900` | 参数错误 | `isSuccess == false` |
/// | `-999` | 系统错误 | `isSuccess == false` |
public struct APIResponse<T: Decodable>: Decodable {

    // MARK: - Fields

    /// 业务状态码（已统一为 Int）
    ///
    /// - Note: 后端可能以 `Int` / `String` / `Bool` / `Double` 返回，
    ///         本类内部解码时会归一化为 `Int`。
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

    /// 是否请求成功
    ///
    /// - Returns: `code == 1` 时为 `true`
    ///
    /// - Important: 后台错误码表明确规定 `0 = 操作失败`，
    ///              因此 **只有 `1` 视为成功**。
    ///              （历史版本曾把 `0` / `200` 也当作成功，
    ///              会导致失败响应被误判为成功，已修正。）
    public var isSuccess: Bool {
        APIConfiguration.successCodes.contains(code)
    }

    /// 是否为"登录态失效"
    ///
    /// - 覆盖 4 种后端业务场景：
    ///   - `-201` 缺少 UserToken
    ///   - `-202` UserToken 无效
    ///   - `-203` UserToken 过期
    ///   - `-300` 异地登录
    ///
    /// - Note: 命中后业务层应清除凭证并跳转登录页。
    ///         具体提示文案可由上层根据 `code` 区分
    ///         （如 `-300` 显示"您的账号在别处登录"）。
    public var isTokenExpired: Bool {
        APIConfiguration.tokenErrorCodes.contains(code)
    }

    /// 是否为"没有数据"（业务正常但内容为空）
    ///
    /// - 对应后端 `-800`。与"业务失败"不同——这不算错误，
    ///   通常是列表无数据 / 详情不存在，UI 层显示空态即可。
    public var isNoData: Bool {
        code == APIConfiguration.noDataCode
    }

    // MARK: - Private Helpers

    /// 统一解析 `code` 字段
    ///
    /// - Parameter container: 解码容器
    /// - Returns: 解析后的 Int 值；全部失败时返回 `-999`（系统错误）
    ///
    /// - Note: 解码优先级 `Int → String → Bool → Double`，
    ///         与后端实际返回值频率一致。
    ///         全部失败时返回 `-999` 而非 `-1`——
    ///         `-999` 是后端错误码表里定义的"系统错误"，
    ///         语义明确、便于日志排查；而 `-1` 不在错误码表中，
    ///         容易与自定义错误码混淆。
    private static func decodeCode(from container: KeyedDecodingContainer<CodingKeys>) -> Int {
        // 1. Int（最常见）
        if let intCode = try? container.decode(Int.self, forKey: .code) {
            return intCode
        }
        // 2. String（PHP 接口常序列化成字符串，如 `"1"`）
        if let strCode = try? container.decode(String.self, forKey: .code),
           let parsed = Int(strCode) {
            return parsed
        }
        // 3. Bool（部分新接口；true → 1, false → 0）
        if let boolCode = try? container.decode(Bool.self, forKey: .code) {
            return boolCode ? 1 : 0
        }
        // 4. Double（偶发：1.0 / 200.0）
        if let doubleCode = try? container.decode(Double.self, forKey: .code) {
            return Int(doubleCode)
        }
        // 5. 极端情况：code 缺失或类型完全不符 → 系统错误
        AppLog.network.error("APIResponse.code 解码失败，回退为 -999（系统错误）")
        return APIConfiguration.systemErrorCode
    }
}

// MARK: - Sendable

extension APIResponse: @unchecked Sendable where T: Sendable {}

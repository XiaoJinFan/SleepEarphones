//
//  APIConfiguration.swift
//  Network
//
//  Created by 肖进凡 on 2026/9/16.
//

import Foundation

/// 后台服务全局配置
///
/// ## 调用方法
/// ```swift
/// // 1. 接口基础前缀（APIRequest 默认 baseURL 使用）
/// let prefix = APIConfiguration.serverPrefix
/// // → "https://admin.xing-man.com/api/m12323"
///
/// // 2. 图片 URL 拼接
/// let fullURL = APIConfiguration.imageURL("uploads/xxx.jpg")
/// // → "http://miaopinyouyue.oss-cn-hangzhou.aliyuncs.com/uploads/xxx.jpg"
///
/// // 3. 业务状态码判定
/// if APIConfiguration.successCodes.contains(code) { ... }
///
/// // 4. Token 失效判定（含 4 种场景）
/// if APIConfiguration.tokenErrorCodes.contains(code) { ... }
/// ```
enum APIConfiguration {

    // MARK: - 域名与租户

    /// API 服务根地址
    ///
    /// - Important: 必须以 `/` 结尾，否则 `serverPrefix` 拼接会出错。
    static let apiDomain = "https://admin.xing-man.com/api/"

    /// 租户 / 项目 ID
    ///
    /// - Note: 生产环境应从配置中心 / Keychain 读取，便于多环境切换。
    static let memberId = "12323"

    /// 业务接口前缀：`https://admin.xing-man.com/api/m12323`
    ///
    /// - Note:
    ///   - **不带尾斜杠**，拼接交给 `URLBuilder` 规范化处理。
    ///   - 从计算属性改为 `static let`：拼接只发生一次。
    static let serverPrefix: String = "\(apiDomain)m\(memberId)"

    /// 图片 CDN 根地址
    ///
    /// - Warning: 当前为 `http://`（非 https）。若线上 App 开启了 ATS，
    ///            需在 `Info.plist` 的 `NSAppTransportSecurity` 中
    ///            为该域名加白名单，否则图片会加载失败。
    static let imageCDN = "http://miaopinyouyue.oss-cn-hangzhou.aliyuncs.com/"

    // MARK: - 网络默认参数

    /// 接口默认超时（秒）
    static let defaultTimeout: TimeInterval = 15

    // MARK: - 业务状态码（与后台错误码表对齐）

    /// 成功码
    ///
    /// - Important: 后台错误码表明确规定：
    ///   - `1` = **操作成功**
    ///   - `0` = **操作失败**（旧版曾误将 0 归为成功，已修正）
    ///   - `200` = **不是本后端的业务成功码**（是 HTTP 状态码，勿混用）
    ///
    /// 因此成功码集合**只有** `[1]`。若未来后端约定变化，
    /// 在此处集中修改即可。
    static let successCodes: Set<Int> = [1]

    /// 业务错误码 — 缺少 UserToken（未登录 / 未携带 token）
    static let missingTokenCode = -201

    /// 业务错误码 — UserToken 无效（格式错误 / 已失效）
    static let invalidTokenCode = -202

    /// 业务错误码 — UserToken 过期（有效期已过）
    static let expiredTokenCode = -203

    /// 业务错误码 — 异地登录（当前 token 被其他设备顶下线）
    ///
    /// - Note: 业务上建议给用户更明确的提示（"您的账号在别处登录"），
    ///         但当前 `NetworkError` 未细分该 case，统一按 `.tokenExpired` 处理，
    ///         用户会看到"登录已过期，请重新登录"——可接受。
    static let remoteLoginCode = -300

    /// 业务错误码 — 没有数据
    static let noDataCode = -800

    /// 业务错误码 — 参数错误
    static let parameterErrorCode = -900

    /// 业务错误码 — 系统错误
    static let systemErrorCode = -999

    /// 所有需要"重新登录"的业务错误码
    ///
    /// - Important: 命中任一码都视为"当前登录态失效"，
    ///              应清除本地凭证并跳转登录页。
    static let tokenErrorCodes: Set<Int> = [
        missingTokenCode,
        invalidTokenCode,
        expiredTokenCode,
        remoteLoginCode
    ]

    // MARK: - HTTP 状态码

    /// HTTP 401 Unauthorized — 标准未授权状态码
    ///
    /// - Note: 与业务码 `-201/-202/-203` **不同**：
    ///         - 业务码：后端处理成功但业务失败（HTTP 200 + `code = -202`）
    ///         - HTTP 401：后端在网关 / 中间件层直接拒绝（HTTP 401）
    ///
    ///         两种场景都需要跳登录页，但识别路径不同。
    static let httpUnauthorizedCode = 401

    // MARK: - 通用文案

    /// 服务端异常时的兜底提示
    static let serverErrorMessage = "您的网络不稳定，请稍后重试"

    // MARK: - 图片地址

    /// 构建完整图片地址
    ///
    /// - Parameter path: 相对路径或完整 URL；传 `nil` / 空字符串时返回 `nil`
    /// - Returns: 完整可用的图片 URL 字符串
    static func imageURL(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }

        // 已是完整 URL：直接返回
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return path
        }

        // 相对路径：URL 编码后拼接
        let encoded = path.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? path
        return "\(imageCDN)\(encoded)"
    }
}

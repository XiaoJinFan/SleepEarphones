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
    ///
    ///            建议与后端协商切换到 https：
    ///            OSS 支持 https 域名（`https://<bucket>.oss-cn-hangzhou.aliyuncs.com/`）
    static let imageCDN = "http://miaopinyouyue.oss-cn-hangzhou.aliyuncs.com/"

    // MARK: - 网络默认参数

    /// 接口默认超时（秒）
    static let defaultTimeout: TimeInterval = 15

    // MARK: - 业务状态码

    /// 成功码（兼容 `1` / `200` / `0` 三种约定）
    static let successCodes: Set<Int> = [1, 200, 0]

    /// Token 失效码
    static let tokenErrorCode = 401

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
        //
        // - Note: `urlPathAllowed` 保留 `/`、`?`、`#` 等路径分隔符，
        //         但会对空格、中文等进行编码。
        let encoded = path.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? path
        return "\(imageCDN)\(encoded)"
    }
}

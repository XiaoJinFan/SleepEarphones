//
//  AuthAPI.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/17.
//

import Foundation
import Alamofire

/// 认证相关接口
///
/// ## 调用方法
/// ```swift
/// // 1. 密码登录
/// let api = AuthAPI.passwordLogin(account: "138...", accountType: .mobile, password: "abc123")
///
/// // 2. 验证码登录
/// let api = AuthAPI.codeLogin(account: "138...", accountType: .mobile, code: "1234")
///
/// // 3. 发送验证码
/// let api = AuthAPI.sendSmsCode(account: "138...", accountType: .mobile, scene: .register)
///
/// // 4. 由 NetworkClient 统一发起请求
/// client.request(api, as: LoginResult.self)
/// ```
///
/// ## 参数命名约定（重点）
/// 后端字段命名不统一，本文件用注释明确标出每处的差异。
///
/// | 字段 | 密码登录 | 验证码登录 | 发送验证码 | 注册 | 忘记密码 |
/// |---|---|---|---|---|---|
/// | 账号 | `account` | `mobile` / `email` | `mobile` / `user_email` | `mobile` / `email` | `account` |
/// | 账号类型 | `account_type` | — | — | — | `account_type` |
/// | 场景类型 | — | `type` | `type` | `type` | `type` |
///
/// - Important: **邮箱字段名依接口而异**：
///   - 发送验证码 → `user_email`
///   - 验证码登录 / 注册 → `email`
///   这是后端历史遗留，已用 Postman 验证。
///   若后端未来统一字段名，修改 `accountField(_:type:context:)` 即可。
enum AuthAPI: APIRequest {

    // MARK: - Constants

    /// DEBUG 下开启"测试模式"标志
    ///
    /// ## 作用
    /// `sendSmsCode` 接口在测试模式下：
    /// - 服务端**不发真实短信**
    /// - 在 `data: {code: 1234}` 里返回验证码
    /// - 客户端可自动填充，实现秒级调试
    ///
    /// ## 开关
    /// - DEBUG 构建：`1`（测试模式）
    /// - Release 构建：`nil`（不发该字段）
    ///
    /// - Warning: Release 构建**绝不能**带此字段——
    ///            否则线上用户会收到测试验证码而非真实短信。
    ///            本字段用 `#if DEBUG` 编译期隔离，保证 Release 不会误带。
    private static let smsTestFlag: Int? = {
        #if DEBUG
        return 1
        #else
        return nil
        #endif
    }()

    // MARK: - Cases

    /// 账号密码登录
    ///
    /// - Parameters:
    ///   - account: 账号（手机号 / 邮箱 / 用户名）
    ///   - accountType: 账号类型
    ///   - password: 密码（明文，HTTPS 传输）
    case passwordLogin(account: String,
                       accountType: AccountType,
                       password: String)

    /// 验证码登录
    ///
    /// - Parameters:
    ///   - account: 手机号 / 邮箱
    ///   - accountType: 账号类型
    ///   - code: 验证码
    case codeLogin(account: String,
                   accountType: AccountType,
                   code: String)

    /// 发送验证码
    ///
    /// - Parameters:
    ///   - account: 接收验证码的手机号 / 邮箱
    ///   - accountType: 账号类型
    ///   - scene: 业务场景
    case sendSmsCode(account: String,
                     accountType: AccountType,
                     scene: SmsScene)

    /// 忘记密码 / 重置密码
    ///
    /// - Parameters:
    ///   - account: 账号
    ///   - accountType: 账号类型
    ///   - newPassword: 新密码
    ///   - code: 验证码（可为 nil）
    case forgetPassword(account: String,
                        accountType: AccountType,
                        newPassword: String,
                        code: String?)

    /// 会员注册
    ///
    /// - Parameters:
    ///   - account: 手机号 / 邮箱
    ///   - accountType: 账号类型
    ///   - password: 密码
    ///   - code: 验证码（可为 nil）
    case register(account: String,
                  accountType: AccountType,
                  password: String,
                  code: String?)

    // MARK: - APIRequest

    /// 接口路径
    var path: String {
        switch self {
        case .passwordLogin:  return APIEndpoint.login.rawValue
        case .codeLogin:      return APIEndpoint.codeLogin.rawValue
        case .sendSmsCode:    return APIEndpoint.smsCode.rawValue
        case .forgetPassword: return APIEndpoint.forgetPassword.rawValue
        case .register:       return APIEndpoint.register.rawValue
        }
    }

    /// HTTP 方法（全部 POST）
    var method: HTTPMethod { .post }

    /// 认证接口统一使用 JSON 请求体
    var encoding: ParameterEncoding { JSONEncoding.default }

    /// 请求参数（依 case 分派）
    var parameters: [String: Any]? {
        switch self {

        // MARK: 账号密码登录
        //
        // 请求：`{"account": "...", "account_type": "mobile",
        //         "password": "...", "user_source": "IOS", "client_id": "..."}`
        case .passwordLogin(let account, let type, let password):
            var p = makeBaseParameters(includeClientID: true)
            p["account"]      = account
            p["account_type"] = type.rawValue
            p["password"]     = password
            return p

        // MARK: 验证码登录
        //
        // 请求：`{"mobile": "...", "code": "8270", "type": 3,
        //         "user_source": "IOS", "client_id": "..."}`
        case .codeLogin(let account, let type, let code):
            var p = makeBaseParameters(includeClientID: true)
            p["code"] = code
            p["type"] = SmsScene.smsLogin.rawValue
            p.merge(accountField(account, type: type, context: .codeLogin)) { _, new in new }
            return p

        // MARK: 发送验证码
        //
        // 请求：`{"mobile": "...", "type": 3, "is_test": 1}`（DEBUG）
        //       或 `{"mobile": "...", "type": 3}`（Release）
        case .sendSmsCode(let account, let type, let scene):
            var p: [String: Any] = [
                "type": scene.rawValue
            ]
            if let isTest = Self.smsTestFlag {
                p["is_test"] = isTest
            }
            p.merge(accountField(account, type: type, context: .sendSmsCode)) { _, new in new }
            return p

        // MARK: 忘记密码 / 重置密码
        //
        // 请求：`{"account": "...", "account_type": "mobile",
        //         "password": "...", "code": "...", "type": 2}`
        case .forgetPassword(let account, let type, let newPassword, let code):
            var p: [String: Any] = [
                "account":      account,
                "account_type": type.rawValue,
                "password":     newPassword,
                "type":         SmsScene.forgetPassword.rawValue
            ]
            if let code, !code.isEmpty {
                p["code"] = code
            }
            return p

        // MARK: 会员注册
        //
        // 请求：`{"mobile": "...", "password": "...", "code": "...",
        //         "type": 1, "user_source": "IOS", "client_id": "..."}`
        case .register(let account, let type, let password, let code):
            var p = makeBaseParameters(includeClientID: true)
            p["password"] = password
            p["type"] = SmsScene.register.rawValue
            p.merge(accountField(account, type: type, context: .register)) { _, new in new }
            if let code, !code.isEmpty {
                p["code"] = code
            }
            return p
        }
    }

    // MARK: - Account Field Context

    /// 账号字段的上下文
    ///
    /// 后端"邮箱"字段在**三个接口里三种命名**：
    /// - **发送验证码**（`user/get_code`）→ `user_email`
    /// - **验证码登录**（`user/user_login_bycode`）→ `email`
    /// - **会员注册**（`user/registerUser`）→ `email`
    ///
    /// - Note: 手机号字段在这三个接口里统一是 `mobile`——
    ///         因此 `context` 只对 `.email` 类型有意义。
    private enum AccountFieldContext {
        /// 发送验证码接口（`user/get_code`）
        case sendSmsCode

        /// 验证码登录接口（`user/user_login_bycode`）
        case codeLogin

        /// 注册接口（`user/registerUser`）
        case register
    }

    // MARK: - Private Helpers

    /// 组装通用基础参数
    ///
    /// - Parameter includeClientID: 是否附带 `client_id`（IDFV）
    ///   - `true`：登录 / 注册等需要设备识别的接口
    ///   - `false`：发送验证码 / 重置密码等不需要的接口
    /// - Returns: 基础参数字典
    ///
    /// - Note: 若 `DeviceInfo.idfv` 为 nil（极少见），不附带 `client_id`——
    ///         后端应容忍该字段缺失。
    private func makeBaseParameters(includeClientID: Bool) -> [String: Any] {
        var p: [String: Any] = [
            "user_source": DeviceInfo.osName
        ]
        if includeClientID, let idfv = DeviceInfo.idfv {
            p["client_id"] = idfv
        }
        return p
    }

    /// 组装账号字段
    ///
    /// - Parameters:
    ///   - account: 账号字符串
    ///   - type: 账号类型
    ///   - context: 调用上下文（区分邮箱字段命名）
    /// - Returns: 账号字段字典
    ///
    /// ## 字段命名规则
    /// | 账号类型 | `sendSmsCode` | `codeLogin` / `register` |
    /// |---|---|---|
    /// | 手机号 | `mobile` | `mobile` |
    /// | 邮箱 | `user_email` | `email` |
    ///
    /// - Important: `.account` 类型**不支持**此方法——
    ///              它仅用于密码登录接口，且密码登录不用本方法组装账号字段。
    ///              若误传 `.account`，会 `preconditionFailure` 明确崩溃，
    ///              避免把用户名错误地塞进 `mobile` 字段。
    private func accountField(_ account: String, type: AccountType, context: AccountFieldContext) -> [String: Any] {
        switch type {
        case .mobile:
            return ["mobile": account]

        case .email:
            switch context {
            case .sendSmsCode:
                return ["user_email": account]
            case .codeLogin, .register:
                return ["email": account]
            }

        case .account:
            // ⚠️ 编程错误：`.account` 类型仅密码登录支持，
            //    而密码登录不走本方法。此处崩溃以便暴露调用方 bug。
            preconditionFailure(
                "accountField 不支持 .account 类型（仅密码登录使用，且不走本方法）"
            )
        }
    }
}

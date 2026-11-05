//
//  AccountSecurityAPI.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/30.
//

import Foundation
import Alamofire

/// 账号与安全相关接口
///
/// ## 接口清单
/// | 接口 | 后端路径 | 用途 |
/// |---|---|---|
/// | `changePassword` | `user/edit_password` | 修改密码 |
/// | `changePhone` | `user/edit_mobile` | 修改绑定手机号 |
/// | `bindPhone` | `user/edit_mobile` | 首次绑定手机号 |
/// | `changeEmail` | `user/edit_email` | 修改绑定邮箱 |
/// | `bindEmail` | `user/edit_email` | 首次绑定邮箱 |
/// | `checkCode` | `user/check_code` | 校验验证码 |
/// | `sendCode` | `user/get_code` | 发送验证码 |
///
/// ## 调用方法
/// ```swift
/// // 1. 修改密码
/// let api = AccountSecurityAPI.changePassword(oldPassword: "old", newPassword: "new")
///
/// // 2. 修改绑定手机号
/// let api = AccountSecurityAPI.changePhone(newPhone: "138...", newCode: "1234")
///
/// // 3. 校验验证码（Step 1）
/// let api = AccountSecurityAPI.checkCode(
///     account: "138...", accountType: .mobile, code: "1234", scene: .changePhone
/// )
///
/// // 4. 由 NetworkClient 统一发起
/// client.request(api, as: EmptyResponse.self)
/// ```
enum AccountSecurityAPI: APIRequest {

    // MARK: - Constants

    /// 修改绑定操作的后端类型常量
    private static let modifyBindingType = 4

    // MARK: - Debug 测试标志

    /// 测试模式标志（仅 DEBUG 构建携带）
    private static let testModeFlag: Int? = {
        #if DEBUG
        return 1
        #else
        return nil
        #endif
    }()

    // MARK: - Cases

    /// 修改密码
    ///
    /// - Parameters:
    ///   - oldPassword: 旧密码
    ///   - newPassword: 新密码
    case changePassword(oldPassword: String, newPassword: String)

    /// 修改绑定手机号（已绑定过手机，需要验证旧手机）
    ///
    /// - Parameters:
    ///   - newPhone: 新手机号
    ///   - newCode: 新手机收到的验证码
    case changePhone(newPhone: String, newCode: String)

    /// 首次绑定手机号（此前未绑定）
    ///
    /// - Parameters:
    ///   - newPhone: 新手机号
    ///   - newCode: 新手机收到的验证码
    case bindPhone(newPhone: String, newCode: String)

    /// 修改绑定邮箱（已绑定过邮箱）
    ///
    /// - Parameters:
    ///   - newEmail: 新邮箱
    ///   - newCode: 新邮箱收到的验证码
    case changeEmail(newEmail: String, newCode: String)

    /// 首次绑定邮箱
    ///
    /// - Parameters:
    ///   - newEmail: 新邮箱
    ///   - newCode: 新邮箱收到的验证码
    case bindEmail(newEmail: String, newCode: String)

    /// 校验验证码（验证旧账号）
    ///
    /// - Parameters:
    ///   - account: 被验证的账号（旧手机号 / 旧邮箱）
    ///   - accountType: 账号类型
    ///   - code: 用户输入的验证码
    ///   - scene: 业务场景
    case checkCode(account: String, accountType: AccountType, code: String, scene: SmsScene)

    /// 发送验证码
    ///
    /// - Parameters:
    ///   - account: 接收验证码的手机号 / 邮箱
    ///   - accountType: 账号类型
    ///   - scene: 业务场景
    ///   - userId: 用户 ID（**可选**）
    ///     - **Step 1**（验证旧账号）：传 `nil`——后端通过 `user-token` 识别用户
    ///     - **Step 2**（绑定新账号）：传当前登录用户 ID——后端据此关联"改绑记录"
    case sendCode(account: String, accountType: AccountType, scene: SmsScene, userId: String?)

    // MARK: - APIRequest

    /// 接口路径
    var path: String {
        switch self {
        case .changePassword:
            return APIEndpoint.editPassword.rawValue

        case .changePhone, .bindPhone:
            // 修改 / 首次绑定共用同一后端接口
            // 后端按用户当前绑定状态自动区分
            return APIEndpoint.editPhone.rawValue

        case .changeEmail, .bindEmail:
            // 修改 / 首次绑定共用同一后端接口（同手机号）
            return APIEndpoint.editEmail.rawValue

        case .checkCode:
            return APIEndpoint.checkCode.rawValue

        case .sendCode:
            return APIEndpoint.smsCode.rawValue
        }
    }

    /// HTTP 方法（全部 POST）
    var method: HTTPMethod { .post }

    /// 所有接口统一使用 JSON body
    var encoding: ParameterEncoding { JSONEncoding.default }

    /// 请求参数（依 case 分派）
    var parameters: [String: Any]? {
        switch self {

        // MARK: 修改密码
        //
        // 请求：`{"old_password": "...", "new_password": "..."}`
        case .changePassword(let oldPassword, let newPassword):
            return [
                "old_password": oldPassword,
                "new_password": newPassword
            ]

        // MARK: 修改 / 首次绑定手机号
        //
        // Postman 实测请求：
        //   `{"code": "1234", "mobile": "18384891021", "type": 4}`
        case .changePhone(let newPhone, let newCode),
             .bindPhone(let newPhone, let newCode):
            return mobileParameters(newMobile: newPhone, code: newCode)

        // MARK: 修改 / 首次绑定邮箱
        //
        // 与手机号对称——字段名从 `mobile` 换成 `email`。
        case .changeEmail(let newEmail, let newCode),
             .bindEmail(let newEmail, let newCode):
            return emailParameters(newEmail: newEmail, code: newCode)

        // MARK: 校验验证码
        //
        // 请求：`{"mobile": "...", "code": "...", "type": 4}`
        //     或 `{"user_email": "...", "code": "...", "type": 4}`
        case .checkCode(let account, let accountType, let code, let scene):
            var p: [String: Any] = [
                "code": code,
                "type": scene.rawValue
            ]
            p.merge(accountField(account, type: accountType)) { _, new in new }
            return p

        // MARK: 发送验证码
        //
        // Postman 实测请求：
        //   Step 1（旧账号）：`{"is_test": 1, "mobile": "...", "type": 4}`
        //   Step 2（新账号）：`{"is_test": 1, "mobile": "...", "type": 4, "user_id": 3910}`
        case .sendCode(let account, let accountType, let scene, let userId):
            var p: [String: Any] = [
                "type": scene.rawValue
            ]

            // 账号字段（mobile / user_email）——与 checkCode 共用
            p.merge(accountField(account, type: accountType)) { _, new in new }

            // 可选 userId——仅 Step 2（绑定新账号）时携带
            if let userId = userId?.nilIfBlank {
                p["user_id"] = userId
            }

            // DEBUG 下携带测试标志（Release 下 `testModeFlag` 为 nil，自动跳过）
            if let testFlag = Self.testModeFlag {
                p["is_test"] = testFlag
            }

            return p
        }
    }

    /// 请求头：附加 `user-token`
    ///
    /// - Returns: 含 `user-token` 的请求头；无 token 时返回 `nil`
    var headers: HTTPHeaders? {
        guard let token = AuthStore.shared.token, !token.isEmpty else {
            AppLog.profile.debug(
                "AccountSecurityAPI 未携带 user-token（path=\(self.path, privacy: .public)）"
            )
            return nil
        }
        return ["user-token": token]
    }

    // MARK: - Private Parameter Builders

    /// 组装"改绑手机号"参数
    ///
    /// - Parameters:
    ///   - newMobile: 新手机号
    ///   - code: 新手机收到的验证码
    /// - Returns: 后端所需参数字典
    private func mobileParameters(newMobile: String, code: String) -> [String: Any] {
        [
            "mobile": newMobile,
            "code":   code,
            "type":   Self.modifyBindingType
        ]
    }

    /// 组装"改绑邮箱"参数
    ///
    /// - Parameters:
    ///   - newEmail: 新邮箱
    ///   - code: 新邮箱收到的验证码
    /// - Returns: 后端所需参数字典
    private func emailParameters(newEmail: String, code: String) -> [String: Any] {
        [
            "email": newEmail,
            "code":  code,
            "type":  Self.modifyBindingType
        ]
    }

    /// 组装账号字段（`mobile` / `user_email`）
    ///
    /// - Parameters:
    ///   - account: 账号字符串
    ///   - type: 账号类型
    /// - Returns: 单键字典
    private func accountField(_ account: String, type: AccountType) -> [String: Any] {
        switch type {
        case .mobile:
            return ["mobile": account]

        case .email:
            return ["user_email": account]

        case .account:
            // ⚠️ 编程错误：`.account` 类型仅密码登录支持，
            //    改绑接口永远不应使用。此处崩溃以便暴露调用方 bug。
            preconditionFailure(
                "accountField 不支持 .account 类型（仅密码登录使用，改绑接口不应出现）"
            )
        }
    }
}

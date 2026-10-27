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
///
/// ## 认证
/// 所有接口都需要 `user-token` 请求头（见 `headers`）。
enum AccountSecurityAPI: APIRequest {

    // MARK: - Constants

    /// 修改绑定操作的后端类型常量
    ///
    /// - Note: 数值 `4` 与 `SmsScene.changePhone.rawValue` **当前**相等，
    ///         若两者出现分歧，以本常量为准（改绑接口专用）。
    private static let modifyBindingType = 4

    // MARK: - Debug 测试标志

    /// 测试模式标志（仅 DEBUG 构建携带）
    ///
    /// ## 作用
    /// 后端 `user/get_code` 接口在 `is_test = 1` 时：
    /// - **不真实发送**短信 / 邮件
    /// - 在响应 `data.code` 里返回验证码
    /// - 客户端可自动填充，实现秒级调试
    ///
    /// ## Release 安全保证
    /// 用 `#if DEBUG` 编译期隔离——
    /// Release 构建**绝不会**携带此字段，防止线上用户收到测试验证码。
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
    ///   - userId: 用户 ID（**可选**）——Postman 实测 Step 2 会带上
    case sendCode(
        account: String,
        accountType: AccountType,
        scene: SmsScene,
        userId: String?
    )

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
    ///
    /// - Note: 改绑 / 校验 / 发送验证码都是结构化参数，
    ///         没有文件上传场景，因此全部 JSON。
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
        //
        // - Note: **不带 `old_code`**——
        //         旧手机验证在 Step 1 已通过，后端按 type=4 关联当前登录用户处理。
        //         新手机收到的验证码通过 `code` 字段提交。
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
        //
        // - Note: `user_id` **可选**——Step 2 带上，Step 1 不带。
        //         `is_test = 1` 只在 DEBUG 下携带。
        case .sendCode(let account, let accountType, let scene, let userId):
            var p: [String: Any] = [
                "type": scene.rawValue
            ]

            // 账号字段（mobile / user_email）——与 checkCode 共用
            p.merge(accountField(account, type: accountType)) { _, new in new }

            // 可选 userId——仅 Step 2（绑定新账号）时携带
            if let userId, !userId.isEmpty {
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
    ///
    /// - Note:
    ///   - `AuthStore.shared.token` 内部线程安全（Keychain / UserDefaults 均线程安全），
    ///     `asURLRequest()` 在任意线程调用都安全
    ///   - 无 token 时返回 `nil`——后端会返回 401，
    ///     由 `NetworkClient` 映射为 `.tokenExpired`
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
    ///
    /// - Note: `changePhone` 与 `bindPhone` **共用**——
    ///         后端按 type=4 + 当前登录用户识别"修改"还是"绑定"。
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
    ///
    /// - Note: 与 `mobileParameters` 对称——只把 `mobile` 换成 `email`。
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
    ///
    /// ## 字段名映射（后端历史遗留）
    /// | 账号类型 | 字段名 |
    /// |---|---|
    /// | `.mobile` / `.account` | `mobile` |
    /// | `.email` | `user_email` |
    private func accountField(_ account: String, type: AccountType) -> [String: Any] {
        switch type {
        case .mobile, .account:
            // `.account`（用户名）在改绑接口中**不应出现**——
            // 但为容错起见，与 `.mobile` 走同一分支。
            // 若出现异常调用（如误传 `.account`），会以 mobile 字段发送，
            // 后端会因参数不匹配返回错误 → 便于暴露调用方 bug。
            return ["mobile": account]

        case .email:
            return ["user_email": account]
        }
    }
}

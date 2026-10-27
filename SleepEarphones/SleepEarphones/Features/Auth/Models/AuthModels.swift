//
//  AuthModels.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/17.
//

import Foundation

// MARK: - 账号类型

/// 账号类型（对应后端 `account_type` 字段）
///
/// ## 调用方法
/// ```swift
/// // 1. 通过 LoginAccountMode 自动映射
/// let type = LoginAccountMode.phone.accountType   // .mobile
///
/// // 2. 直接指定
/// AuthAPI.passwordLogin(account: "138...", accountType: .mobile, password: "...")
/// ```
///
/// ## 不同接口的取值差异
/// | 接口 | 允许的取值 |
/// |---|---|
/// | 密码登录（`user_name_login`） | `account` / `mobile` / `email` |
/// | 验证码登录 / 注册 / 找回密码 | `mobile` / `email` |
///
/// - Note: `.account` 表示"用户名"（仅密码登录接口支持）。
///         其他接口传 `.account` 时后端会返回参数错误。
enum AccountType: String, Sendable, CaseIterable {

    /// 账号名（仅密码登录时使用）
    case account

    /// 手机号
    case mobile

    /// 邮箱
    case email
}

// MARK: - 短信业务场景

/// 短信 / 邮箱验证码场景（对应接口的 `type` 字段）
///
/// ## 调用方法
/// ```swift
/// // 1. 发送注册验证码
/// AuthAPI.sendSmsCode(account: "138...", accountType: .mobile, scene: .register)
///
/// // 2. 通过 ViewModel 的便利方法
/// registerVM.sendRegisterCode()       // 内部固定 scene = .register
/// forgetPasswordVM.sendForgetCode()   // 内部固定 scene = .forgetPassword
/// ```
///
enum SmsScene: Int, Sendable, CaseIterable {

    /// 注册
    case register       = 1

    /// 忘记密码
    case forgetPassword = 2

    /// 短信 / 邮箱验证码登录
    case smsLogin       = 3

    /// 修改绑定手机号
    case changePhone    = 4

    /// 绑定手机号
    case bindPhone      = 5

    /// 场景描述（便于日志 / 调试）
    ///
    /// - Returns: 中文场景名（如 `"注册"` / `"忘记密码"`）
    var description: String {
        switch self {
        case .register:       return "注册"
        case .forgetPassword: return "忘记密码"
        case .smsLogin:       return "验证码登录"
        case .changePhone:    return "修改手机号"
        case .bindPhone:      return "绑定手机号"
        }
    }
}

// MARK: - 用户信息（解码容器）

/// 会员信息（对应各接口返回的 `data.userinfo`）
struct UserInfo: Decodable, Sendable {

    /// 会员登录标识（token）
    let userToken: String?

    /// 用户 ID
    let id: Int?

    /// 账号名（后端返回，如 `"1786096102_38737"`）
    let account: String?

    /// 头像 URL
    let avatar: String?

    /// 真实姓名
    let realName: String?

    /// 昵称
    let nickname: String?

    /// 邮箱
    let email: String?

    /// 性别（后端用字符串表示，如 `"0"` / `"1"` / `"2"`）
    let gender: String?

    /// 手机号（可能带 `*` 号，如 `"183****1021"`）
    let mobile: String?

    /// 生日（时间戳字符串，如 `"1786096102"`）
    let birthday: String?

    /// 推送标识
    let clientId: String?

    /// 手机号（不带 `*` 号，仅部分接口返回）
    let phone: String?

    /// 是否弹窗提醒注销信息（1 = 是，0 = 否）
    let isCancel: Int?

    enum CodingKeys: String, CodingKey {
        case userToken = "user_token"
        case id
        case account
        case avatar
        case realName  = "real_name"
        case nickname
        case email
        case gender
        case mobile
        case birthday
        case clientId  = "client_id"
        case phone
        case isCancel  = "is_cancel"
    }
}

// MARK: - 登录 / 注册返回结果

/// 登录 / 注册接口返回的会员数据
///
/// ## 调用方法
/// ```swift
/// // 通常由 AuthService / AuthRepository 返回，业务层通过 AuthStore 访问。
/// loginVM.$loginSuccess
///     .filter { $0 }
///     .sink { _ in
///         // 此时 AuthStore.shared 已保存好凭证
///         let nickname = AuthStore.shared.nickname
///     }
/// ```
///
/// ## 字段映射（重点）
/// 后端返回结构为 `data.userinfo.xxx`，本类型通过自定义解码
/// **直接解包到扁平字段**，调用方无需感知 `userinfo` 这一层包装。
///
/// | 本属性 | 后端字段 | 说明 |
/// |---|---|---|
/// | `userId` | `id` | 用户 ID（字段名从 `id` 改为 `userId` 避免歧义） |
/// | `userToken` | `user_token` | 登录令牌 |
/// | `realName` | `real_name` | 真实姓名 |
struct LoginResult: Decodable, Sendable {

    /// 会员登录标识（token）
    let userToken: String?

    /// 用户 ID（后端字段 `id`）
    let userId: Int?

    /// 后端生成的内部账号名（如 `"1786096102_38737"`）
    ///
    /// - Note: 与用户登录时输入的账号可能不同。当前未使用，保留以保证解码完整。
    let account: String?

    /// 昵称
    let nickname: String?

    /// 头像 URL
    let avatar: String?

    /// 邮箱
    let email: String?

    /// 手机号（可能带 `*` 号，如 `"183****1021"`）
    let mobile: String?

    /// 手机号（不带 `*` 号，如 `"18384891021"`）
    let phone: String?

    /// 真实姓名
    let realName: String?

    /// 性别（字符串 `"0"` / `"1"` / `"2"`）
    let gender: String?

    /// 生日（时间戳字符串）
    let birthday: String?

    // MARK: 便捷判断

    /// 是否携带了有效的 token
    ///
    /// - Returns: `userToken` 非空时为 `true`
    var hasValidToken: Bool {
        guard let userToken, !userToken.isEmpty else { return false }
        return true
    }

    /// 是否有昵称
    var hasNickname: Bool {
        guard let nickname else { return false }
        return !nickname.isEmpty
    }

    /// 是否有真实姓名
    var hasRealName: Bool {
        guard let realName else { return false }
        return !realName.isEmpty
    }

    /// 是否有头像
    var hasAvatar: Bool {
        guard let avatar else { return false }
        return !avatar.isEmpty
    }

    /// 用于展示的名称（昵称 → 真实姓名 → 手机号 → 邮箱 → "用户"）
    ///
    /// - Returns: 优先级的第一个非空值
    ///
    /// - Note: 各处回退逻辑收敛在此，避免调用方各写一套。
    var displayName: String {
        if hasNickname, let nickname { return nickname }
        if hasRealName, let realName { return realName }
        if let mobile, !mobile.isEmpty { return mobile }
        if let email, !email.isEmpty { return email }
        return "用户"
    }

    // MARK: CodingKeys

    private enum RootKeys: String, CodingKey {
        case userinfo
    }

    private enum InfoKeys: String, CodingKey {
        case userToken = "user_token"
        case id
        case account
        case nickname
        case avatar
        case email
        case mobile
        case phone
        case realName  = "real_name"
        case gender
        case birthday
    }

    // MARK: 自定义解码

    /// 从 `data.userinfo.*` 解包到扁平字段
    ///
    /// - Parameter decoder: 解码器
    /// - Throws: `DecodingError`（仅当根容器构造失败时）
    ///
    /// ## 容错语义（重要）
    /// 用 `try? info?.decodeIfPresent(...)` 而非严格 `decode`：
    /// - `userinfo` 字段**缺失** → `info` 为 nil → 所有字段为 nil
    /// - `userinfo` 存在但**类型不符**（如后端返回数组）→ 同样为 nil
    /// - 单个字段解码失败（如 `id` 返回字符串而非 Int）→ 该字段为 nil
    ///
    /// 这是**有意的容错**——登录结果部分字段缺失不应导致整体解码失败。
    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: RootKeys.self)

        // 用 optional chaining 处理"userinfo 可能不存在"的情况
        let info = try? root.nestedContainer(keyedBy: InfoKeys.self, forKey: .userinfo)

        userToken = try? info?.decodeIfPresent(String.self, forKey: .userToken)
        userId    = try? info?.decodeIfPresent(Int.self,    forKey: .id)
        account   = try? info?.decodeIfPresent(String.self, forKey: .account)
        nickname  = try? info?.decodeIfPresent(String.self, forKey: .nickname)
        avatar    = try? info?.decodeIfPresent(String.self, forKey: .avatar)
        email     = try? info?.decodeIfPresent(String.self, forKey: .email)
        mobile    = try? info?.decodeIfPresent(String.self, forKey: .mobile)
        phone     = try? info?.decodeIfPresent(String.self, forKey: .phone)
        realName  = try? info?.decodeIfPresent(String.self, forKey: .realName)
        gender    = try? info?.decodeIfPresent(String.self, forKey: .gender)
        birthday  = try? info?.decodeIfPresent(String.self, forKey: .birthday)
    }
}

// MARK: - 发送验证码返回

/// 发送验证码接口的 `data` 层
///
/// ## 调用方法
/// ```swift
/// // 通常由 AuthService.sendSmsCode 返回。
/// // DEBUG 下 result.code 会带测试验证码，可自动填充。
/// if let testCode = result.code {
///     codeTextField.text = "\(testCode)"
/// }
/// ```
struct SmsCodeResult: Decodable, Sendable {

    /// 测试模式下返回的验证码（生产环境为 nil）
    let code: Int?

    /// 供上层构造默认值使用
    ///
    /// - Parameter code: 测试验证码，默认 nil
    init(code: Int? = nil) {
        self.code = code
    }

    private enum CodingKeys: String, CodingKey {
        case code
    }

    /// 宽容解码：任何形态的 `data` 都不会抛错
    ///
    /// - Parameter decoder: 解码器
    /// - Throws: 无（本方法内部容错，不抛出）
    init(from decoder: Decoder) throws {
        // 场景 1：data 是对象 `{ "code": 1234 }` 或 `{ "code": "1234" }`
        if let c = try? decoder.container(keyedBy: CodingKeys.self) {
            // 优先 Int
            if let intCode = try? c.decodeIfPresent(Int.self, forKey: .code) {
                self.code = intCode
                return
            }
            // 兼容 String（后端 PHP 可能序列化）
            if let strCode = try? c.decodeIfPresent(String.self, forKey: .code),
               let parsed = Int(strCode) {
                self.code = parsed
                return
            }
            self.code = nil
            return
        }
        // 场景 2：data 是 `[]` / 数字 / 字符串 / 其他 → 忽略
        self.code = nil
    }
}

// MARK: - 空响应占位

/// 空响应占位
///
/// - Note: 用于"只关心业务成功 / 失败，不关心 data 内容"的接口。
///         当前使用场景：**忘记密码**（`AuthAPI.forgetPassword`）——
///         接口返回 `data: []` 或 `data: {}`。
///
/// ## 宽容解码
/// 无论 `data` 是 `null` / `[]` / `{}` / 对象 / 数组，
/// 都能成功构造（`init(from:)` 故意留空）。
struct EmptyResponse: Decodable, Sendable {

    init() {}

    /// 什么都不解析，任何内容都接受
    ///
    /// - Parameter decoder: 解码器（忽略）
    /// - Throws: 无
    init(from decoder: Decoder) throws {
        // 故意留空
    }
}

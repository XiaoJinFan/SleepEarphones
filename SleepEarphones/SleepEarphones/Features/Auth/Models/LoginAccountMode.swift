//
//  LoginAccountMode.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/17.
//

import UIKit   // 需要 UIKeyboardType / UITextContentType 等 UIKit 枚举

// MARK: - 账号模式（segmentControl）

/// 账号模式
///
/// 用于登录 / 注册 / 找回密码页的 `UISegmentedControl`：
/// - 索引 `0` → 手机号
/// - 索引 `1` → 邮箱
///
/// ## 调用方法
/// ```swift
/// // 1. 与 UISegmentedControl 互转
/// let mode = LoginAccountMode(rawValue: segment.selectedSegmentIndex)
/// segment.selectedSegmentIndex = mode.rawValue
///
/// // 2. 获取账号类型（传给后端 account_type）
/// let type = mode.accountType   // .mobile / .email
///
/// // 3. 配置输入框键盘（配合 AuthFormUIHelper）
/// applyAuthKeyboard(to: textField, mode: .phone)
/// ```
///
enum LoginAccountMode: Int, Sendable, CaseIterable {

    /// 手机号
    case phone = 0

    /// 邮箱
    case email = 1

    // MARK: - Account Type

    /// 对应的账号类型（传给后端的 `account_type`）
    ///
    /// - Returns: `.mobile` / `.email`
    ///
    /// - Note: 手机号走 `.mobile`（不是 `.account`），
    ///         因为 `.account` 仅密码登录接口支持。
    var accountType: AccountType {
        switch self {
        case .phone: return .mobile
        case .email: return .email
        }
    }

    // MARK: - Display

    /// 输入框占位符
    ///
    /// - Returns: `"请输入手机号"` / `"请输入邮箱"`
    var placeholder: String {
        switch self {
        case .phone: return "请输入手机号"
        case .email: return "请输入邮箱"
        }
    }

    /// 分段控件标题
    ///
    /// - Returns: `"手机号码"` / `"邮箱账号"`
    var title: String {
        switch self {
        case .phone: return "手机号码"
        case .email: return "邮箱账号"
        }
    }

    // MARK: - 键盘与输入特性

    /// 键盘类型
    ///
    /// - Returns:
    ///   - 手机号：`.numberPad`（纯数字键盘）
    ///   - 邮箱：`.emailAddress`（含 @ 与 . 的键盘）
    ///
    /// - Note: 返回 `UIKeyboardType` 而非 `Int`——
    ///         硬编码 `UIKeyboardType.rawValue` 无语义且易错。
    var keyboardType: UIKeyboardType {
        switch self {
        case .phone: return .numberPad
        case .email: return .emailAddress
        }
    }

    /// 输入内容类型（用于系统自动填充 / 密码管理器识别）
    ///
    /// - Returns:
    ///   - 手机号：`.telephoneNumber`——iOS 会自动弹出键盘上方的"填充"提示
    ///   - 邮箱：`.emailAddress`
    ///
    /// - Note: 前提是用户在系统设置里开启了自动填充。
    var textContentType: UITextContentType {
        switch self {
        case .phone: return .telephoneNumber
        case .email: return .emailAddress
        }
    }

    /// 自动大写类型
    ///
    /// - Returns: `.none`（手机号 / 邮箱均为精确字符串，禁止自动大写）
    var autocapitalizationType: UITextAutocapitalizationType {
        .none
    }

    /// 自动纠错类型
    ///
    /// - Returns: `.no`（手机号和邮箱都是**精确字符串**，禁止自动纠错）
    var autocorrectionType: UITextAutocorrectionType {
        .no
    }
}

// MARK: - 登录方式（loginTypeBtn）

/// 登录方式
///
/// 仅登录页使用，用于切换「验证码登录」与「密码登录」：
/// - `.code`：验证码登录（默认）
/// - `.password`：密码登录
///
/// ## 调用方法
/// ```swift
/// // 1. 切换
/// var method: LoginMethod = .code
/// method.toggle()   // → .password
///
/// // 2. 获取切换按钮标题
/// let title = method.switchButtonTitle   // "密码登录" / "验证码登录"
///
/// // 3. 日志 / 埋点
/// print(method.description)   // "验证码登录" / "密码登录"
/// ```
///
/// ## 与 `LoginAccountMode` 的区别
/// - `LoginAccountMode`：切换**账号类型**（手机号 / 邮箱）
/// - `LoginMethod`：切换**登录方式**（验证码 / 密码）
///
/// 两者在 UI 上表现为两个独立的切换控件。
enum LoginMethod: Int, Sendable, CaseIterable {

    /// 验证码登录
    case code = 0

    /// 密码登录
    case password = 1

    // MARK: - Toggle

    /// 在「验证码登录」与「密码登录」之间切换
    ///
    /// - Note: 用 `mutating` 让业务层可以直接：
    ///         ```swift
    ///         var method: LoginMethod = .code
    ///         method.toggle()
    ///         ```
    mutating func toggle() {
        self = (self == .code) ? .password : .code
    }

    // MARK: - Display

    /// 切换按钮上显示的文案
    ///
    /// - Returns: 点击后**切换到的方式**（不是当前方式）
    ///
    /// ## 命名说明
    /// - 当前是"验证码登录" → 按钮显示"密码登录"（提示用户"点我切到密码登录"）
    /// - 当前是"密码登录" → 按钮显示"验证码登录"
    var switchButtonTitle: String {
        switch self {
        case .code:     return "密码登录"
        case .password: return "验证码登录"
        }
    }

    /// 当前登录方式名称
    ///
    /// - Returns: `"验证码登录"` / `"密码登录"`
    ///
    /// - Note: 用于日志 / 埋点 / 分析。
    var description: String {
        switch self {
        case .code:     return "验证码登录"
        case .password: return "密码登录"
        }
    }
}

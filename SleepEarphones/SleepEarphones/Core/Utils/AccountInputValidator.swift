//
//  AccountInputValidator.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/21.
//

import Foundation

/// 账号 / 密码 / 验证码 输入校验
///
/// ## 调用方法
/// ```swift
/// // 1. 快速校验（返回 Bool）
/// AccountInputValidator.isValidPhone("13800138000")     // true
/// AccountInputValidator.isValidEmail("a@b.com")         // true
/// AccountInputValidator.isValidPassword("abc123")       // true
/// AccountInputValidator.isStrongPassword("abc123")      // true
/// AccountInputValidator.isValidNumericCode("1234")      // true
///
/// // 2. 按模式分派
/// AccountInputValidator.isValidAccount(input, mode: .phone)
///
/// // 3. 返回具体失败原因（用于 UI 提示）
/// switch AccountInputValidator.validateAccount(input, mode: .phone) {
/// case .success: break
/// case .failure(let reason): showToast(reason.message)
/// }
///
/// // 4. 输入规范化（发送请求前）
/// let normalized = AccountInputValidator.normalizePhone(" 138 0013 8000 ")
/// ```
enum AccountInputValidator {

    // MARK: - Regex（预编译）

    /// 手机号正则：`1` 开头 + `[3-9]` 号段 + 9 位数字
    private static let phoneRegex = try! NSRegularExpression(
        pattern: "^1[3-9]\\d{9}$"
    )

    /// 邮箱正则：标准的简化版（覆盖 99% 场景，未用 RFC 5322 完整规范）
    private static let emailRegex = try! NSRegularExpression(
        pattern: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
    )

    /// 强密码正则：6~12 位字母 + 数字（至少各一个）
    private static let strongPasswordRegex = try! NSRegularExpression(
        pattern: "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d]{6,12}$"
    )

    /// 纯数字验证码正则：4~6 位数字
    private static let numericCodeRegex = try! NSRegularExpression(
        pattern: "^\\d{4,6}$"
    )

    // MARK: - Phone

    /// 校验手机号
    ///
    /// - Parameter phone: 待校验字符串（内部会自动去空格 + 全角转半角）
    /// - Returns: 是否为合法的中国大陆手机号
    static func isValidPhone(_ phone: String) -> Bool {
        matches(normalizePhone(phone), regex: phoneRegex)
    }

    // MARK: - Email

    /// 校验邮箱
    ///
    /// - Parameter email: 待校验字符串（内部会自动去空格）
    /// - Returns: 是否为合法邮箱
    static func isValidEmail(_ email: String) -> Bool {
        matches(email.trimmingCharacters(in: .whitespaces), regex: emailRegex)
    }

    // MARK: - Account（按模式分派）

    /// 校验账号（手机号 / 邮箱二选一）
    ///
    /// - Parameters:
    ///   - account: 待校验字符串
    ///   - mode: 账号模式（`.phone` / `.email`）
    /// - Returns: 是否符合当前模式的格式
    static func isValidAccount(_ account: String, mode: LoginAccountMode) -> Bool {
        switch mode {
        case .phone: return isValidPhone(account)
        case .email: return isValidEmail(account)
        }
    }

    // MARK: - Password

    /// 校验密码（宽松版：仅长度）
    ///
    /// - Parameter password: 待校验密码
    /// - Returns: 长度是否 ≥ 6
    ///
    /// - Note: 用于**登录** / **找回密码**——
    ///         老用户密码可能是历史遗留格式，只要长度 ≥ 6 就允许提交。
    static func isValidPassword(_ password: String) -> Bool {
        password.count >= 6
    }

    /// 校验密码（严格版：6~12 位字母 + 数字）
    ///
    /// - Parameter password: 待校验密码
    /// - Returns: 是否同时包含字母和数字，且长度为 6~12
    ///
    /// - Note: 用于**注册**——与注册页 placeholder 提示一致。
    static func isStrongPassword(_ password: String) -> Bool {
        matches(password, regex: strongPasswordRegex)
    }

    // MARK: - Code

    /// 校验验证码（宽松版：仅长度）
    ///
    /// - Parameter code: 待校验验证码
    /// - Returns: 长度是否 ≥ 4
    ///
    /// - Note: 兼容短信验证码长度差异（4~6 位）。
    static func isValidCode(_ code: String) -> Bool {
        code.count >= 4
    }

    /// 校验验证码（严格版：4~6 位纯数字）
    ///
    /// - Parameter code: 待校验验证码
    /// - Returns: 是否为 4~6 位纯数字
    static func isValidNumericCode(_ code: String) -> Bool {
        matches(code, regex: numericCodeRegex)
    }

    // MARK: - Normalize

    /// 规范化手机号输入
    ///
    /// - Parameter phone: 原始输入
    /// - Returns: 去除首尾 / 中间空格、全角数字转半角后的字符串
    static func normalizePhone(_ phone: String) -> String {
        let trimmed = phone.trimmingCharacters(in: .whitespaces)
        let noSpaces = trimmed.replacingOccurrences(of: " ", with: "")
        return halfWidthDigits(noSpaces)
    }

    /// 规范化邮箱输入
    ///
    /// - Parameter email: 原始输入
    /// - Returns: 去除首尾空格、全角字符转半角后的字符串
    static func normalizeEmail(_ email: String) -> String {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return halfWidthDigits(trimmed)
    }

    // MARK: - Private Helpers

    /// 正则匹配辅助方法
    ///
    /// - Parameters:
    ///   - string: 待匹配字符串
    ///   - regex: 预编译的正则
    /// - Returns: 是否完全匹配
    ///
    private static func matches(_ string: String, regex: NSRegularExpression) -> Bool {
        guard !string.isEmpty else { return false }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        return regex.firstMatch(in: string, options: [], range: range) != nil
    }

    /// 全角数字转半角
    ///
    /// - Parameter input: 原始字符串
    /// - Returns: 全角数字已被替换为半角
    ///
    private static func halfWidthDigits(_ input: String) -> String {
        var result = ""
        result.reserveCapacity(input.count)
        for scalar in input.unicodeScalars {
            // 全角数字 U+FF10 ~ U+FF19 → 半角 '0' ~ '9'
            if scalar.value >= 0xFF10, scalar.value <= 0xFF19 {
                let halfWidth = scalar.value - 0xFF10 + UInt32(Character("0").asciiValue!)
                if let newScalar = Unicode.Scalar(halfWidth) {
                    result.unicodeScalars.append(newScalar)
                }
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }
}

// MARK: - Failure Reason

extension AccountInputValidator {

    /// 校验失败原因（供上层做本地化提示）
    enum FailureReason: Error {

        /// 账号为空
        case emptyAccount

        /// 手机号格式错误
        case invalidPhone

        /// 邮箱格式错误
        case invalidEmail

        /// 密码长度不足
        case passwordTooShort

        /// 密码强度不足
        case passwordNotStrongEnough

        /// 验证码格式错误
        case invalidCode

        /// 中文提示文案
        var message: String {
            switch self {
            case .emptyAccount:
                return "请输入账号"
            case .invalidPhone:
                return "请输入正确的手机号"
            case .invalidEmail:
                return "请输入正确的邮箱"
            case .passwordTooShort:
                return "密码长度至少 6 位"
            case .passwordNotStrongEnough:
                return "密码需为 6~12 位字母+数字"
            case .invalidCode:
                return "请输入正确的验证码"
            }
        }
    }

    /// 校验账号，返回具体失败原因
    ///
    /// - Parameters:
    ///   - account: 待校验账号
    ///   - mode: 账号模式（`.phone` / `.email`）
    /// - Returns: 成功返回 `.success(())`；失败返回 `.failure(reason)`
    ///
    static func validateAccount(_ account: String, mode: LoginAccountMode) -> Result<Void, FailureReason> {
        let trimmed = account.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .failure(.emptyAccount) }

        switch mode {
        case .phone:
            return isValidPhone(trimmed) ? .success(()) : .failure(.invalidPhone)
        case .email:
            return isValidEmail(trimmed) ? .success(()) : .failure(.invalidEmail)
        }
    }
}

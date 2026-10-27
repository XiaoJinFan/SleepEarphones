//
//  String+Validate.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import Foundation

// MARK: - 通用校验

extension String {

    // MARK: 空值判断

    /// 是否为空字符串（**不**包含空白字符判断）
    ///
    /// ## 调用方法
    /// ```swift
    /// "".isEmptyString       // true
    /// " ".isEmptyString      // false（有空格）
    /// ```
    ///
    /// - Note: 若需要判断"仅含空白"，用 `isEmptyOrBlank`
    var isEmptyString: Bool {
        isEmpty
    }

    /// 是否为空或仅含空白字符
    ///
    /// ## 调用方法
    /// ```swift
    /// "".isEmptyOrBlank       // true
    /// "   ".isEmptyOrBlank    // true
    /// "abc".isEmptyOrBlank    // false
    /// ```
    ///
    /// - Note: 用于表单校验。用户输入空格不应视为有效。
    var isEmptyOrBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: 字符类型判断

    /// 是否为纯数字（0~9）
    ///
    /// ## 调用方法
    /// ```swift
    /// "123".isNumeric     // true
    /// "12.3".isNumeric    // false（含小数点）
    /// "-1".isNumeric      // false（含负号）
    /// "１２３".isNumeric  // false（全角）
    /// ```
    ///
    /// - Note: 不包括小数、正负号。全角数字需先调用
    ///         `AccountInputValidator.normalizePhone(_:)` 转换。
    var isNumeric: Bool {
        !isEmpty && allSatisfy { $0.isNumber }
    }

    /// 是否为纯字母
    ///
    /// ## 调用方法
    /// ```swift
    /// "abc".isAlphabetic   // true
    /// "ABC".isAlphabetic   // true
    /// "ab1".isAlphabetic   // false
    /// "".isAlphabetic      // false
    /// ```
    var isAlphabetic: Bool {
        !isEmpty && allSatisfy { $0.isLetter }
    }

    /// 是否为字母 + 数字组合（至少各含一个）
    ///
    /// ## 调用方法
    /// ```swift
    /// "abc123".isAlphanumeric   // true
    /// "abc".isAlphanumeric      // false（无数字）
    /// "123".isAlphanumeric      // false（无字母）
    /// ```
    ///
    /// - Note: 用于"密码必须含字母和数字"类校验的**通用判断**，
    ///         业务语义的密码校验请用 `AccountInputValidator.isStrongPassword`。
    var isAlphanumeric: Bool {
        guard !isEmpty else { return false }
        let hasLetter = contains { $0.isLetter }
        let hasNumber = contains { $0.isNumber }
        return hasLetter && hasNumber
    }

    /// 是否全部为 ASCII 可见字符（不含控制字符 / 中文 / emoji）
    ///
    /// ## 调用方法
    /// ```swift
    /// "abc123!@#".isASCII   // true
    /// "中文".isASCII        // false
    /// "😀".isASCII          // false
    /// ```
    var isASCII: Bool {
        !isEmpty && allSatisfy { $0.isASCII }
    }

    /// 是否全部为中文字符
    ///
    /// ## 调用方法
    /// ```swift
    /// "张三".isChinese     // true
    /// "张三A".isChinese    // false
    /// "".isChinese         // false
    /// ```
    ///
    /// - Note: 依赖 Unicode 范围（CJK Unified Ideographs），
    ///         覆盖常见汉字，不含日文假名 / 韩文。
    var isChinese: Bool {
        !isEmpty && allSatisfy { character in
            character.unicodeScalars.allSatisfy { scalar in
                // CJK Unified Ideographs：U+4E00 ~ U+9FFF
                (0x4E00...0x9FFF).contains(scalar.value)
            }
        }
    }

    // MARK: 长度判断

    /// 是否在指定长度范围内（含边界）
    ///
    /// ## 调用方法
    /// ```swift
    /// "abc".hasLength(in: 1...5)   // true
    /// "abc".hasLength(in: 4...10)  // false
    /// ```
    ///
    /// - Parameters:
    ///   - range: 长度范围（闭区间）
    /// - Returns: 长度是否在 `[lower, upper]` 区间内
    ///
    /// - Note: 用 `count` 而非 `utf8.count`：中文、emoji 也算 1 个字符。
    ///         若需要按字节数校验，改用 `utf8.count`。
    func hasLength(in range: ClosedRange<Int>) -> Bool {
        range.contains(count)
    }

    /// 是否至少为指定长度
    ///
    /// - Parameter min: 最小长度
    /// - Returns: `count >= min` 时为 `true`
    func hasMinLength(_ min: Int) -> Bool {
        count >= min
    }

    /// 是否至多为指定长度
    ///
    /// - Parameter max: 最大长度
    /// - Returns: `count <= max` 时为 `true`
    func hasMaxLength(_ max: Int) -> Bool {
        count <= max
    }

    // MARK: 转 Optional

    /// 空字符串 → nil，否则返回自身
    ///
    /// ## 调用方法
    /// ```swift
    /// "".nilIfEmpty        // nil
    /// " ".nilIfEmpty       // " "（有空格，不算空）
    /// "abc".nilIfEmpty     // "abc"
    /// ```
    ///
    /// - Note: 用于网络请求参数组装，避免发送空字符串。
    ///         若需要"仅空白也算空"，用 `nilIfBlank`。
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    /// 空字符串或仅空白 → nil，否则返回自身（**会 trim**）
    ///
    /// ## 调用方法
    /// ```swift
    /// "".nilIfBlank        // nil
    /// "   ".nilIfBlank     // nil
    /// " a ".nilIfBlank     // "a"（已 trim）
    /// ```
    ///
    /// - Note: **会同时做 trim**，避免把 `" a "` 作为参数发出。
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: 转换

    /// 去除首尾空白字符（含换行）
    ///
    /// ## 调用方法
    /// ```swift
    /// "  abc  ".trimmed    // "abc"
    /// "\nabc\n".trimmed    // "abc"
    /// ```
    ///
    /// - Note: `trimmingCharacters(in: .whitespaces)` **不含换行**，
    ///         这里用 `.whitespacesAndNewlines` 更符合"去首尾空白"的直觉。
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 截断到指定长度
    ///
    /// ## 调用方法
    /// ```swift
    /// "abcdef".truncated(to: 3)   // "abc"
    /// "abc".truncated(to: 5)      // "abc"（未超长，原样返回）
    /// ```
    ///
    /// - Parameter length: 最大保留长度
    /// - Returns: 若原长 ≤ length，返回自身；否则返回前 length 个字符
    ///
    /// - Note: 按 `Character` 计数，中文 / emoji 不会被拆坏。
    ///         若需要在截断后加省略号，用 `truncatedWithEllipsis(to:)`。
    func truncated(to length: Int) -> String {
        guard length >= 0, count > length else { return self }
        return String(prefix(length))
    }

    /// 截断到指定长度，超出部分用省略号替代
    ///
    /// ## 调用方法
    /// ```swift
    /// "abcdef".truncatedWithEllipsis(to: 3)   // "abc…"
    /// "abc".truncatedWithEllipsis(to: 5)      // "abc"（未超长，不加省略号）
    /// ```
    ///
    /// - Parameter length: 最大保留长度（**不含省略号**）
    /// - Returns: 若原长 ≤ length，返回自身；否则返回 `前 length 个字符 + "…"`
    func truncatedWithEllipsis(to length: Int) -> String {
        guard length >= 0 else { return self }
        guard count > length else { return self }
        return String(prefix(length)) + "…"
    }
}

// MARK: - 脱敏

extension String {

    /// 手机号脱敏（保留前 3 后 4）
    ///
    /// ## 调用方法
    /// ```swift
    /// "18384891021".maskedMobile    // "183****1021"
    /// "123".maskedMobile            // "123"（长度不足，原样返回）
    /// ```
    ///
    /// - Note: 长度不足 7 位时直接返回自身（不做处理，避免越界）。
    ///         用于界面展示，**不要**用于日志（日志请用 `AppLog` 的 `privacy:`）。
    var maskedMobile: String {
        guard count >= 7 else { return self }
        let prefix = self.prefix(3)
        let suffix = self.suffix(4)
        return "\(prefix)****\(suffix)"
    }

    /// 邮箱脱敏（保留首字符）
    ///
    /// ## 调用方法
    /// ```swift
    /// "user@example.com".maskedEmail    // "u***@example.com"
    /// "invalid".maskedEmail             // "invalid"（无 @，原样返回）
    /// ```
    var maskedEmail: String {
        let parts = split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return self }

        let local = parts[0]
        let domain = parts[1]
        guard let first = local.first else { return self }

        return "\(first)***@\(domain)"
    }

    /// 通用脱敏
    ///
    /// ## 调用方法
    /// ```swift
    /// "1234567890".masked(prefix: 2, suffix: 2)   // "12***90"
    /// "ab".masked(prefix: 2, suffix: 2)           // "ab"（总长不足，原样返回）
    /// ```
    ///
    /// - Parameters:
    ///   - prefixLength: 保留前缀长度
    ///   - suffixLength: 保留后缀长度
    /// - Returns: 中间用 `*` 替代
    ///
    /// - Note: 若总长度 ≤ prefix + suffix，直接返回自身。
    func masked(prefix prefixLength: Int, suffix suffixLength: Int) -> String {
        guard prefixLength >= 0, suffixLength >= 0 else { return self }
        guard count > prefixLength + suffixLength else { return self }
        let prefix = self.prefix(prefixLength)
        let suffix = self.suffix(suffixLength)
        return "\(prefix)***\(suffix)"
    }
}

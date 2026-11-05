//
//  UIColor+Hex.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import UIKit

extension UIColor {

    // MARK: - Init from Hex String

    /// 从十六进制字符串创建颜色
    ///
    /// - Parameters:
    ///   - hex: 十六进制字符串（大小写不敏感）
    ///   - alpha: 透明度（0~1）；仅在 3 / 6 位 hex 时生效
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        // 1. 清理输入：去空格、转小写、剥前缀
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if str.hasPrefix("#") { str.removeFirst() }
        if str.hasPrefix("0x") { str.removeFirst(2) }

        // 2. 3/4 位缩写展开为 6/8 位
        if str.count == 3 || str.count == 4 {
            str = str.map { "\($0)\($0)" }.joined()
        }

        // 3. 合法性校验
        guard str.count == 6 || str.count == 8,
              let value = UInt64(str, radix: 16) else {
            AppLog.ui.error(
                "非法十六进制颜色: \(hex, privacy: .public)（长度应为 3 / 4 / 6 / 8）"
            )
            // 返回透明色，避免静默产生黑色
            self.init(red: 0, green: 0, blue: 0, alpha: 0)
            return
        }

        // 4. 解析字节（**所有组件都 clamp 到 [0, 1]**）
        let r, g, b, a: CGFloat
        if str.count == 8 {
            // RRGGBBAA（alpha 在末尾）
            r = Self.clamp(CGFloat((value & 0xFF00_0000) >> 24) / 255.0)
            g = Self.clamp(CGFloat((value & 0x00FF_0000) >> 16) / 255.0)
            b = Self.clamp(CGFloat((value & 0x0000_FF00) >> 8)  / 255.0)
            a = Self.clamp(CGFloat( value & 0x0000_00FF)        / 255.0)

            // 若外部传入了非默认 alpha，提示调用方"参数被忽略"
            if alpha != 1.0 {
                AppLog.ui.warning(
                    "\(hex, privacy: .public) 是 8 位 hex，alpha 参数被忽略（使用字符串中的 alpha）"
                )
            }
        } else {
            // RRGGBB
            r = Self.clamp(CGFloat((value & 0xFF0000) >> 16) / 255.0)
            g = Self.clamp(CGFloat((value & 0x00FF00) >> 8)  / 255.0)
            b = Self.clamp(CGFloat( value & 0x0000FF)        / 255.0)
            a = Self.clamp(alpha)
        }

        // 5. 构造（`init(red:green:blue:alpha:)` 本身就是 sRGB 色域）
        self.init(red: r, green: g, blue: b, alpha: a)
    }

    // MARK: - Init from Hex String + Alpha Byte

    /// 从十六进制字符串创建颜色，alpha 单独指定（0~255）
    ///
    /// - Parameters:
    ///   - hex: 十六进制字符串（**必须不含 alpha 位**，即 3 位或 6 位）
    ///   - alphaByte: alpha 值（0~255），超出范围会自动 clamp
    ///
    convenience init(hex: String, alphaByte: Int) {
        // 前置校验：hex 是否含 alpha 位
        let normalized = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "0x", with: "")

        if normalized.count == 4 || normalized.count == 8 {
            AppLog.ui.warning(
                "\(hex, privacy: .public) 已含 alpha 位，alphaByte 参数被忽略"
            )
        }

        let clampedByte = max(0, min(255, alphaByte))
        let alpha = CGFloat(clampedByte) / 255.0
        self.init(hex: hex, alpha: alpha)
    }

    // MARK: - Init from Int

    /// 从 24 位 `RGB` 整数创建颜色
    ///
    /// - Parameter rgb: `0xRRGGBB` 形式的整数（如 `0xFF0000` 表示红色）
    ///
    /// ## 使用场景
    /// 当色值以整数形式存在于常量 / 后端返回值中时，避免转字符串：
    /// ```swift
    /// // ❌ 原写法
    /// let color = UIColor(hex: String(format: "#%06X", ledColorHex))
    ///
    /// // ✅ 新写法
    /// let color = UIColor(rgb: ledColorHex)
    /// ```
    convenience init(rgb: Int) {
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8)  & 0xFF) / 255.0
        let b = CGFloat( rgb        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    /// 从 32 位 `ARGB` 整数创建颜色
    ///
    /// - Parameter argb: `0xAARRGGBB` 形式的整数
    ///
    /// ## 使用场景
    /// Android / 后端常用 `ARGB` 格式（alpha 在高位）：
    /// ```swift
    /// let color = UIColor(argb: 0xFF1B84CC)   // 不透明主色
    /// let color = UIColor(argb: 0x801B84CC)   // 50% 透明主色
    /// ```
    convenience init(argb: UInt32) {
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8)  & 0xFF) / 255.0
        let b = CGFloat( argb        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: a)
    }

    // MARK: - Private Helpers

    /// 将 `CGFloat` clamp 到 `[0, 1]`
    ///
    /// - Parameter value: 待 clamp 的值
    /// - Returns: `[0, 1]` 范围内的值
    ///
    /// - Note: `init(red:green:blue:alpha:)` 本身已经会 clamp，
    ///         但这里**显式** clamp 是为了让"输入非法时的行为"可预期——
    ///         若依赖 UIKit 的内部 clamp，未来 UIKit 行为变化可能影响输出。
    private static func clamp(_ value: CGFloat) -> CGFloat {
        max(0, min(1, value))
    }
}

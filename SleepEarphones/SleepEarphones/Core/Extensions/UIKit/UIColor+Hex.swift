//
//  UIColor+Hex.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import UIKit

extension UIColor {

    // MARK: - Init from Hex

    /// 从十六进制字符串创建颜色
    ///
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

    // MARK: - Convenience

    /// 从十六进制字符串创建颜色，alpha 单独指定（0~255）
    ///
    /// - Parameters:
    ///   - hex: 十六进制字符串（**不含 alpha 位**，即 3 位或 6 位）
    ///   - alphaByte: alpha 值（0~255），超出范围会自动 clamp
    convenience init(hex: String, alphaByte: Int) {
        let clampedByte = max(0, min(255, alphaByte))
        let alpha = CGFloat(clampedByte) / 255.0
        self.init(hex: hex, alpha: alpha)
    }

    // MARK: - Private Helpers

    /// 将 `CGFloat` clamp 到 `[0, 1]`
    ///
    /// - Parameter value: 待 clamp 的值
    /// - Returns: `[0, 1]` 范围内的值
    /// 
    private static func clamp(_ value: CGFloat) -> CGFloat {
        return max(0, min(1, value))
    }
}

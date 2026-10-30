//
//  AppColor.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import UIKit

/// 全局颜色定义
///
enum AppColor {

    // MARK: - Brand

    /// 品牌色
    enum Brand {
        /// 主品牌色（浅色 #1B84CC / 深色 #4A9EE0）
        ///
        /// - Note: 深色版本略微提亮，保证在深色背景上的对比度。
        static let primary = dynamic(
            light: "#1B84CC",
            dark:  "#4A9EE0"
        )

        /// 主品牌色 - 按下状态（浅色 #1468A3 / 深色 #3A7FB5）
        static let primaryPressed = dynamic(
            light: "#1468A3",
            dark:  "#3A7FB5"
        )
    }

    // MARK: - Semantic

    /// 语义色（表达状态：成功 / 警告 / 错误 / 信息）
    ///
    /// - Note: 与品牌色区分——品牌色表达"强调"，语义色表达"状态"。
    enum Semantic {

        /// 成功（浅色 #34C759 / 深色 #30D158）
        ///
        /// - 使用场景：设备已连接、保存成功、勾选同意协议
        static let success = dynamic(
            light: "#34C759",
            dark:  "#30D158"
        )

        /// 警告（浅色 #FF9500 / 深色 #FF9F0A）
        ///
        /// - 使用场景：待处理、需注意但不阻断的提示
        static let warning = dynamic(
            light: "#FF9500",
            dark:  "#FF9F0A"
        )

        /// 错误 / 危险（浅色 #FF3B30 / 深色 #FF453A）
        ///
        /// - 使用场景：故障状态、删除按钮、错误提示
        static let error = dynamic(
            light: "#FF3B30",
            dark:  "#FF453A"
        )

        /// 信息（浅色 #3478F6 / 深色 #0A84FF）
        ///
        /// - 使用场景：中性提示、可点击链接
        static let info = dynamic(
            light: "#3478F6",
            dark:  "#0A84FF"
        )
    }

    // MARK: - Text

    /// 文字色（按重要性分四级）
    enum Text {

        /// 主要文字（浅色 #1C1C1E / 深色 #FFFFFF）
        ///
        /// - 使用场景：标题、正文、强调文字
        static let primary = dynamic(
            light: "#1C1C1E",
            dark:  "#FFFFFF"
        )

        /// 次要文字（浅色 #8E8E93 / 深色 #98989D）
        ///
        /// - 使用场景：副标题、说明文字、占位提示
        static let secondary = dynamic(
            light: "#8E8E93",
            dark:  "#98989D"
        )

        /// 三级文字 / 禁用态（浅色 #B0B3B8 / 深色 #48484A）
        ///
        /// - 使用场景：禁用按钮文字、时间戳、极次要信息
        static let tertiary = dynamic(
            light: "#B0B3B8",
            dark:  "#48484A"
        )

        /// 反色文字（浅色 #FFFFFF / 深色 #000000）
        ///
        /// - 使用场景：深色按钮上的文字
        static let inverse = dynamic(
            light: "#FFFFFF",
            dark:  "#000000"
        )
    }

    // MARK: - Background

    /// 背景色（三级层次：primary 最底 → secondary 中间 → card 最上层）
    enum Background {

        /// 主背景（浅色 #FFFFFF / 深色 #000000）
        ///
        /// - 使用场景：页面根背景
        static let primary = dynamic(
            light: "#FFFFFF",
            dark:  "#000000"
        )

        /// 次背景（浅色 #F5F7FA / 深色 #1C1C1E）
        ///
        /// - 使用场景：卡片外的页面背景、分组列表背景
        static let secondary = dynamic(
            light: "#F5F7FA",
            dark:  "#1C1C1E"
        )

        /// 卡片背景（浅色 #FFFFFF / 深色 #2C2C2E）
        ///
        /// - 使用场景：列表 Cell、白色卡片
        static let card = dynamic(
            light: "#FFFFFF",
            dark:  "#2C2C2E"
        )
    }

    // MARK: - Separator

    /// 分隔线 / 边框（浅色 #E5E5EA / 深色 #38383A）
    static let separator = dynamic(
        light: "#E5E5EA",
        dark:  "#38383A"
    )

    // MARK: - Link

    /// 链接色（浅色 #3478F6 / 深色 #0A84FF）
    ///
    /// - 使用场景：协议文本中的可点击链接（《用户注册协议》《隐私政策》）
    /// 
    static let link = dynamic(
        light: "#3478F6",
        dark:  "#0A84FF"
    )
    
    // MARK: - Device (设备控制页专属深色主题)
    
    /// 设备控制页（如 DeviceDetails）专属的沉浸式深色配色
    ///
    /// - Note: 为了与全局的亮/暗主题区分开，这里使用固定色值，不跟随系统切换。
    enum Device {
        /// 页面主背景色（深蓝）
        static let background = UIColor(hex: "#0B102B")
        
        /// 卡片主背景色（深蓝灰）
        static let cardBackground = UIColor(hex: "#25284B")
        
        /// 声音库、睡眠报告背景颜色
        static let soundAndSleepBackground = UIColor(hex: "#343758")
        
        /// 电量胶囊背景绿
        static let batteryGreen = UIColor(hex: "#14C260")
        
        /// 卡片内按钮文字浅蓝
        static let buttonTextLightBlue = UIColor(hex: "#A1C6FF")
        
        /// 列表右侧箭头灰
        static let arrowGray = UIColor(hex: "#8A8A8E")
        
        /// 开关激活状态主题蓝
        static let switchTint = UIColor(hex: "#1C96D5")
    }

    // MARK: - Helper

    /// 构造动态颜色（随系统外观自动切换）
    ///
    /// - Parameters:
    ///   - light: 浅色模式下的 hex 值
    ///   - dark: 深色模式下的 hex 值
    /// - Returns: 动态 UIColor
    /// 
    private static func dynamic(light: String, dark: String) -> UIColor {
        UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(hex: dark)
            case .light, .unspecified:
                return UIColor(hex: light)
            @unknown default:
                return UIColor(hex: light)
            }
        }
    }
}

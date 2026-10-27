//
//  AppFont.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import UIKit

/// 全局字体定义（全部支持 Dynamic Type）
///
enum AppFont {

    // MARK: - Title

    /// 标题字体
    enum Title {

        /// 页面主标题（基准 22pt Bold）
        ///
        /// - 使用场景：导航栏大标题、页面顶部主标题
        static let page: UIFont = scaled(
            size: 22,
            weight: .bold,
            textStyle: .title2
        )

        /// 区块标题（基准 18pt Semibold）
        ///
        /// - 使用场景：列表分组标题、卡片主标题
        static let section: UIFont = scaled(
            size: 18,
            weight: .semibold,
            textStyle: .headline
        )

        /// 卡片标题（基准 17pt Semibold）
        ///
        /// - 使用场景：设备名称、列表项主标题
        static let card: UIFont = scaled(
            size: 17,
            weight: .semibold,
            textStyle: .headline
        )
    }

    // MARK: - Body

    /// 正文字体
    enum Body {

        /// 标准正文（基准 16pt Regular）
        ///
        /// - 使用场景：说明文字、条款正文
        static let regular: UIFont = scaled(
            size: 16,
            weight: .regular,
            textStyle: .body
        )

        /// 强调正文（基准 16pt Medium）
        ///
        /// - 使用场景：列表项主文字、需要视觉强调的正文
        static let emphasized: UIFont = scaled(
            size: 16,
            weight: .medium,
            textStyle: .body
        )

        /// 次要正文（基准 15pt Regular）
        ///
        /// - 使用场景：副标题、说明补充
        static let secondary: UIFont = scaled(
            size: 15,
            weight: .regular,
            textStyle: .subheadline
        )
    }

    // MARK: - Caption

    /// 辅助文字字体（更小、更灰）
    enum Caption {

        /// 标准辅助文字（基准 14pt Regular）
        ///
        /// - 使用场景：时间戳、次要说明、Cell 副标题
        static let regular: UIFont = scaled(
            size: 14,
            weight: .regular,
            textStyle: .footnote
        )

        /// 强调辅助文字（基准 14pt Medium）
        ///
        /// - 使用场景：需要视觉强调的辅助信息
        static let emphasized: UIFont = scaled(
            size: 14,
            weight: .medium,
            textStyle: .footnote
        )

        /// 极小辅助文字（基准 12pt Regular）
        ///
        /// - 使用场景：版本号、法律声明、版权
        static let tiny: UIFont = scaled(
            size: 12,
            weight: .regular,
            textStyle: .caption1
        )
    }

    // MARK: - Button

    /// 按钮字体
    enum Button {

        /// 主按钮（基准 17pt Semibold）
        ///
        /// - 使用场景：登录、注册、保存等主操作按钮
        static let primary: UIFont = scaled(
            size: 17,
            weight: .semibold,
            textStyle: .headline
        )

        /// 次要按钮（基准 15pt Regular）
        ///
        /// - 使用场景：取消、去注册、忘记密码等次要操作
        static let secondary: UIFont = scaled(
            size: 15,
            weight: .regular,
            textStyle: .subheadline
        )
    }

    // MARK: - Mono

    /// 等宽字体
    ///
    /// - 使用场景：MAC 地址、序列号、验证码等需要字符对齐的文本
    ///
    enum Mono {

        /// 等宽正文（基准 15pt Regular）
        ///
        /// - 使用场景：设备 MAC、序列号
        static let regular: UIFont = {
            let base = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
            return UIFontMetrics(forTextStyle: .body).scaledFont(for: base)
        }()

        /// 等宽小字（基准 13pt Regular）
        ///
        /// - 使用场景：紧凑布局中的 MAC / SN
        static let small: UIFont = {
            let base = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            return UIFontMetrics(forTextStyle: .footnote).scaledFont(for: base)
        }()
    }

    // MARK: - Line Height

    /// 标准行高倍数（1.35）
    ///
    /// - 使用场景：多行正文需要设置 `lineHeightMultiple` 时使用，
    ///   避免各处传入不同倍数导致视觉不一致。
    ///   
    static let lineHeightMultiple: CGFloat = 1.35

    // MARK: - Helper

    /// 构造支持 Dynamic Type 的字体
    ///
    /// - Parameters:
    ///   - size: 基准字号（pt）
    ///   - weight: 字重
    ///   - textStyle: 对应的 Apple 语义化样式（决定缩放曲线）
    /// - Returns: 已应用 Dynamic Type 的 `UIFont`
    ///
    private static func scaled(size: CGFloat, weight: UIFont.Weight, textStyle: UIFont.TextStyle) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }
}

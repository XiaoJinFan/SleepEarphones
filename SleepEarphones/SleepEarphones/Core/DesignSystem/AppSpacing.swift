//
//  AppSpacing.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import UIKit

/// 全局间距、圆角、阴影、动画、边框定义
///
enum AppSpacing {

    // MARK: - Insets（内边距 / 间距）

    /// 极小间距：4pt（图标与文字间隙）
    static let xxs: CGFloat = 4

    /// 小间距：8pt（紧密排列的元素之间）
    static let xs: CGFloat = 8

    /// 中小间距：12pt（列表项内部、紧凑卡片内部）
    static let sm: CGFloat = 12

    /// 中间距：16pt（最常用的标准间距、Cell 上下间距）
    static let md: CGFloat = 16

    /// 中大间距：20pt（卡片内部边距、宽松分隔）
    static let lg: CGFloat = 20

    /// 大间距：24pt（区块之间、视觉呼吸感）
    static let xl: CGFloat = 24

    /// 超大间距：32pt（页面级分隔、底部安全距离）
    static let xxl: CGFloat = 32

    // MARK: - Horizontal（常用水平边距）

    /// 页面水平边距：20pt
    ///
    static let horizontal: CGFloat = 20

    /// 卡片水平边距：16pt
    ///
    static let horizontalCard: CGFloat = 16

    // MARK: - Corner（圆角）

    /// 圆角预设
    enum Corner {

        /// 小圆角：4pt（标签、徽章）
        static let small: CGFloat = 4

        /// 中圆角：8pt（输入框、图片、小卡片）
        static let medium: CGFloat = 8

        /// 大圆角：12pt（标准卡片、弹窗）
        static let card: CGFloat = 12

        /// 按钮圆角：10pt
        static let button: CGFloat = 10

        /// 头像圆角：直径的一半
        ///
        /// - Parameter width: 头像宽度
        /// - Returns: 圆形头像所需的圆角值
        ///
        static func avatar(width: CGFloat) -> CGFloat {
            width / 2
        }

        /// 胶囊形（胶囊按钮）
        static let capsule: CGFloat = .greatestFiniteMagnitude
    }

    // MARK: - Shadow（阴影）

    /// 阴影预设
    ///
    /// ## 调用方法
    /// ```swift
    /// AppSpacing.Shadow.card.apply(to: cardView)
    /// ```
    ///
    struct Shadow {

        /// 阴影颜色
        let color: UIColor
        /// 阴影偏移
        let offset: CGSize
        /// 阴影不透明度
        let opacity: Float
        /// 阴影模糊半径
        let radius: CGFloat

        /// 应用到视图的 layer
        ///
        /// - Parameter view: 目标视图
        /// 
        func apply(to view: UIView) {
            view.layer.shadowColor = color.cgColor
            view.layer.shadowOffset = offset
            view.layer.shadowOpacity = opacity
            view.layer.shadowRadius = radius
            // 性能优化：指定阴影路径避免离屏渲染
            view.layer.shadowPath = UIBezierPath(
                roundedRect: view.bounds,
                cornerRadius: view.layer.cornerRadius
            ).cgPath
        }

        /// 卡片阴影：轻微、柔和
        ///
        /// - 使用场景：设备卡片、信息卡片
        static let card = Shadow(
            color: UIColor.black.withAlphaComponent(0.08),
            offset: CGSize(width: 0, height: 2),
            opacity: 1,
            radius: 8
        )

        /// 浮动阴影：明显、有立体感
        ///
        /// - 使用场景：浮层、悬浮按钮
        static let floating = Shadow(
            color: UIColor.black.withAlphaComponent(0.15),
            offset: CGSize(width: 0, height: 4),
            opacity: 1,
            radius: 12
        )
    }

    // MARK: - Animation（动画时长）

    /// 动画时长预设
    ///
    /// - Note: 时长参考 Apple HIG，统一交互节奏。
    enum Animation {

        /// 快速：0.15s（按钮按下反馈、颜色变化）
        static let quick: TimeInterval = 0.15

        /// 标准：0.25s（视图出现/消失、状态切换）
        static let standard: TimeInterval = 0.25

        /// 慢速：0.35s（页面转场、复杂的视图动画）
        static let slow: TimeInterval = 0.35
    }

    // MARK: - Border（边框宽度）

    /// 边框宽度预设
    enum Border {

        /// 细边框：0.5pt（1 物理像素）
        static let hairline: CGFloat = 0.5

        /// 标准边框：1pt
        static let standard: CGFloat = 1

        /// 粗边框：2pt
        static let thick: CGFloat = 2
    }
}

//
//  SearchingAnimationView.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/22.
//

import UIKit
import SnapKit

/// 搜索中的扩散动画视图
///
/// ## 组成
/// - 外围浅蓝装饰圆（固定尺寸）
/// - 中心蓝底 + 蓝牙图标
/// - 3 个扩散圆环（`CALayer` 实现，通过 `CAAnimationGroup` 循环扩散）
///
/// ## 生命周期
/// - `start()`：启动扩散动画（**幂等**——重复调用不叠加）
/// - `stop()`：停止并清除所有动画
/// - `didMoveToWindow`：view 从 window 移除再添加时（如 push / pop）自动恢复动画
///
/// ## 为什么用 `CALayer` 而非 `UIView`
/// - 3 个圆环同步 `transform.scale` + `opacity` 动画——
///   用 `CALayer` 直接操作 GPU 合成层，性能远高于 `UIView.animate`
/// - 圆环不参与 Auto Layout / 响应链，`UIView` 的能力完全浪费
@MainActor
final class SearchingAnimationView: UIView {

    // MARK: - Layout

    private enum Layout {
        /// 中心圆直径
        static let coreDiameter: CGFloat = 80
        /// 最大圆环直径（动画终态）
        static let maxRingDiameter: CGFloat = 240
        /// 圆环数量
        static let ringCount = 3
        /// 单个动画周期（秒）
        static let animationDuration: CFTimeInterval = 3.0
    }

    // MARK: - UI

    /// 中心圆（蓝底 + 蓝牙图标）
    private let coreView: UIView = {
        let v = UIView()
        v.backgroundColor = AppColor.Brand.primary
        v.layer.cornerRadius = Layout.coreDiameter / 2
        v.clipsToBounds = true
        return v
    }()

    /// 蓝牙图标
    private let bluetoothIconView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(
            systemName: "wave.3.right",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        )
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    /// 3 个扩散圆环（`CALayer` 直接操作——不用 UIView，性能更好）
    private var ringLayers: [CALayer] = []

    /// 用户是否希望动画运行（由 `start()` / `stop()` 驱动）
    ///
    /// - Note: 与 `layer.animation(forKey:)` 的状态**解耦**——
    ///         即使动画因 view 移除被系统丢弃，本标志仍为 `true`，
    ///         便于 `didMoveToWindow` 恢复动画。
    private var isAnimating = false

    /// 上次 layout 时的尺寸（用于跳过无变化的重复写入）
    ///
    /// - Note: `layoutSubviews` 会被频繁调用（键盘弹出、旋转、父 view 布局变化等），
    ///         但本视图内部布局只依赖 `bounds`——尺寸不变时无需重复写入 layer 属性。
    private var lastLayoutSize: CGSize = .zero

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupRings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        // 浅蓝背景圆（装饰用——围绕在核心圆外围）
        let outerCircle = UIView()
        outerCircle.backgroundColor = AppColor.Brand.primary.withAlphaComponent(0.08)
        outerCircle.layer.cornerRadius = Layout.maxRingDiameter / 2
        outerCircle.isUserInteractionEnabled = false
        addSubview(outerCircle)

        addSubview(coreView)
        coreView.addSubview(bluetoothIconView)

        outerCircle.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Layout.maxRingDiameter)
        }

        coreView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Layout.coreDiameter)
        }

        bluetoothIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(36)
        }
    }

    /// 创建 3 个扩散圆环（用 `CALayer`——不参与 Auto Layout，性能好）
    private func setupRings() {
        for _ in 0..<Layout.ringCount {
            let ring = CALayer()
            ring.backgroundColor = AppColor.Brand.primary
                .withAlphaComponent(0.15)
                .cgColor
            ring.opacity = 0
            layer.addSublayer(ring)
            ringLayers.append(ring)
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        // 尺寸未变化时跳过——避免键盘弹出 / 父 view 布局等场景的重复写入
        guard bounds.size != lastLayoutSize else { return }
        lastLayoutSize = bounds.size

        // 圆环初始尺寸 = 中心圆直径；动画中由 CABasicAnimation 缩放到 maxRingDiameter
        let size = Layout.coreDiameter
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        for ring in ringLayers {
            ring.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            ring.position = center
            ring.cornerRadius = size / 2
        }
    }

    // MARK: - Window Lifecycle

    /// view 从 window 移除再添加时（如 push / pop）重新应用动画
    ///
    /// ## 背景
    /// `CALayer` 的动画**依附于 render tree**——view 从 window 移除后，
    /// 系统会丢弃其 render tree 上的所有动画。若用户未调用 `stop()`，
    /// 重新添加回 window 时应恢复动画。
    ///
    /// - Note: `addPulseAnimation` 使用固定 `key = "pulse"`——
    ///         重复调用会**替换**旧动画，不会叠加，天然幂等。
    override func didMoveToWindow() {
        super.didMoveToWindow()

        // 只在 window 有效 + 用户希望动画运行时恢复
        guard window != nil, isAnimating else { return }

        for (index, ring) in ringLayers.enumerated() {
            addPulseAnimation(to: ring, index: index)
        }
    }

    // MARK: - Public

    /// 开始扩散动画（幂等）
    func start() {
        guard !isAnimating else { return }
        isAnimating = true

        for (index, ring) in ringLayers.enumerated() {
            addPulseAnimation(to: ring, index: index)
        }
    }

    /// 停止动画
    func stop() {
        guard isAnimating else { return }
        isAnimating = false

        for ring in ringLayers {
            ring.removeAllAnimations()
            ring.opacity = 0
        }
    }

    // MARK: - Private

    /// 给单个圆环添加"缩放 + 淡出"动画
    ///
    /// - Parameters:
    ///   - ring: 目标圆环
    ///   - index: 圆环序号（用于错开 `beginTime`）
    private func addPulseAnimation(to ring: CALayer, index: Int) {
        // 缩放：从 1.0 → maxRingDiameter/coreDiameter
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = Layout.maxRingDiameter / Layout.coreDiameter

        // 透明度：从 0.6 → 0
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.6
        opacity.toValue = 0

        // 组合动画
        let group = CAAnimationGroup()
        group.animations = [scale, opacity]
        group.duration = Layout.animationDuration
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)

        // 三层错开 1/3 周期 —— 形成"连续扩散"效果
        group.beginTime = CACurrentMediaTime()
            + Double(index) * (Layout.animationDuration / Double(Layout.ringCount))

        ring.add(group, forKey: "pulse")
    }
}

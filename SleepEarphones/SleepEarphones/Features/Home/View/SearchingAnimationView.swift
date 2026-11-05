//
//  SearchingAnimationView.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/22.
//

import UIKit
import SnapKit

/// 搜索中的扩散动画视图
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
        /// 圆环初始不透明度
        static let ringInitialOpacity: Float = 0.15
        /// 动画过程中的不透明度起点
        static let ringAnimatingOpacity: Float = 0.6
        /// 蓝牙图标尺寸
        static let bluetoothIconSize: CGFloat = 36
        /// 蓝牙图标 SF Symbol 字号
        static let bluetoothIconPointSize: CGFloat = 32
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
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: Layout.bluetoothIconPointSize,
                weight: .medium
            )
        )
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    /// 外围浅蓝装饰圆
    private let outerCircle = UIView()

    /// 3 个扩散圆环（`CALayer` 直接操作——不用 UIView，性能更好）
    private var ringLayers: [CALayer] = []

    /// 用户是否希望动画运行（由 `start()` / `stop()` 驱动）
    private var isAnimating = false

    /// 上次 layout 时的尺寸（用于跳过无变化的重复写入）
    private var lastLayoutSize: CGSize = .zero

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupRings()
        registerTraitChangeObservation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        // 浅蓝背景圆（装饰用——围绕在核心圆外围）
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
            make.width.height.equalTo(Layout.bluetoothIconSize)
        }
    }

    /// 创建 3 个扩散圆环（用 `CALayer`——不参与 Auto Layout，性能好）
    private func setupRings() {
        for _ in 0..<Layout.ringCount {
            let ring = CALayer()
            ring.backgroundColor = AppColor.Brand.primary
                .withAlphaComponent(CGFloat(Layout.ringInitialOpacity))
                .cgColor
            ring.opacity = 0
            layer.addSublayer(ring)
            ringLayers.append(ring)
        }
    }

    // MARK: - Trait 变化监听

    /// 注册 trait 变化监听
    private func registerTraitChangeObservation() {
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: SearchingAnimationView, _) in
                view.refreshRingColors()
                view.outerCircle.backgroundColor = AppColor.Brand.primary.withAlphaComponent(0.08)
                view.coreView.backgroundColor = AppColor.Brand.primary
            }
        }
    }

    /// 旧版兼容（iOS 17 以下）
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // iOS 17+ 由 registerForTraitChanges 处理，避免重复
        if #available(iOS 17.0, *) { return }

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            refreshRingColors()
            outerCircle.backgroundColor = AppColor.Brand.primary.withAlphaComponent(0.08)
            coreView.backgroundColor = AppColor.Brand.primary
        }
    }

    /// 按当前 trait 刷新所有 ring 的颜色
    private func refreshRingColors() {
        let color = AppColor.Brand.primary
            .withAlphaComponent(CGFloat(Layout.ringInitialOpacity))
            .cgColor
        for ring in ringLayers {
            ring.backgroundColor = color
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
        opacity.fromValue = Layout.ringAnimatingOpacity
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

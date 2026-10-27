//
//  PrimaryButton.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import UIKit
import SnapKit

/// 主按钮
///
/// ## 调用方法
/// ```swift
/// // 1. Storyboard 拖拽（推荐）
/// //    - 将 UIButton 的 Custom Class 设为 PrimaryButton
///
/// // 2. 代码创建
/// let button = PrimaryButton(type: .system)
/// button.setTitle("登录", for: .normal)
/// button.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
///
/// // 3. 切换加载态
/// button.isLoading = true   // 显示菊花、禁用交互、保持亮度
/// button.isLoading = false  // 恢复
/// ```
@MainActor
class PrimaryButton: UIButton {

    // MARK: - Public Properties

    /// 是否处于"加载中"状态
    ///
    /// - `true`：标题透明、显示菊花、**禁止交互但保持亮度**
    /// - `false`：恢复标题、隐藏菊花、恢复交互
    ///
    /// - Note: loading 时**不**改 `isEnabled`——
    ///         改用 `isUserInteractionEnabled = false` 拦截点击，
    ///         避免触发 `updateEnabledState()` 把按钮变暗。
    var isLoading: Bool = false {
        didSet {
            guard isLoading != oldValue else { return }
            updateLoadingState()
        }
    }

    // MARK: - Private UI

    /// 加载指示器
    ///
    /// - Note: 使用 `.medium` 尺寸与标题等高，视觉平衡。
    private lazy var indicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        setupObservers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
        setupObservers()
    }

    // MARK: - Setup

    /// 应用视觉样式
    ///
    /// - Note: 使用 iOS 15+ 的 `UIButton.Configuration.plain()` + 手动 padding，
    ///         不再使用已废弃的 `contentEdgeInsets`。
    private func setupUI() {
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: AppSpacing.md,
            bottom: 0,
            trailing: AppSpacing.md
        )
        // 保留外部 setTitle(_:for:) 的行为（不自动管理标题）
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppFont.Button.primary
            return outgoing
        }
        configuration = config

        // 背景色（正常态 / 高亮态由 handleHighlight 手动控制）
        backgroundColor = AppColor.Brand.primary

        // 圆角
        layer.cornerRadius = AppSpacing.Corner.button
        layer.masksToBounds = true
    }

    /// 菊花居中约束（SnapKit）
    private func setupConstraints() {
        addSubview(indicator)
        indicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    /// 监听 `isHighlighted`，自动驱动视觉状态
    private func setupObservers() {
        addTarget(
            self,
            action: #selector(handleHighlight),
            for: [.touchDown, .touchDragEnter]
        )
        addTarget(
            self,
            action: #selector(handleUnhighlight),
            for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit]
        )
    }

    // MARK: - Layout

    /// 固定高度 46pt（兜底）
    ///
    /// - Note: 若外部用 SnapKit / Auto Layout 设置了 `height`，外部约束优先。
    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.height = 46
        return size
    }

    // MARK: - State Handling

    /// 监听 `isEnabled` 变化
    ///
    /// - Note: 只改 `alpha`，**不**改 `backgroundColor`。
    ///         因为 `handleHighlight` 会临时改 backgroundColor，
    ///         两者并行会冲突。
    override var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            updateEnabledState()
        }
    }

    /// 更新"禁用"视觉
    ///
    /// - Note: 加载中时保持全亮（视觉上"正在进行"，而不是"不可用"）。
    private func updateEnabledState() {
        alpha = (isEnabled || isLoading) ? 1.0 : 0.5
    }

    /// 更新加载态视觉
    ///
    /// - Important: 用 `isUserInteractionEnabled` 而非 `isEnabled` 拦截点击，
    ///              避免按钮变暗。
    private func updateLoadingState() {
        if isLoading {
            indicator.startAnimating()
            // 标题透明：Configuration 模式下用 foregroundColor 控制
            configuration?.baseForegroundColor = .clear
            isUserInteractionEnabled = false
        } else {
            indicator.stopAnimating()
            configuration?.baseForegroundColor = .white
            isUserInteractionEnabled = true
        }
        // 触发一次 alpha 重算（isEnabled 未变，但 isLoading 变了）
        updateEnabledState()
    }

    // MARK: - Highlight Feedback

    /// 按下：背景变深
    @objc private func handleHighlight() {
        guard isEnabled, !isLoading else { return }
        UIView.animate(withDuration: AppSpacing.Animation.quick) {
            self.backgroundColor = AppColor.Brand.primaryPressed
        }
    }

    /// 抬起：恢复主色
    @objc private func handleUnhighlight() {
        UIView.animate(withDuration: AppSpacing.Animation.quick) {
            self.backgroundColor = AppColor.Brand.primary
        }
    }
}

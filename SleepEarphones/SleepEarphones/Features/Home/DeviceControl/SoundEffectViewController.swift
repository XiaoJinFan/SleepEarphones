//
//  SoundEffectViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/30.
//

import UIKit
import SnapKit
import Combine

// MARK: - Model

/// 音效类型枚举
enum SoundEffectType: String, CaseIterable {

    /// 经典
    case defaultEffect = "经典"

    /// 低音增强
    case bassBoost     = "低音增强"

    /// 原声
    case original      = "原声"

    /// 摇滚
    case rock          = "摇滚"

    /// 流行
    case pop           = "流行"

    /// 古典
    case classical     = "古典"

    // MARK: - 展示辅助

    /// 波形图资源名（**保持中文原值，不本地化**）
    ///
    /// - Returns: 中文原值，用于 `UIImage(named:)`
    var imageName: String {
        return rawValue
    }

    /// 展示名称（**已本地化**）
    ///
    /// - Returns: 当前语言下的展示文案（用于按钮标题 / 卡片标题）
    var displayName: String {
        switch self {
        case .defaultEffect: return LN("经典")
        case .bassBoost:     return LN("低音增强")
        case .original:      return LN("原声")
        case .rock:          return LN("摇滚")
        case .pop:           return LN("流行")
        case .classical:     return LN("古典")
        }
    }
}

// MARK: - View Controller

/// 音效设置页面
@MainActor
final class SoundEffectViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let cardCornerRadius: CGFloat = AppSpacing.Corner.card
        static let buttonHeight: CGFloat = 44
        static let cardPadding: CGFloat = 20
        static let cardTitleTop: CGFloat = 20
        static let waveformTopSpacing: CGFloat = 16
        static let waveformHeight: CGFloat = 100
        static let buttonsTopSpacing: CGFloat = 24
        static let buttonsBottomSpacing: CGFloat = 24
        static let buttonsInnerSpacing: CGFloat = 16
        static let cardTopSpacing: CGFloat = 16
        static let cardBottomSpacing: CGFloat = 20
        static let waveformCornerRadius: CGFloat = 8
    }

    // MARK: - Properties

    /// 当前选中的音效类型，初始默认选中"经典"
    @Published private var selectedEffect: SoundEffectType = .defaultEffect

    private var cancellables = Set<AnyCancellable>()

    /// 存储所有按钮，便于更新高亮状态
    private var effectButtons: [UIButton: SoundEffectType] = [:]

    // MARK: - UI

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        return sv
    }()

    private lazy var contentView = UIView()

    /// 主卡片容器
    private lazy var cardView: UIView = {
        let view = UIView()
        view.backgroundColor = AppColor.Background.card
        view.layer.cornerRadius = Layout.cardCornerRadius
        return view
    }()

    /// 卡片内标题（跟随选中的音效变化）
    private lazy var cardTitleLabel: UILabel = {
        let label = UILabel()
        // 初始文本会在 Combine 绑定中自动设置
        label.font = AppFont.Title.section
        label.textColor = AppColor.Text.primary
        return label
    }()

    /// 音效波形图
    private lazy var waveformImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = Layout.waveformCornerRadius
        // 图片加载前的占位底色（设计稿指定的深蓝）
        iv.backgroundColor = UIColor(hex: "#0B143B")
        return iv
    }()

    /// 按钮网格容器
    private lazy var buttonsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Layout.buttonsInnerSpacing
        stack.distribution = .fillEqually
        return stack
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupUI()
        setupConstraints()
        setupButtons()
        setupBindings()
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        // 设置标题（**已本地化**）
        self.title = L("音效")

        // 配置透明导航栏
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: AppColor.Text.primary]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance

        // 返回按钮颜色
        navigationController?.navigationBar.tintColor = AppColor.Text.primary
    }

    private func setupUI() {
        view.backgroundColor = AppColor.Background.secondary

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(cardView)
        cardView.addSubview(cardTitleLabel)
        cardView.addSubview(waveformImageView)
        cardView.addSubview(buttonsStackView)
    }

    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        // 主卡片约束
        cardView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.cardTopSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.bottom.equalToSuperview().offset(-Layout.cardBottomSpacing) // 撑开 contentView
        }

        // 卡片内标题
        cardTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.cardTitleTop)
            make.leading.equalToSuperview().offset(Layout.cardPadding)
        }

        // 波形图约束
        waveformImageView.snp.makeConstraints { make in
            make.top.equalTo(cardTitleLabel.snp.bottom).offset(Layout.waveformTopSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.cardPadding)
            make.height.equalTo(Layout.waveformHeight)
        }

        // 按钮网格约束
        buttonsStackView.snp.makeConstraints { make in
            make.top.equalTo(waveformImageView.snp.bottom).offset(Layout.buttonsTopSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.cardPadding)
            make.bottom.equalToSuperview().offset(-Layout.buttonsBottomSpacing)
        }
    }

    // MARK: - Setup Buttons

    private func setupButtons() {
        let effects = SoundEffectType.allCases

        // 2列3行
        let rows = stride(from: 0, to: effects.count, by: 2).map {
            Array(effects[$0..<min($0 + 2, effects.count)])
        }

        for rowEffects in rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = Layout.buttonsInnerSpacing
            rowStack.distribution = .fillEqually

            for effect in rowEffects {
                let btn = createEffectButton(effect: effect)
                effectButtons[btn] = effect
                rowStack.addArrangedSubview(btn)
            }

            // 如果最后一行只有一个元素，补一个透明占位
            if rowEffects.count == 1 {
                rowStack.addArrangedSubview(UIView())
            }

            buttonsStackView.addArrangedSubview(rowStack)
        }
    }

    /// 创建音效按钮
    ///
    /// - Parameter effect: 音效类型
    /// - Returns: 配置好的按钮
    private func createEffectButton(effect: SoundEffectType) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule

        var titleAttr = AttributedString(effect.displayName)
        titleAttr.font = AppFont.Body.emphasized
        config.attributedTitle = titleAttr

        let btn = UIButton(configuration: config)
        btn.addAction(UIAction { [weak self] _ in
            self?.selectedEffect = effect
        }, for: .touchUpInside)

        return btn
    }

    // MARK: - Bindings

    private func setupBindings() {
        // 监听选中的音效变化
        $selectedEffect
            .receive(on: DispatchQueue.main)
            .sink { [weak self] effect in
                guard let self = self else { return }

                // 1. 切换顶部标题文本（用 `displayName`，已本地化）
                self.cardTitleLabel.text = effect.displayName

                // 2. 切换波形图（用 `imageName`，中文原值，加载资源）
                self.waveformImageView.image = UIImage(named: effect.imageName)

                // 3. 更新所有按钮样式
                self.updateButtonStyles(selectedEffect: effect)
            }
            .store(in: &cancellables)
    }

    // MARK: - UI Updates

    /// 更新按钮高亮状态
    ///
    /// - Parameter selectedEffect: 当前选中的音效
    private func updateButtonStyles(selectedEffect: SoundEffectType) {
        let selectedBgColor = AppColor.Brand.primary
        let selectedTextColor = UIColor.white

        let unselectedBgColor = AppColor.Background.secondary
        let unselectedTextColor = AppColor.Text.primary

        for (btn, effect) in effectButtons {
            let isSelected = (effect == selectedEffect)
            btn.configuration?.baseBackgroundColor =
                isSelected ? selectedBgColor : unselectedBgColor
            btn.configuration?.baseForegroundColor =
                isSelected ? selectedTextColor : unselectedTextColor
        }
    }
}

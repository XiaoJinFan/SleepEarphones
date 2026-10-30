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
///
/// - Note: `rawValue` 直接对应图 2 中的图片资源名称
enum SoundEffectType: String, CaseIterable {
    case defaultEffect = "经典"
    case bassBoost     = "低音增强"
    case original      = "原声"
    case rock          = "摇滚"
    case pop           = "流行"
    case classical     = "古典"
}

// MARK: - View Controller

/// 音效设置页面
@MainActor
final class SoundEffectViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let cardCornerRadius: CGFloat = 16
        static let buttonHeight: CGFloat = 44
    }

    // MARK: - Properties

    /// 当前选中的音效类型，初始默认选中“经典”
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
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = AppColor.Text.primary
        return label
    }()

    /// 音效波形图
    private lazy var waveformImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 8
        iv.backgroundColor = UIColor(hex: "#0B143B") // 图片加载前的占位底色
        return iv
    }()

    /// 按钮网格容器
    private lazy var buttonsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
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
        // 设置标题
        self.title = "音效"
        
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
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.bottom.equalToSuperview().offset(-20) // 撑开 contentView
        }

        // 卡片内标题
        cardTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalToSuperview().offset(20)
        }

        // 波形图约束
        waveformImageView.snp.makeConstraints { make in
            make.top.equalTo(cardTitleLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(100) // 根据设计图比例设定高度
        }

        // 按钮网格约束
        buttonsStackView.snp.makeConstraints { make in
            make.top.equalTo(waveformImageView.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().offset(-24)
        }
    }

    // MARK: - Setup Buttons

    private func setupButtons() {
        let effects = SoundEffectType.allCases
        
        // 2列3行
        let rows = stride(from: 0, to: effects.count, by: 2).map { Array(effects[$0..<min($0 + 2, effects.count)]) }
        
        for rowEffects in rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 16
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

    private func createEffectButton(effect: SoundEffectType) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        
        var titleAttr = AttributedString(effect.rawValue)
        titleAttr.font = .systemFont(ofSize: 16, weight: .semibold)
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
                
                // 1. 切换顶部标题文本
                self.cardTitleLabel.text = effect.rawValue
                
                // 2. 切换波形图
                self.waveformImageView.image = UIImage(named: effect.rawValue)
                
                // 3. 更新所有按钮样式
                self.updateButtonStyles(selectedEffect: effect)
            }
            .store(in: &cancellables)
    }

    // MARK: - UI Updates

    /// 更新按钮高亮状态
    private func updateButtonStyles(selectedEffect: SoundEffectType) {
        let selectedBgColor = AppColor.Brand.primary
        let selectedTextColor = UIColor.white
        
        let unselectedBgColor = AppColor.Background.secondary
        let unselectedTextColor = AppColor.Text.primary
        
        for (btn, effect) in effectButtons {
            let isSelected = (effect == selectedEffect)
            btn.configuration?.baseBackgroundColor = isSelected ? selectedBgColor : unselectedBgColor
            btn.configuration?.baseForegroundColor = isSelected ? selectedTextColor : unselectedTextColor
        }
    }
}

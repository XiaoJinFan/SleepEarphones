//
//  GuestViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/30.
//

import UIKit
import SnapKit
import Combine

// MARK: - Enums & Models

/// 耳机左右耳选择枚举
enum EarType: CaseIterable {
    case left
    case right
    
    var title: String {
        switch self {
        case .left: return "左耳"
        case .right: return "右耳"
        }
    }
}

/// 耳机的操作类型
enum GestureAction: String, CaseIterable {
    case doubleTap = "双击"
    case tripleTap = "三击"
    
    /// 指示点的数量
    var dotCount: Int {
        switch self {
        case .doubleTap: return 2
        case .tripleTap: return 3
        }
    }
}

/// 左右耳独立的配置模型
struct EarSettings {
    var doubleTap: EarAction
    var tripleTap: EarAction
    
    // 默认配置
    static let `default` = EarSettings(doubleTap: .volumeUp, tripleTap: .next)
}

// MARK: - View Controller

/// 耳机控制页面
@MainActor
final class GuestViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let cardCornerRadius: CGFloat = 16
        static let selectionButtonHeight: CGFloat = 44
    }

    // MARK: - Properties

    /// 当前选中的耳朵
    @Published private var selectedEar: EarType = .left
    
    /// 左耳的独立配置
    @Published private var leftEarSettings: EarSettings = .default
    
    /// 右耳的独立配置
    @Published private var rightEarSettings: EarSettings = .default
    
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI - 左耳/右耳选择卡片

    private lazy var earSelectionCard: UIView = {
        let view = UIView()
        view.backgroundColor = AppColor.Background.card
        view.layer.cornerRadius = Layout.cardCornerRadius
        return view
    }()

    private lazy var leftEarImageView: UIImageView = createEarImageView()
    private lazy var rightEarImageView: UIImageView = createEarImageView()

    private lazy var leftButton: UIButton = createSelectionButton(title: "左耳", ear: .left)
    private lazy var rightButton: UIButton = createSelectionButton(title: "右耳", ear: .right)

    private lazy var earButtonsStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [leftButton, rightButton])
        stack.axis = .horizontal
        stack.spacing = 16
        stack.distribution = .fillEqually
        return stack
    }()

    // MARK: - UI - 操作列表卡片及副标题引用

    private lazy var doubleTapSubtitleLabel: UILabel = createSubtitleLabel()
    private lazy var tripleTapSubtitleLabel: UILabel = createSubtitleLabel()

    private lazy var doubleTapCard: UIView = createActionCard(
        action: .doubleTap,
        subtitleLabel: doubleTapSubtitleLabel
    )
    
    private lazy var tripleTapCard: UIView = createActionCard(
        action: .tripleTap,
        subtitleLabel: tripleTapSubtitleLabel
    )

    // MARK: - UI - 重置按钮

    private lazy var resetButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("重置操作", for: .normal)
        btn.setTitleColor(AppColor.Brand.primary, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        btn.addTarget(self, action: #selector(resetButtonTapped), for: .touchUpInside)
        return btn
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupUI()
        setupConstraints()
        setupBindings()
    }
    
    // MARK: - NavigationBar
    
    private func setupNavigationBar() {
        // 设置标题
        self.title = "手势控制"
        
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

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = AppColor.Background.secondary
        
        leftEarImageView.image = UIImage(named: "左耳背景")
        rightEarImageView.image = UIImage(named: "右耳背景")

        // 1. 添加耳机选择卡片
        view.addSubview(earSelectionCard)
        earSelectionCard.addSubview(leftEarImageView)
        earSelectionCard.addSubview(rightEarImageView)
        earSelectionCard.addSubview(earButtonsStack)

        // 2. 添加操作列表卡片
        view.addSubview(doubleTapCard)
        view.addSubview(tripleTapCard)

        // 3. 添加重置按钮
        view.addSubview(resetButton)
    }

    private func setupConstraints() {
        // --- 选择卡片 ---
        earSelectionCard.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(16)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        // 耳机图片布局
        leftEarImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(30)
            make.leading.equalToSuperview().offset(40)
            make.width.height.equalTo(100)
        }

        rightEarImageView.snp.makeConstraints { make in
            make.top.equalTo(leftEarImageView)
            make.trailing.equalToSuperview().offset(-40)
            make.width.height.equalTo(100)
        }

        // 底部按钮布局
        earButtonsStack.snp.makeConstraints { make in
            make.top.equalTo(leftEarImageView.snp.bottom).offset(30)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(Layout.selectionButtonHeight)
            make.bottom.equalToSuperview().offset(-24)
        }

        // --- 操作列表卡片 ---
        doubleTapCard.snp.makeConstraints { make in
            make.top.equalTo(earSelectionCard.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.height.equalTo(90)
        }

        tripleTapCard.snp.makeConstraints { make in
            make.top.equalTo(doubleTapCard.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.height.equalTo(90)
        }

        // --- 重置按钮 ---
        resetButton.snp.makeConstraints { make in
            make.top.equalTo(tripleTapCard.snp.bottom).offset(30)
            make.centerX.equalToSuperview()
            make.height.equalTo(44)
        }
    }

    // MARK: - Bindings

    private func setupBindings() {
        Publishers.CombineLatest3($selectedEar, $leftEarSettings, $rightEarSettings)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ear, leftSettings, rightSettings in
                guard let self = self else { return }
                
                self.updateEarButtonStyles(selectedEar: ear)
                
                let currentSettings = (ear == .left) ? leftSettings : rightSettings
                
                self.doubleTapSubtitleLabel.text = currentSettings.doubleTap.rawValue
                self.tripleTapSubtitleLabel.text = currentSettings.tripleTap.rawValue
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func earButtonTapped(_ sender: UIButton) {
        let ear: EarType = (sender.tag == 0) ? .left : .right
        if selectedEar != ear {
            selectedEar = ear
        }
    }

    @objc private func resetButtonTapped() {
        AppLog.device.debug("点击重置操作")
        showConfirm(
            title: "重置操作",
            message: "确定要将左右耳的双击/三击操作恢复为默认设置吗？",
            destructive: true
        ) { [weak self] in
            self?.leftEarSettings = .default
            self?.rightEarSettings = .default
            self?.showToast("操作已重置")
        }
    }

    private func actionCardTapped(action: GestureAction) {
        // 1. 拦截判断：检查敲击功能是否被禁用
        let isTouchEnabled = UserDefaults.standard.object(forKey: "device_touch_function_enabled") as? Bool ?? true
        guard isTouchEnabled else {
            showToast("敲击功能已被禁用，请重新开启")
            return
        }
        
        AppLog.device.debug("点击操作：\(action.rawValue)")
        
        let currentEar = selectedEar
        let currentSettings = (currentEar == .left) ? leftEarSettings : rightEarSettings
        let currentAction: EarAction = (action == .doubleTap) ? currentSettings.doubleTap : currentSettings.tripleTap
        
        let pickerVC = ActionPickerViewController(
            actionTitle: "\(currentEar.title)\(action.rawValue)",
            currentAction: currentAction
        ) { [weak self] newAction in
            guard let self = self else { return }
            
            if currentEar == .left {
                if action == .doubleTap {
                    self.leftEarSettings.doubleTap = newAction
                } else {
                    self.leftEarSettings.tripleTap = newAction
                }
            } else {
                if action == .doubleTap {
                    self.rightEarSettings.doubleTap = newAction
                } else {
                    self.rightEarSettings.tripleTap = newAction
                }
            }
            
            AppLog.device.debug("\(currentEar.title)的\(action.rawValue)已设置为: \(newAction.rawValue)")
            self.showToast("设置成功")
        }
        
        present(pickerVC, animated: false)
    }
}

// MARK: - UI Factory Methods

extension GuestViewController {
    
    private func createEarImageView() -> UIImageView {
        let iv = UIImageView()
        iv.image = UIImage(
            systemName: "headphones",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 80, weight: .light)
        )
        iv.tintColor = .lightGray
        iv.contentMode = .scaleAspectFit
        return iv
    }

    private func createSelectionButton(title: String, ear: EarType) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.baseForegroundColor = AppColor.Text.primary
        config.baseBackgroundColor = AppColor.Background.secondary
        config.cornerStyle = .capsule
        
        var titleAttr = AttributedString(title)
        titleAttr.font = .systemFont(ofSize: 16, weight: .semibold)
        config.attributedTitle = titleAttr
        
        let btn = UIButton(configuration: config)
        btn.tag = (ear == .left) ? 0 : 1
        btn.addTarget(self, action: #selector(earButtonTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func updateEarButtonStyles(selectedEar: EarType) {
        let selectedColor = AppColor.Brand.primary
        let unselectedColor = AppColor.Background.secondary
        
        leftButton.configuration?.baseBackgroundColor = (selectedEar == .left) ? selectedColor : unselectedColor
        leftButton.configuration?.baseForegroundColor = (selectedEar == .left) ? .white : AppColor.Text.primary
        
        rightButton.configuration?.baseBackgroundColor = (selectedEar == .right) ? selectedColor : unselectedColor
        rightButton.configuration?.baseForegroundColor = (selectedEar == .right) ? .white : AppColor.Text.primary
    }

    private func createSubtitleLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = AppColor.Text.secondary
        return label
    }

    /// 创建操作列表卡片（双击/三击）
    private func createActionCard(action: GestureAction, subtitleLabel: UILabel) -> UIView {
        let card = UIView()
        card.backgroundColor = AppColor.Background.card
        card.layer.cornerRadius = Layout.cardCornerRadius
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleCardTap(_:)))
        card.addGestureRecognizer(tap)
        card.tag = (action == .doubleTap) ? 10 : 11
        
        // --- 左侧圆点固定容器 ---
        // 使用固定宽度的容器，保证所有卡片的文字起始点绝对对齐
        let dotsContainer = UIView()
        card.addSubview(dotsContainer)
        
        let dotsStack = UIStackView()
        dotsStack.axis = .horizontal
        dotsStack.spacing = 6
        dotsStack.alignment = .center
        
        for _ in 0..<action.dotCount {
            let dot = UIView()
            dot.backgroundColor = AppColor.Brand.primary
            dot.layer.cornerRadius = 6
            dot.snp.makeConstraints { make in
                make.width.height.equalTo(12)
            }
            dotsStack.addArrangedSubview(dot)
        }
        dotsContainer.addSubview(dotsStack)
        
        // --- 中间标题 ---
        let titleLabel = UILabel()
        titleLabel.text = action.rawValue
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = AppColor.Text.primary
        card.addSubview(titleLabel)
        
        // --- 中间副标题 ---
        card.addSubview(subtitleLabel)
        
        // --- 右侧箭头 ---
        let arrowView = UIImageView(
            image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        )
        arrowView.tintColor = AppColor.Text.tertiary
        arrowView.contentMode = .scaleAspectFit
        card.addSubview(arrowView)
        
        // --- 约束布局 ---
        // 圆点容器约束：固定宽度 48（刚好容纳3个圆点 + 间距）
        dotsContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.equalTo(48)
            make.height.equalTo(20)
        }
        
        dotsStack.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }
        
        // 标题约束：绑定在圆点容器的尾部
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(dotsContainer.snp.trailing).offset(16)
            make.top.equalToSuperview().offset(24)
        }
        
        // 副标题：与标题左对齐
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
        }
        
        arrowView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
        
        return card
    }

    @objc private func handleCardTap(_ sender: UITapGestureRecognizer) {
        guard let tag = sender.view?.tag else { return }
        if tag == 10 {
            actionCardTapped(action: .doubleTap)
        } else {
            actionCardTapped(action: .tripleTap)
        }
    }
}

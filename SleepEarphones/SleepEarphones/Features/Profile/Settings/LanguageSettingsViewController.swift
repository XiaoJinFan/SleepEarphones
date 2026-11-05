//
//  LanguageSettingsViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import UIKit
import SnapKit

/// 语言设置页
///
/// ## 职责
/// - 展示 App 支持的所有语言（`AppLanguage.allCases`）
/// - 单选 + 底部"确定"按钮提交
/// - 提交后调用 `LanguageManager.changeLanguage(to:)` → 重建整个 UI
///
/// ## 交互流程
/// ```
/// 进入本页 → 初始选中 LanguageManager.current
///   ↓ 用户点击其他语言
/// 仅更新本地 selectedLanguage + 勾选样式（**不提交**）
///   ↓ 用户点击"确定"
///   ├─ 语言未变化 → 直接 pop
///   └─ 语言变化 → LanguageManager.changeLanguage(to:)
///                    ↓
///                  AppRouter.reloadRoot() —— 整棵 UI 树重建
///                    ↓
///                  本页被销毁（无需手动 pop）
/// ```
@MainActor
final class LanguageSettingsViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        /// 卡片圆角
        static let cardCornerRadius: CGFloat = AppSpacing.Corner.card
        /// 卡片水平边距
        static let horizontalInset: CGFloat = AppSpacing.md
        /// 卡片上下边距
        static let cardVerticalInset: CGFloat = AppSpacing.md
        /// 分隔线左右缩进
        static let separatorInset: CGFloat = AppSpacing.lg
        /// 分隔线高度
        static let separatorHeight: CGFloat = AppSpacing.Border.hairline
        /// 底部按钮高度
        static let confirmButtonHeight: CGFloat = 46
        /// 底部按钮水平边距
        static let confirmButtonHorizontalInset: CGFloat = AppSpacing.horizontal
        /// 底部按钮距 safeArea 底部距离
        static let confirmButtonBottomOffset: CGFloat = AppSpacing.xxl
        /// 按钮与 ScrollView 的间距
        static let scrollBottomToButtonSpacing: CGFloat = AppSpacing.md
    }

    // MARK: - Properties

    /// 当前选中的语言（**本地状态，点击"确定"才提交**）
    private var selectedLanguage: AppLanguage

    /// 所有支持的语言
    private let languages: [AppLanguage] = AppLanguage.allCases

    // MARK: - UI

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.backgroundColor = .clear
        // ⚠️ 关键：开启后 Auto Layout 才能正确推导内容尺寸
        sv.contentInsetAdjustmentBehavior = .automatic
        return sv
    }()

    private lazy var cardView: UIView = {
        let v = UIView()
        v.backgroundColor = AppColor.Background.card
        v.layer.cornerRadius = Layout.cardCornerRadius
        v.clipsToBounds = true
        return v
    }()

    private lazy var rowStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 0
        s.alignment = .fill
        // ⚠️ 关键：让 stackView 完整展示所有 arrangedSubview
        s.distribution = .fill
        return s
    }()

    private var rowViews: [LanguageRowView] = []

    private lazy var confirmButton: UIButton = {
        let b = UIButton(type: .system)
        // **按钮标题已本地化**
        b.setTitle(L("确定"), for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = AppFont.Button.primary
        b.backgroundColor = AppColor.Brand.primary
        b.layer.cornerRadius = AppSpacing.Corner.button
        b.clipsToBounds = true
        b.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        return b
    }()

    // MARK: - Init

    /// 初始化
    init() {
        self.selectedLanguage = LanguageManager.shared.current
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        buildRows()
    }

    // MARK: - Setup

    private func setupUI() {
        // **导航标题已本地化**
        title = L("语言设置")
        view.backgroundColor = AppColor.Background.secondary
        navigationItem.backButtonDisplayMode = .minimal

        view.addSubview(scrollView)
        scrollView.addSubview(cardView)
        cardView.addSubview(rowStack)

        view.addSubview(confirmButton)
    }

    private func setupConstraints() {
        // MARK: Confirm Button（先约束被引用者，便于阅读）
        confirmButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
                .inset(Layout.confirmButtonHorizontalInset)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
                .offset(-Layout.confirmButtonBottomOffset)
            make.height.equalTo(Layout.confirmButtonHeight)
        }

        // MARK: ScrollView
        scrollView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(confirmButton.snp.top)
                .offset(-Layout.scrollBottomToButtonSpacing)
        }

        // MARK: CardView
        cardView.snp.makeConstraints { make in
            make.top.equalTo(scrollView.contentLayoutGuide)
                .offset(Layout.cardVerticalInset)
            make.bottom.equalTo(scrollView.contentLayoutGuide)
                .offset(-Layout.cardVerticalInset)
            make.leading.trailing.equalTo(scrollView.frameLayoutGuide)
                .inset(Layout.horizontalInset)
        }

        // MARK: RowStack
        rowStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    /// 构造语言列表
    private func buildRows() {
        for (index, language) in languages.enumerated() {
            // 非首行插入分隔线
            if index > 0 {
                rowStack.addArrangedSubview(makeSeparator())
            }

            let row = LanguageRowView(language: language)
            row.onTap = { [weak self] in
                self?.selectLanguage(language)
            }
            rowStack.addArrangedSubview(row)
            rowViews.append(row)
        }

        refreshSelection()
    }

    /// 构造分隔线
    ///
    /// - Returns: 分隔线视图
    private func makeSeparator() -> UIView {
        let container = UIView()
        let line = UIView()
        line.backgroundColor = AppColor.separator
        container.addSubview(line)

        line.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Layout.separatorInset)
            make.centerY.equalToSuperview()
            make.height.equalTo(Layout.separatorHeight)
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(Layout.separatorHeight)
        }
        return container
    }

    // MARK: - Selection

    /// 选中指定语言（仅更新本地状态 + UI，**未提交**）
    ///
    /// - Parameter language: 目标语言
    private func selectLanguage(_ language: AppLanguage) {
        guard language != selectedLanguage else { return }
        selectedLanguage = language
        refreshSelection()
    }

    /// 刷新所有行的选中状态
    private func refreshSelection() {
        for row in rowViews {
            row.setSelected(row.language == selectedLanguage)
        }
    }

    // MARK: - Actions

    /// 点击「确定」
    @objc private func confirmTapped() {
        guard selectedLanguage != LanguageManager.shared.current else {
            // 语言未变化：直接返回
            navigationController?.popViewController(animated: true)
            return
        }

        // 语言变化：`changeLanguage` 内部会 `reloadRoot` 重建 UI
        // （本页会被销毁，无需手动 pop）
        LanguageManager.shared.changeLanguage(to: selectedLanguage)
    }
}

// MARK: - 语言行视图

/// 单行语言视图（卡片内部使用）
@MainActor
private final class LanguageRowView: UIView {

    // MARK: - Constants

    private enum Layout {
        /// 水平内边距
        static let horizontalPadding: CGFloat = AppSpacing.lg
        /// 垂直内边距（上下各 20pt → 行高 60pt）
        static let verticalPadding: CGFloat = AppSpacing.lg
        /// 勾选图标尺寸
        static let checkmarkSize: CGFloat = 20
    }

    // MARK: - Public

    /// 本行对应的语言
    let language: AppLanguage

    /// 点击回调
    var onTap: (() -> Void)?

    // MARK: - UI

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Body.regular
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    private let checkmarkImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "checkmark")
        iv.tintColor = AppColor.Brand.primary
        iv.contentMode = .scaleAspectFit
        iv.isHidden = true
        return iv
    }()

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter language: 本行对应的语言
    init(language: AppLanguage) {
        self.language = language
        super.init(frame: .zero)
        setupUI()
        setupGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("LanguageRowView 只支持代码初始化")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = AppColor.Background.card

        // **`displayName` 是母语原生写法，不参与国际化**
        titleLabel.text = language.displayName
        addSubview(titleLabel)
        addSubview(checkmarkImageView)

        // ✅ 关键：只用 top/bottom 撑起行高——**不要**再给 centerY，
        //    否则与 top/bottom 形成过度约束（top + height = bottom 已隐含 centerY）
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.horizontalPadding)
            make.top.equalToSuperview().offset(Layout.verticalPadding)
            make.bottom.equalToSuperview().offset(-Layout.verticalPadding)
            make.trailing.lessThanOrEqualTo(checkmarkImageView.snp.leading)
                .offset(-AppSpacing.sm)
        }

        checkmarkImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Layout.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.checkmarkSize)
        }
    }

    private func setupGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    /// 点击处理
    @objc private func handleTap() {
        onTap?()
    }

    // MARK: - Public

    /// 设置选中状态
    ///
    /// - Parameter selected: 是否选中
    func setSelected(_ selected: Bool) {
        checkmarkImageView.isHidden = !selected
    }

    // MARK: - Highlight（按下反馈）
    
    /// 按下时背景变深
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        backgroundColor = AppColor.Background.secondary
    }

    /// 抬起时恢复背景
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        backgroundColor = AppColor.Background.card
    }

    /// 取消时恢复背景
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        backgroundColor = AppColor.Background.card
    }
}

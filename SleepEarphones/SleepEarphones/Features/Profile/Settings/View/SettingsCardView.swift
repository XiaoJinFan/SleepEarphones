//
//  SettingsCardView.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import UIKit
import SnapKit

// MARK: - 数据模型

/// 单个设置项
///
/// ## 调用方法
/// ```swift
/// // 1. 可点击项（尾随闭包）
/// SettingsItem(title: L("账号与安全")) { openAccountSecurity() }
///
/// // 2. 展示值 + 无箭头（如"当前版本"）
/// SettingsItem(title: L("当前版本"), value: "V1.0.0", showsArrow: false, action: nil)
///
/// // 3. 完整参数
/// SettingsItem(
///     title: L("语言设置"),
///     value: nil,
///     showsArrow: true,
///     action: { openLanguage() }
/// )
/// ```
struct SettingsItem {

    /// 标题（左侧，**调用方负责本地化**）
    let title: String

    /// 右侧文字（如 `"V1.0.1"`）；传 nil 时不显示
    let value: String?

    /// 是否显示右箭头
    let showsArrow: Bool

    /// 点击回调；传 nil 时整行不可点击（如"当前版本"）
    let action: (() -> Void)?

    /// 便利构造
    ///
    /// - Parameters:
    ///   - title: 标题
    ///   - value: 右侧文字（默认 nil）
    ///   - showsArrow: 是否显示箭头（默认 true）
    ///   - action: 点击回调（默认 nil，不可点击）
    init(title: String, value: String? = nil, showsArrow: Bool = true, action: (() -> Void)? = nil) {
        self.title = title
        self.value = value
        self.showsArrow = showsArrow
        self.action = action
    }
}

// MARK: - 卡片视图

/// 设置卡片（多行组成一张圆角卡片）
@MainActor
final class SettingsCardView: UIView {

    // MARK: - Constants

    private enum Layout {
        /// 卡片圆角
        static let cornerRadius: CGFloat = AppSpacing.Corner.card
        /// 行高
        static let rowHeight: CGFloat = 60
        /// 分隔线左右缩进
        static let separatorInset: CGFloat = AppSpacing.lg
        /// 分隔线高度
        static let separatorHeight: CGFloat = AppSpacing.Border.hairline
    }

    // MARK: - UI

    /// 承载所有行的垂直栈
    private lazy var contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 0
        s.alignment = .fill
        return s
    }()

    // MARK: - Init

    /// 用设置项数组构造卡片
    ///
    /// - Parameter items: 设置项列表（`title` / `value` 已由调用方本地化）
    init(items: [SettingsItem]) {
        super.init(frame: .zero)
        setupUI()
        buildRows(items)
    }

    /// - Note: 本视图**不支持**从 Storyboard / XIB 初始化。
    ///         必须走 `init(items:)`，因此此处 fatalError 是合理兜底。
    required init?(coder: NSCoder) {
        fatalError("SettingsCardView 只支持代码初始化，请使用 init(items:)")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = AppColor.Background.card
        layer.cornerRadius = Layout.cornerRadius
        clipsToBounds = true

        addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    /// 逐行构建 UI
    ///
    /// - Parameter items: 设置项列表
    private func buildRows(_ items: [SettingsItem]) {
        for (index, item) in items.enumerated() {
            if index > 0 {
                contentStack.addArrangedSubview(makeSeparator())
            }
            contentStack.addArrangedSubview(makeRow(item))
        }
    }

    /// 构造分隔线
    ///
    /// - Returns: 分隔线视图（外层容器用于撑高度，内层 line 做左右缩进）
    private func makeSeparator() -> UIView {
        let container = UIView()
        let line = UIView()
        line.backgroundColor = AppColor.separator
        container.addSubview(line)

        line.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Layout.separatorInset)
            make.height.equalTo(Layout.separatorHeight)
            make.centerY.equalToSuperview()
        }

        container.snp.makeConstraints { make in
            make.height.equalTo(Layout.separatorHeight)
        }
        return container
    }

    /// 构造单行
    ///
    /// - Parameter item: 设置项
    /// - Returns: 单行视图
    private func makeRow(_ item: SettingsItem) -> UIView {
        let row = SettingsRowView(item: item)
        row.snp.makeConstraints { make in
            make.height.equalTo(Layout.rowHeight)
        }
        return row
    }
}

// MARK: - 单行视图

/// 单行设置项视图（卡片内部使用）
@MainActor
private final class SettingsRowView: UIView {

    // MARK: - Constants

    private enum Layout {
        /// 水平内边距
        static let horizontalPadding: CGFloat = AppSpacing.lg
        /// 箭头尺寸
        static let arrowSize: CGFloat = 16
        /// 值与箭头之间的间距
        static let valueArrowGap: CGFloat = AppSpacing.xs
        /// 标题与值之间的最小间距
        static let titleToValueGap: CGFloat = AppSpacing.sm
    }

    // MARK: - UI

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Body.regular
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 1
        // 标题过长时尾部截断（而非压缩到 0 宽度）
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    private let valueLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Caption.regular
        l.textColor = AppColor.Text.secondary
        l.textAlignment = .right
        l.numberOfLines = 1
        // 值过长时尾部截断
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    private let arrowImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = AppImage.System.chevronRight
        iv.tintColor = AppColor.Text.tertiary
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    /// 点击回调（nil 表示不可点击）
    private let action: (() -> Void)?

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter item: 设置项
    init(item: SettingsItem) {
        self.action = item.action
        super.init(frame: .zero)

        titleLabel.text = item.title
        valueLabel.text = item.value
        valueLabel.isHidden = (item.value == nil || item.value?.isEmpty == true)
        arrowImageView.isHidden = !item.showsArrow

        setupUI()
        setupGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("SettingsRowView 只支持代码初始化")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = AppColor.Background.card

        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(arrowImageView)

        // 标题（左侧）
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.horizontalPadding)
            make.centerY.equalToSuperview()
        }

        // 箭头（最右侧，优先占位）
        arrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Layout.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.arrowSize)
        }

        // 右侧文字（箭头左侧）
        valueLabel.snp.makeConstraints { make in
            make.trailing.equalTo(arrowImageView.snp.leading)
                .offset(-Layout.valueArrowGap)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing)
                .offset(Layout.titleToValueGap)
        }

        // 无箭头时，右侧文字贴右边缘
        if arrowImageView.isHidden {
            valueLabel.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().offset(-Layout.horizontalPadding)
                make.centerY.equalToSuperview()
                make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing)
                    .offset(Layout.titleToValueGap)
            }
        }
    }

    /// 添加点击手势
    private func setupGesture() {
        guard action != nil else { return }

        isUserInteractionEnabled = true
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(gesture)
    }

    /// 点击处理
    @objc private func handleTap() {
        action?()
    }

    // MARK: - Highlight（按下反馈）

    /// 按下时背景变深
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard action != nil else { return }
        backgroundColor = AppColor.Background.secondary
    }

    /// 抬起时恢复背景
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard action != nil else { return }
        backgroundColor = AppColor.Background.card
    }

    /// 取消时恢复背景
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        guard action != nil else { return }
        backgroundColor = AppColor.Background.card
    }
}

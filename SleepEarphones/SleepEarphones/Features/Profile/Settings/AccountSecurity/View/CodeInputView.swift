//
//  CodeInputView.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/30.
//

import UIKit
import SnapKit

/// 验证码输入框（4 位 / 6 位可配置）
///
/// ## 交互
/// - 点击任意位置 → 唤起系统键盘（隐藏的 `UITextField`）
/// - 输入时数字回填到方框
/// - 支持删除（回退键）
///
/// ## 调用方法
/// ```swift
/// // 1. 创建（默认 4 位）
/// let codeView = CodeInputView()
///
/// // 2. 6 位验证码
/// let codeView = CodeInputView(length: 6)
///
/// // 3. 读取当前输入
/// let code = codeView.code
///
/// // 4. 监听变化
/// codeView.onCodeChanged = { code in print("输入：\(code)") }
///
/// // 5. 监听输入完成（达到 length 时**只触发一次**）
/// codeView.onComplete = { code in submit(code) }
///
/// // 6. 清空 / 编程填充
/// codeView.clear()
/// codeView.setCode("1234")
///
/// // 7. 主动收起键盘（外部调用，**会**转发到隐藏输入框）
/// codeView.resignFirstResponder()
/// ```
@MainActor
final class CodeInputView: UIView {

    // MARK: - Public

    /// 长度（4 位 / 6 位）
    let length: Int

    /// 当前验证码（只读）
    ///
    /// - Returns: 已输入的数字字符串（长度 ≤ `length`）
    var code: String { _code }

    /// 验证码变化回调（每次输入都触发）
    ///
    /// - Parameter code: 变化后的完整验证码字符串
    var onCodeChanged: ((String) -> Void)?

    /// 输入完成回调（达到 `length` 长度时**只触发一次**）
    ///
    /// - Parameter code: 完整验证码
    var onComplete: ((String) -> Void)?

    // MARK: - Private

    /// 内部存储的验证码（`didSet` 触发 UI 刷新）
    private var _code: String = "" {
        didSet { refreshBoxes() }
    }

    /// 是否已上报过 `onComplete`（用于**只触发一次**）
    private var hasReportedComplete = false

    /// 隐藏的 `UITextField`（真正接收输入）
    private let hiddenField: UITextField = {
        let tf = UITextField()
        tf.keyboardType = .numberPad
        tf.textContentType = .oneTimeCode  // 支持系统短信验证码自动填充
        // ✅ 关键：alpha 接近 0 但非 0 —— 保证可以成为 first responder
        tf.alpha = 0.01
        tf.tintColor = .clear  // 光标也隐藏
        return tf
    }()

    /// 每个方框（UIView 容器）
    private var boxes: [UIView] = []

    /// 每个方框内的数字 label
    private var labels: [UILabel] = []

    // MARK: - Layout

    private enum Layout {
        /// 方框边长
        static let boxSize: CGFloat = 50
        /// 方框间距
        static let boxSpacing: CGFloat = 12
        /// 方框圆角
        static let boxCornerRadius: CGFloat = 6
        /// 未聚焦边框宽度
        static let boxBorderWidth: CGFloat = 1
        /// 聚焦时边框宽度
        static let boxBorderWidthFocused: CGFloat = 2
    }

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter length: 验证码长度（默认 4 位）
    init(length: Int = 4) {
        self.length = length
        super.init(frame: .zero)
        setupUI()
        setupActions()
        setupNotifications()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 释放时移除通知观察者
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Intrinsic Content Size

    /// 默认尺寸（外部无约束时使用）
    ///
    /// - 宽度 = `length × 50 + (length - 1) × 12`
    ///   - 4 位：236
    ///   - 6 位：360
    /// - 高度 = 50
    ///
    /// - Note: 外部若已设 `height` / `width` 约束，这两者兼容；
    ///         若外部只约束了位置，本属性提供 fallback。
    override var intrinsicContentSize: CGSize {
        CGSize(
            width: CGFloat(length) * Layout.boxSize
                 + CGFloat(length - 1) * Layout.boxSpacing,
            height: Layout.boxSize
        )
    }

    // MARK: - Public API

    /// 清空输入
    func clear() {
        _code = ""
        hiddenField.text = ""
        hasReportedComplete = false
        onCodeChanged?("")   // 通知外部
    }

    /// 以编程方式填入验证码（如 DEBUG 自动填充）
    ///
    /// - Parameter code: 待填入的验证码（超过 `length` 会被截断）
    func setCode(_ code: String) {
        let truncated = String(code.prefix(length))
        _code = truncated
        hiddenField.text = truncated
        onCodeChanged?(truncated)   // 通知外部

        // 与 `textDidChange` 保持同一套"完成"判定逻辑
        reportCompleteIfNeeded(count: truncated.count)
    }

    // MARK: - UI Setup

    private func setupUI() {
        backgroundColor = .clear

        // 隐藏输入框（用 alpha 而非 isHidden）
        addSubview(hiddenField)
        hiddenField.snp.makeConstraints { make in
            make.width.height.equalTo(1)
            make.leading.top.equalToSuperview()
        }

        // 横向排列方框
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Layout.boxSpacing

        // ✅ 关键：从 `.center` 改为 `.fill`
        //
        // - `.center` → 每个 box 的高度取**自身 intrinsic size**，
        //   而空 `UIView` 的 intrinsic size = 0 → **方框完全不可见**
        // - `.fill` → 每个 box 填满 stack 的高度 → 正确显示
        stack.alignment = .fill
        stack.distribution = .fillEqually
        addSubview(stack)

        for _ in 0..<length {
            let box = makeBox()
            boxes.append(box)
            stack.addArrangedSubview(box)
        }

        // 只设 `edges`——高度由 `self` 的约束 / intrinsicContentSize 决定
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 点击手势 → 唤起键盘
        let tap = UITapGestureRecognizer(target: self, action: #selector(focusInput))
        addGestureRecognizer(tap)

        refreshBoxes()
    }

    /// 构造一个方框（含边框 + 数字 label）
    ///
    /// - Returns: 配置好的方框视图
    private func makeBox() -> UIView {
        let box = UIView()
        box.backgroundColor = AppColor.Background.card
        box.layer.cornerRadius = Layout.boxCornerRadius
        box.layer.borderWidth = Layout.boxBorderWidth
        box.layer.borderColor = AppColor.separator.cgColor

        let label = UILabel()
        label.font = AppFont.Title.page
        label.textColor = AppColor.Text.primary
        label.textAlignment = .center
        box.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        labels.append(label)

        return box
    }

    private func setupActions() {
        hiddenField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)
    }

    /// 通知在 `init` 里注册（而非 `didMoveToWindow`——会重复注册）
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshBoxes),
            name: UITextField.textDidBeginEditingNotification,
            object: hiddenField
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshBoxes),
            name: UITextField.textDidEndEditingNotification,
            object: hiddenField
        )
    }

    // MARK: - Actions

    /// 点击唤起键盘
    @objc private func focusInput() {
        hiddenField.becomeFirstResponder()
    }

    /// 文本变化：过滤非数字、截断超长、更新 UI、触发回调
    @objc private func textDidChange() {
        let raw = hiddenField.text ?? ""
        let filtered = raw.filter { $0.isNumber }
        let truncated = String(filtered.prefix(length))

        if truncated != raw {
            hiddenField.text = truncated
        }

        _code = truncated
        onCodeChanged?(truncated)

        // 完成判定（**只触发一次**）
        reportCompleteIfNeeded(count: truncated.count)
    }

    // MARK: - Complete Reporting

    /// 完成判定：只在"从未报过"且"长度达到 length"时触发 `onComplete`
    ///
    /// - Parameter count: 当前输入长度
    private func reportCompleteIfNeeded(count: Int) {
        if count == length {
            if !hasReportedComplete {
                hasReportedComplete = true
                onComplete?(code)
            }
            // else：同一周期内重复达到 length —— 不重复触发
        } else {
            // 长度不足 → 重置标志，允许下次重新触发
            hasReportedComplete = false
        }
    }

    // MARK: - UI Refresh

    /// 刷新所有方框的显示与高亮状态
    ///
    /// - 已输入的方框显示对应数字
    /// - 当前待输入的方框高亮（边框加粗 + 主色）
    @objc private func refreshBoxes() {
        // 1. 更新每个方框里的数字
        for (index, label) in labels.enumerated() {
            if index < _code.count {
                let charIndex = _code.index(_code.startIndex, offsetBy: index)
                label.text = String(_code[charIndex])
            } else {
                label.text = ""
            }
        }

        // 2. 高亮当前待输入的方框
        let focusedIndex = min(_code.count, length - 1)
        for (index, box) in boxes.enumerated() {
            let isFocused = (index == focusedIndex) && hiddenField.isFirstResponder
            box.layer.borderWidth = isFocused
                ? Layout.boxBorderWidthFocused
                : Layout.boxBorderWidth
            box.layer.borderColor = isFocused
                ? AppColor.Brand.primary.cgColor
                : AppColor.separator.cgColor
        }
    }

    // MARK: - First Responder

    override var canBecomeFirstResponder: Bool { true }

    /// 外部调用 `becomeFirstResponder()` 时，转发到 `hiddenField`
    ///
    /// - Returns: `hiddenField` 是否成功成为第一响应者
    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return hiddenField.becomeFirstResponder()
    }

    /// 外部调用 `resignFirstResponder()` 时，转发到 `hiddenField`
    ///
    /// ## 返回值语义
    /// - 优先返回 `hiddenField` 的转发结果（它才是真正持有键盘的）
    /// - 无论 `hiddenField` 是否是 first responder，都调用 `super.resignFirstResponder()`
    ///   保持响应链清理的完整性
    override func resignFirstResponder() -> Bool {
        let hiddenResigned = hiddenField.resignFirstResponder()
        super.resignFirstResponder()
        return hiddenResigned
    }
}

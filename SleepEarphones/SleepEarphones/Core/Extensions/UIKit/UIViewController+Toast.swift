//
//  UIViewController+Toast.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/21.
//

import UIKit
import Toast_Swift

/// UIViewController 便捷提示扩展
///
/// ## 调用方法
/// ```swift
/// // 1. 轻提示（自动消失）
/// showToast("保存成功")
/// showToast("网络连接失败", duration: 2.0, position: .bottom)
///
/// // 2. 单按钮提示
/// showAlert("网络连接失败")
/// showAlert("加载失败，请重试", popOnDismiss: true)
/// showAlert("权限不足", onConfirm: { openSettings() })
///
/// // 3. 危险操作确认
/// showConfirm(title: "退出登录",
///             message: "确定要退出当前账号吗？",
///             destructive: true) {
///     logout()
/// }
///
/// // 4. 底部操作表
/// showActionSheet(title: "选择头像来源", actions: [
///     .init(title: "从相册选择") { pickFromAlbum() },
///     .init(title: "拍照")     { pickFromCamera() }
/// ])
///
/// // 5. 全屏加载（必须成对调用）
/// showLoading("提交中…")
/// hideLoading()
/// ```
@MainActor
extension UIViewController {

    // MARK: - Toast

    /// 显示轻量 Toast（自动消失，不打断用户）
    ///
    /// - Parameters:
    ///   - message: 提示文案
    ///   - duration: 停留时长，默认 1.2s
    ///   - position: 显示位置，默认居中
    ///
    /// - Note: 底层走 `ToastPresenter`，样式全局统一。
    ///         若需要在指定容器展示（如 Cell 内），直接用 `ToastPresenter.show(_:in:)`。
    func showToast(_ message: String, duration: TimeInterval = 1.2, position: ToastPosition = .center) {
        ToastPresenter.show(message, in: view, duration: duration, position: position)
    }

    // MARK: - Alert（单按钮提示）

    /// 单按钮提示（点击"确定"后可选回调）
    ///
    /// - Parameters:
    ///   - message: 提示正文
    ///   - title: 提示标题，传 nil 时无标题
    ///   - popOnDismiss: 点击"确定"后是否返回上一页
    ///                   （Push 场景 pop，Modal 场景 dismiss）
    ///   - onConfirm: 点击"确定"后的回调
    func showAlert(_ message: String, title: String? = nil, popOnDismiss: Bool = false, onConfirm: (() -> Void)? = nil) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            onConfirm?()
            if popOnDismiss {
                self?.dismissOrPop()
            }
        })
        present(alert, animated: true)
    }

    // MARK: - Confirm（双按钮确认）

    /// 通用确认框
    ///
    /// - Parameters:
    ///   - title: 标题
    ///   - message: 正文，默认 nil
    ///   - confirmTitle: 确认按钮标题，默认"确定"
    ///   - cancelTitle: 取消按钮标题，默认"取消"
    ///   - destructive: 确认按钮是否为危险操作（红色）
    ///   - onConfirm: 点击确认后的回调
    ///
    func showConfirm(title: String, message: String? = nil, confirmTitle: String = "确定", cancelTitle: String = "取消", destructive: Bool = false, onConfirm: @escaping () -> Void) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
        alert.addAction(UIAlertAction(
            title: confirmTitle,
            style: destructive ? .destructive : .default
        ) { _ in
            onConfirm()
        })
        present(alert, animated: true)
    }

    // MARK: - Action Sheet

    /// 底部操作表
    ///
    /// - Parameters:
    ///   - title: 标题，默认 nil
    ///   - message: 副标题，默认 nil
    ///   - actions: 操作项数组
    ///   - cancelTitle: 取消按钮标题，默认"取消"
    ///
    func showActionSheet(title: String? = nil, message: String? = nil, actions: [ActionSheetAction], cancelTitle: String = "取消") {
        let sheet = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .actionSheet
        )

        for action in actions {
            sheet.addAction(UIAlertAction(
                title: action.title,
                style: action.style
            ) { _ in
                action.handler?()
            })
        }

        sheet.addAction(UIAlertAction(title: cancelTitle, style: .cancel))

        // iPad 兼容：无 sourceView 时用 center 兜底，避免 Crash
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(
                x: view.bounds.midX,
                y: view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        present(sheet, animated: true)
    }

    // MARK: - Loading

    /// 显示全屏加载指示器（模态）
    ///
    /// - Parameter message: 加载文案，默认 nil（仅显示菊花）
    ///
    /// - Important: 必须与 `hideLoading()` 成对调用。
    ///              若同一 VC 已存在 loading，会先移除旧的再显示新的。
    ///
    /// - Note: 用于网络请求等需要在页面级阻止交互的场景。
    ///         若只是某按钮的加载态，用 `PrimaryButton.isLoading` 更合适。
    func showLoading(_ message: String? = nil) {
        // 先移除旧的（避免叠加）
        hideLoading()

        let container = UIView()
        container.tag = Self.loadingTag
        container.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.alpha = 0

        let card = UIView()
        card.backgroundColor = AppColor.Background.card
        card.layer.cornerRadius = AppSpacing.Corner.card
        card.layer.masksToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false

        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = AppColor.Brand.primary
        indicator.startAnimating()
        indicator.translatesAutoresizingMaskIntoConstraints = false

        let label: UILabel? = message.map { text in
            let l = UILabel()
            l.text = text
            l.font = AppFont.Body.secondary
            l.textColor = AppColor.Text.primary
            l.textAlignment = .center
            l.numberOfLines = 0
            l.translatesAutoresizingMaskIntoConstraints = false
            return l
        }

        view.addSubview(container)
        container.addSubview(card)
        card.addSubview(indicator)
        if let label {
            card.addSubview(label)
        }

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            card.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            card.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            indicator.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            indicator.topAnchor.constraint(equalTo: card.topAnchor, constant: AppSpacing.xl)
        ])

        if let label {
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: indicator.bottomAnchor, constant: AppSpacing.sm),
                label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AppSpacing.md),
                label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AppSpacing.md),
                label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -AppSpacing.lg)
            ])
        } else {
            NSLayoutConstraint.activate([
                indicator.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -AppSpacing.xl)
            ])
        }

        UIView.animate(withDuration: AppSpacing.Animation.quick) {
            container.alpha = 1
        }
    }

    /// 隐藏全屏加载指示器
    ///
    /// - Note: 若当前 VC 无 loading，静默返回（幂等）。
    func hideLoading() {
        guard let container = view.viewWithTag(Self.loadingTag) else { return }
        UIView.animate(
            withDuration: AppSpacing.Animation.quick,
            animations: { container.alpha = 0 }
        ) { _ in
            container.removeFromSuperview()
        }
    }

    // MARK: - Private

    /// Loading 视图的 tag，用于查找与移除
    private static var loadingTag: Int { 0x10A_D_19 }

    /// 关闭当前 VC：Push 场景 pop，Modal 场景 dismiss
    ///
    private func dismissOrPop() {
        if let nav = navigationController, nav.viewControllers.first !== self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

// MARK: - Action Sheet Action

/// 底部操作表的操作项
///
/// ## 调用方法
/// ```swift
/// showActionSheet(title: "选择来源", actions: [
///     ActionSheetAction(title: "从相册选择") { pickFromAlbum() },
///     ActionSheetAction(title: "拍照")       { pickFromCamera() },
///     ActionSheetAction(title: "删除", style: .destructive) { delete() }
/// ])
/// ```
///
struct ActionSheetAction {

    /// 操作标题
    let title: String

    /// 操作样式（默认 `.default`）
    let style: UIAlertAction.Style

    /// 点击回调（可空）
    let handler: (() -> Void)?

    /// 便利构造
    ///
    /// - Parameters:
    ///   - title: 操作标题
    ///   - style: 操作样式，默认 `.default`
    ///   - handler: 点击回调，默认 nil
    init(title: String, style: UIAlertAction.Style = .default, handler: (() -> Void)? = nil) {
        self.title = title
        self.style = style
        self.handler = handler
    }
}

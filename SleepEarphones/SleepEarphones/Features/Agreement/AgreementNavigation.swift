//
//  AgreementNavigation.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import UIKit

/// 协议页导航中心
/// 
/// ## 调用方法
/// ```swift
/// // 1. 从任意 VC 打开协议页（推荐）
/// AgreementNavigation.open(from: self, urlString: AgreementLinks.userAgreement)
/// AgreementNavigation.open(from: self, urlString: AgreementLinks.privacyPolicy)
///
/// // 2. 用于 UITextView 协议链接点击（由 AgreementTextViewHandler 内部调用）
/// ```
///
/// ## 扩展新的协议入口
/// 若后端新增协议类型（如"青少年模式协议"）：
/// 1. 在 `AgreementAPI.ColumnID` 增加常量
/// 2. 在 `meta(for:)` 的 `switch` 里增加对应分支
/// 3. 在 `AgreementLinks` 增加对应的 URL 拼装方法
///
@MainActor
enum AgreementNavigation {

    // MARK: - Meta

    /// 协议元信息
    struct Meta {
        /// 单页 KID（可能为 nil，如第三方链接未带 column_id）
        let columnId: Int?

        /// 展示标题（**已本地化**）
        let title: String
    }

    // MARK: - Public

    /// 根据 URL 打开协议页
    ///
    /// - Parameters:
    ///   - vc: 调用方
    ///   - urlString: 协议原始 URL（用于接口失败时兜底）
    static func open(from vc: UIViewController, urlString: String) {
        let meta = meta(for: urlString)

        AppLog.agreement.debug(
            "打开协议页：columnId=\(meta.columnId.map(String.init) ?? "nil", privacy: .public) title=\(meta.title, privacy: .public)"
        )

        AgreementViewController.push(
            from: vc,
            columnId: meta.columnId,
            title: meta.title,
            fallbackURL: urlString
        )
    }

    // MARK: - Private

    /// URL → (column_id, 标题)
    ///
    /// - Parameter url: 协议原始 URL
    /// - Returns: 元信息（`columnId` 可能为 nil）
    private static func meta(for url: String) -> Meta {
        guard let columnId = extractColumnId(from: url) else {
            // 未解析到 column_id：保留 nil + 兜底标题
            return Meta(columnId: nil, title: L("详情"))
        }

        switch columnId {
        case AgreementAPI.ColumnID.userAgreement:
            return Meta(columnId: columnId, title: L("用户注册协议"))

        case AgreementAPI.ColumnID.privacyPolicy:
            return Meta(columnId: columnId, title: L("隐私政策"))

        default:
            // column_id 存在但未在 `ColumnID` 中登记——
            // 保留 columnId（用于接口请求）+ 兜底标题
            return Meta(columnId: columnId, title: L("详情"))
        }
    }

    /// 从 URL 中解析 `column_id` 查询参数
    ///
    /// - Parameter url: 完整 URL 字符串（如 `"https://...?column_id=9"`）
    /// - Returns: `column_id` 的整数值；缺失或格式错误时返回 `nil`
    private static func extractColumnId(from url: String) -> Int? {
        guard let components = URLComponents(string: url),
              let items = components.queryItems else {
            return nil
        }

        // 大小写不敏感匹配（`column_id` / `columnId` / `COLUMN_ID` 都命中）
        let target = "column_id"
        return items
            .first { $0.name.lowercased().replacingOccurrences(of: "_", with: "") == target.replacingOccurrences(of: "_", with: "") }
            .flatMap { $0.value }
            .flatMap { Int($0) }
    }
}

// MARK: - UITextViewDelegate 通用实现

/// 协议 TextView 的通用点击处理
@MainActor
class AgreementTextViewHandler: NSObject, UITextViewDelegate {

    // MARK: - Public

    /// 处理链接点击
    ///
    /// - Parameters:
    ///   - url: 被点击的链接 URL
    ///   - vc: 链接所属的 VC（由 `textView.findViewController()` 反查）
    func handleAgreementLink(_ url: URL, from vc: UIViewController) {
        AgreementNavigation.open(from: vc, urlString: url.absoluteString)
    }

    // MARK: - iOS 17 之前

    /// 处理链接点击（iOS 17 之前）
    ///
    /// - Parameters:
    ///   - textView: 触发事件的 textView
    ///   - URL: 被点击的链接
    ///   - characterRange: 链接的字符范围
    ///   - interaction: 交互类型
    /// - Returns: 固定返回 `false`——表示由我们**自己**处理跳转
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        guard let vc = textView.findViewController() else {
            AppLog.agreement.error("无法从 UITextView 找到所属 VC，忽略链接点击")
            return false
        }
        handleAgreementLink(URL, from: vc)
        return false
    }

    // MARK: - iOS 17+

    /// 处理链接点击（iOS 17+）
    ///
    /// - Parameters:
    ///   - textView: 触发事件的 textView
    ///   - textItem: 文本项（含链接 URL）
    ///   - defaultAction: 系统默认行为
    /// - Returns: 自定义的 `UIAction`；非链接类型返回 `defaultAction`
    @available(iOS 17.0, *)
    func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
        // 非链接类型（如附件）：走系统默认
        guard case .link(let url) = textItem.content else {
            return defaultAction
        }

        // 捕获 textView（弱引用），点击时再查找所属 VC
        return UIAction { [weak textView] _ in
            MainActor.assumeIsolated {
                guard let vc = textView?.findViewController() else {
                    AppLog.agreement.error("无法从 UITextView 找到所属 VC，忽略链接点击")
                    return
                }
                AgreementNavigation.open(from: vc, urlString: url.absoluteString)
            }
        }
    }
}

// MARK: - UIView → 所在 VC

/// 视图 → 所属 ViewController 的响应链查找
extension UIView {

    /// 向上查找所在的 UIViewController
    ///
    /// - Returns: 所属 VC；未找到时返回 `nil`
    @MainActor
    func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController {
                return vc
            }
            responder = r.next
        }
        return nil
    }
}

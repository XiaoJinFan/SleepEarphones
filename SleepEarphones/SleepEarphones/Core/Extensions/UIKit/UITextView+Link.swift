//
//  UITextView+Link.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/18.
//

import UIKit

// MARK: - 协议链接模型

/// 协议文本中的链接配置
///
/// - Note: 遵循 `Hashable` 便于在数组中去重 / 做单元测试断言。
struct AgreementLink: Hashable {

    /// 展示文本（如："《用户注册协议》"）
    let text: String

    /// 跳转地址
    let url: String
}

// MARK: - UITextView 便捷方法

extension UITextView {

    // MARK: 配置

    /// 将整段文本中的多个指定子串设置成可点击链接
    /// 
    /// - Parameters:
    ///   - fullText: 完整文本
    ///   - links: 需要变成链接的子串 + 目标 URL
    ///   - baseAttributes: 普通文字样式；传 nil 时使用默认（`AppFont.Body.regular` + `AppColor.Text.primary`）
    ///   - linkColor: 链接文字颜色；传 nil 时使用 `AppColor.link`
    ///   - lineHeightMultiple: 行高倍数；传 nil 时使用 `AppFont.lineHeightMultiple`
    /// - Returns: 实际设置成功的链接数组（缺失的 link 会被忽略）
    ///
    @discardableResult
    func setAgreementText(_ fullText: String, links: [AgreementLink], baseAttributes: [NSAttributedString.Key: Any]? = nil, linkColor: UIColor? = nil, lineHeightMultiple: CGFloat? = nil) -> [AgreementLink] {

        // 1. 组装基础属性（含段落样式）
        let attributes = baseAttributes ?? Self.defaultBaseAttributes(
            lineHeightMultiple: lineHeightMultiple ?? AppFont.lineHeightMultiple
        )

        // 2. 创建可变富文本
        let attributed = NSMutableAttributedString(
            string: fullText,
            attributes: attributes
        )

        // 3. 匹配并设置所有链接
        let nsText = fullText as NSString
        var appliedLinks: [AgreementLink] = []

        for link in links {
            // ⚠️ 循环匹配：文本中同一子串出现多次时全部设为链接
            var searchRange = NSRange(location: 0, length: nsText.length)
            var found = false

            while searchRange.location < nsText.length {
                let range = nsText.range(of: link.text, range: searchRange)
                guard range.location != NSNotFound else { break }

                attributed.addAttribute(.link, value: link.url, range: range)
                found = true

                // 移动搜索起点到本次匹配的末尾
                let nextLocation = range.location + range.length
                searchRange = NSRange(
                    location: nextLocation,
                    length: nsText.length - nextLocation
                )
            }

            if found {
                appliedLinks.append(link)
            } else {
                AppLog.ui.debug(
                    "协议链接文本未匹配：\(link.text, privacy: .public)"
                )
            }
        }

        // 4. 应用
        attributedText = attributed
        linkTextAttributes = [
            .foregroundColor: linkColor ?? AppColor.link,
            .underlineStyle: 0
        ]
        applyBaseConfiguration()

        return appliedLinks
    }

    // MARK: 默认样式

    /// 默认基础属性
    ///
    /// - Parameter lineHeightMultiple: 行高倍数
    /// - Returns: 字号、颜色、段落样式的组合
    private static func defaultBaseAttributes(lineHeightMultiple: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = lineHeightMultiple
        paragraphStyle.alignment = .justified

        return [
            .font: AppFont.Body.regular,
            .foregroundColor: AppColor.Text.primary,
            .paragraphStyle: paragraphStyle
        ]
    }

    /// 应用通用的展示配置
    ///
    /// - `isEditable = false`：禁止编辑
    /// - `isSelectable = true`：允许选中 / 点击链接
    /// - `isScrollEnabled = false`：交给父容器滚动
    /// - `textContainerInset = .zero` + `lineFragmentPadding = 0`：消除内边距，
    ///   避免与外部 Auto Layout 间距叠加
    private func applyBaseConfiguration() {
        isEditable = false
        isSelectable = true
        isScrollEnabled = false
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        backgroundColor = .clear
    }
}

// MARK: - 协议地址集中配置

/// 协议地址配置
enum AgreementLinks {

    /// 用户注册协议
    ///
    /// - Note: 使用 `AgreementAPI.ColumnID.userAgreement`（= 9）。
    static let userAgreement =
        "\(APIConfiguration.serverPrefix)/\(APIEndpoint.privacyPolicy.rawValue)?column_id=\(AgreementAPI.ColumnID.userAgreement)"

    /// 隐私政策
    ///
    /// - Note: 使用 `AgreementAPI.ColumnID.privacyPolicy`（= 10）。
    static let privacyPolicy =
        "\(APIConfiguration.serverPrefix)/\(APIEndpoint.privacyPolicy.rawValue)?column_id=\(AgreementAPI.ColumnID.privacyPolicy)"
}

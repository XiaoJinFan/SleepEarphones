//
//  AgreementHTMLTemplate.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/21.
//

import UIKit

/// 协议 HTML 模板
///
/// ## 职责
/// 后端返回的 `content` 是 **HTML 片段**（不是完整文档），
/// 需要包裹 `<html>` / `<head>` / `<style>` 等标签后才能加载到 `WKWebView`。
///
/// ## 统一控制的样式
/// - 字体（跟随系统 / 中文优化）
/// - 行高（1.75，适合长文阅读）
/// - 颜色（浅色 / 暗黑两套，与 `AppColor` 保持一致）
/// - 图片（自适应宽度、居中）
/// - 常用元素（标题 / 段落 / 列表 / 表格 / 引用 / 代码）
/// - **安全**：CSP 禁脚本（协议页无需 JS，防止后端内容注入执行）
///
/// ## 调用方法
/// ```swift
/// // 1. 渲染协议内容
/// let html = AgreementHTMLTemplate.wrap(content, title: "用户注册协议")
/// webView.loadHTMLString(html, baseURL: nil)
///
/// // 2. App 启动时预热样式（避免首次 push 时卡顿）
/// AgreementHTMLTemplate.warmUp()
/// ```
@MainActor
enum AgreementHTMLTemplate {

    // MARK: - Public API

    /// 用统一模板包裹后端返回的 HTML 片段
    ///
    /// - Parameters:
    ///   - body: 后端返回的 HTML 片段
    ///   - title: HTML `<title>`；默认空字符串
    /// - Returns: 完整的 HTML 文档
    ///
    /// - Note:
    ///   - `title` 用于 `WKWebView.title` KVO——若页面没 `<title>`，
    ///     `webView.title` 会是 `nil`，导致导航栏标题无法更新
    ///   - `body` **不**做转义——它本身是 HTML，转义后标签会变成纯文本
    static func wrap(_ body: String, title: String = "") -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes">
        <meta name="format-detection" content="telephone=no">
        <meta http-equiv="Content-Security-Policy" content="\(cspPolicy)">
        <meta name="theme-color" content="#FFFFFF" media="(prefers-color-scheme: light)">
        <meta name="theme-color" content="#000000" media="(prefers-color-scheme: dark)">
        <title>\(escapeHTML(title))</title>
        <style>\(cachedStyleSheet)</style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    /// 预热缓存的样式表
    ///
    /// ## 使用场景
    /// 若首次访问发生在用户点击"用户协议"的瞬间，
    /// 会在主线程阻塞数毫秒——虽然只一次，但在低端机上有可感知的一帧掉帧。
    ///
    /// ## 调用方法
    /// 在 `AppDelegate.didFinishLaunchingWithOptions` 中调用一次：
    /// ```swift
    /// AgreementHTMLTemplate.warmUp()
    /// ```
    ///
    /// - Note: 因为本 `enum` 标注 `@MainActor`，
    ///         本方法必须在主线程调用（App 启动路径天然满足）。
    static func warmUp() {
        // 触发 `cachedStyleSheet` 的惰性初始化
        _ = cachedStyleSheet
        AppLog.ui.debug("AgreementHTMLTemplate 样式表已预热")
    }

    // MARK: - CSP Policy

    /// 内容安全策略
    ///
    /// ## 策略说明
    /// | 指令 | 值 | 说明 |
    /// |---|---|---|
    /// | `default-src` | `'none'` | 默认禁止一切（脚本 / 字体 / 媒体等） |
    /// | `img-src` | `data: https: http:` | 允许图片（base64 / 远程，含 http 兼容老旧资源） |
    /// | `style-src` | `'unsafe-inline'` | 允许内联样式（模板自身用 `<style>`） |
    ///
    /// - Important: **没有**显式列 `script-src`——
    ///              因为它会被 `default-src 'none'` 覆盖，
    ///              语义更简洁。任何 `<script>` 都不会执行。
    private static let cspPolicy =
        "default-src 'none'; img-src data: https: http:; style-src 'unsafe-inline';"

    // MARK: - Style Sheet（缓存）

    /// 缓存的样式表
    ///
    /// - Note:
    ///   - 首次访问时计算，之后直接命中静态缓存
    ///   - 因为样式表内容**不依赖运行时状态**（只依赖 `AppColor` 的固定色值），
    ///     所以缓存是安全的
    ///   - `static let` 惰性初始化由 `@MainActor` 保证主线程首次访问
    ///   - 通过 `warmUp()` 在 App 启动时提前触发初始化
    private static let cachedStyleSheet: String = makeStyleSheet()

    /// 生成样式表（仅首次调用）
    ///
    /// 通过 `resolveHex(_:style:)` **显式指定 trait collection** 解析动态色，
    /// 保证浅色块与暗黑块的色值不同。
    ///
    /// - Returns: 完整的 CSS 样式字符串
    private static func makeStyleSheet() -> String {
        let light = makePalette(style: .light)
        let dark  = makePalette(style: .dark)

        return """
        :root {
          color-scheme: light dark;
          --text: \(light.hexText);
          --secondary-text: \(light.hexSecondaryText);
          --background: \(light.hexBackground);
          --link: \(light.hexLink);
          --border: \(light.hexBorder);
          --code-bg: \(light.hexCodeBackground);
        }

        @media (prefers-color-scheme: dark) {
          :root {
            --text: \(dark.hexText);
            --secondary-text: \(dark.hexSecondaryText);
            --background: \(dark.hexBackground);
            --link: \(dark.hexLink);
            --border: \(dark.hexBorder);
            --code-bg: \(dark.hexCodeBackground);
          }
        }

        /* ---------- 基础 ---------- */
        html, body {
          margin: 0;
          padding: 0;
          background: var(--background);
        }

        body {
          font-family: -apple-system, BlinkMacSystemFont, "PingFang SC",
                       "Hiragino Sans GB", "Helvetica Neue", "Microsoft YaHei",
                       sans-serif;
          font-size: 16px;
          line-height: 1.75;
          color: var(--text);
          padding: 16px;
          word-break: break-word;
          overflow-wrap: break-word;
          -webkit-text-size-adjust: 100%;
          -webkit-font-smoothing: antialiased;
        }

        /* ---------- 标题 ---------- */
        h1, h2, h3, h4, h5, h6 {
          margin: 20px 0 12px;
          line-height: 1.4;
          font-weight: 600;
          color: var(--text);
        }
        h1 { font-size: 20px; }
        h2 { font-size: 18px; }
        h3 { font-size: 17px; }
        h4, h5, h6 { font-size: 16px; }

        /* ---------- 段落 ---------- */
        p {
          margin: 0 0 12px;
        }

        /* ---------- 链接 ---------- */
        a {
          color: var(--link);
          text-decoration: none;
          word-break: break-all;
        }
        a:active {
          opacity: 0.7;
        }

        /* ---------- 列表 ---------- */
        ul, ol {
          margin: 0 0 12px;
          padding-left: 24px;
        }
        li {
          margin-bottom: 6px;
        }

        /* ---------- 图片 ---------- */
        img {
          max-width: 100%;
          height: auto;
          display: block;
          margin: 12px auto;
          border-radius: 6px;
        }

        /* ---------- 表格 ---------- */
        table {
          width: 100%;
          border-collapse: collapse;
          margin: 12px 0;
          font-size: 15px;
        }
        th, td {
          border: 1px solid var(--border);
          padding: 8px 10px;
          text-align: left;
          vertical-align: top;
        }
        th {
          background: var(--code-bg);
          font-weight: 600;
        }

        /* ---------- 引用块 ---------- */
        blockquote {
          margin: 12px 0;
          padding: 8px 12px;
          border-left: 3px solid var(--border);
          color: var(--secondary-text);
          background: var(--code-bg);
          border-radius: 4px;
        }

        /* ---------- 代码 ---------- */
        code, pre {
          font-family: "SF Mono", Menlo, Consolas, monospace;
          font-size: 14px;
          background: var(--code-bg);
          border-radius: 4px;
        }
        code {
          padding: 2px 6px;
        }
        pre {
          padding: 12px;
          overflow-x: auto;
          margin: 12px 0;
        }
        pre code {
          padding: 0;
          background: transparent;
        }

        /* ---------- 分隔线 ---------- */
        hr {
          border: none;
          border-top: 1px solid var(--border);
          margin: 20px 0;
        }

        /* ---------- 强调 ---------- */
        strong, b { font-weight: 600; }
        em, i { font-style: italic; }

        /* ---------- 反选/长按选择 ---------- */
        ::selection {
          background: var(--link);
          color: #FFFFFF;
        }
        """
    }

    // MARK: - Color Palette

    /// 色值集合（直接存 hex String）
    private struct ColorPalette {
        let hexText: String
        let hexSecondaryText: String
        let hexBackground: String
        let hexLink: String
        let hexBorder: String
        let hexCodeBackground: String
    }

    /// 预建 trait collection 常量
    ///
    /// - Note: 原实现 `resolveHex` 每次都 `UITraitCollection(userInterfaceStyle: style)`——
    ///         创建对象虽轻量，但每次都分配堆内存 + 拷贝，6 次调用就是 6 次分配。
    ///         既然是固定两种 style，抽成常量只创建一次。
    private static let lightTraits = UITraitCollection(userInterfaceStyle: .light)
    private static let darkTraits  = UITraitCollection(userInterfaceStyle: .dark)

    /// 按目标外观生成色板
    ///
    /// - Parameter style: `.light` / `.dark`
    /// - Returns: 6 个字段均已解析为 hex 字符串的色板
    private static func makePalette(style: UIUserInterfaceStyle) -> ColorPalette {
        ColorPalette(
            hexText:           resolveHex(AppColor.Text.primary,       style: style),
            hexSecondaryText:  resolveHex(AppColor.Text.secondary,     style: style),
            hexBackground:     resolveHex(AppColor.Background.primary, style: style),
            hexLink:           resolveHex(AppColor.link,               style: style),
            hexBorder:         resolveHex(AppColor.separator,          style: style),
            hexCodeBackground: style == .dark ? "#2C2C2E" : "#F2F2F7"
        )
    }

    // MARK: - Helpers

    /// 解析动态色为指定外观下的 hex 字符串
    ///
    /// `resolvedColor(with:)` 允许传入指定的 trait collection，
    /// 强制按浅色 / 暗黑解析出对应色值。
    ///
    /// - Parameters:
    ///   - color: 动态色
    ///   - style: 目标外观（`.light` / `.dark`）
    /// - Returns: `#RRGGBB` 格式的十六进制字符串
    ///
    /// - Note: 复用 `lightTraits` / `darkTraits` 静态常量，
    ///         避免每次重建 `UITraitCollection`。
    private static func resolveHex(_ color: UIColor, style: UIUserInterfaceStyle) -> String {
        let traits = (style == .dark) ? darkTraits : lightTraits
        return color.resolvedColor(with: traits).hexString
    }

    /// 转义 HTML 特殊字符
    ///
    /// - Parameter string: 原始字符串
    /// - Returns: 转义后的字符串
    ///
    /// - Note: 用于 `<title>` 标签。正文（`body`）是后端返回的 HTML，
    ///         不应转义，否则 HTML 标签会被显示为纯文本。
    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

// MARK: - UIColor → Hex

/// 仅本文件使用的十六进制转换
///
/// - Note: 保持 `private` 而非 `internal`——
///         避免其他模块各自实现一套 hex 转换，统一走 `AppColor` + 本扩展。
private extension UIColor {

    /// 转为 `#RRGGBB` 格式的十六进制字符串
    ///
    /// - Returns: `#RRGGBB` 格式字符串
    ///
    /// - Note:
    ///   - 用于把 `AppColor` 的动态颜色注入 HTML CSS
    ///   - 只输出 RGB，不含 alpha（CSS 中不做透明度处理）
    ///   - **必须先在主线程调用 `resolvedColor(with:)` 解析动态色**
    ///     后再调用本属性，否则可能拿到错误的色值
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        getRed(&r, green: &g, blue: &b, alpha: &a)

        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))

        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }
}

//
//  AgreementViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/21.
//

import UIKit
import WebKit
import Combine


@MainActor
final class AgreementViewController: UIViewController {

    // MARK: - Config

    /// 单页 KID（可选）
    private let columnId: Int?

    /// 接口失败时回退的 URL
    private let fallbackURL: String?

    // MARK: - Deps

    /// 协议服务（复用同一实例，避免每次 push 都新建 Session）
    private let service: AgreementServiceProtocol

    /// Combine 订阅容器
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI

    private let webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let wv = WKWebView(frame: .zero, configuration: config)
        // 透明背景：避免加载前闪现白/黑块
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.contentInsetAdjustmentBehavior = .automatic
        return wv
    }()

    private let indicator: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(style: .large)
        v.hidesWhenStopped = true
        v.color = AppColor.Text.tertiary
        return v
    }()

    // MARK: - State

    /// 是否已经提示过加载错误（避免重复弹窗）
    private var hasShownErrorAlert = false

    /// 日志用的 `columnId` 描述（**延迟计算 + 缓存**）
    private lazy var columnIdLog: String = {
        columnId.map(String.init) ?? "nil"
    }()

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameters:
    ///   - columnId: 单页 KID（可选，传 nil 返回后端默认协议）
    ///   - title: 页面标题（会作为初始导航栏标题；接口返回 `name` 后会覆盖）。
    ///            **调用方应传入 `L(...)` 已本地化的字符串**
    ///   - fallbackURL: 接口失败时回退的 URL
    ///   - service: 协议服务，默认 `AgreementService.shared`
    init(columnId: Int?, title: String, fallbackURL: String? = nil, service: AgreementServiceProtocol = AgreementService.shared) {
        self.columnId = columnId
        self.fallbackURL = fallbackURL
        self.service = service
        super.init(nibName: nil, bundle: nil)
        self.title = title
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
        loadAgreement()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = AppColor.Background.primary
        navigationItem.backButtonDisplayMode = .minimal
        webView.navigationDelegate = self
    }

    private func setupConstraints() {
        view.addSubview(webView)
        view.addSubview(indicator)

        webView.translatesAutoresizingMaskIntoConstraints = false
        indicator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // 底边贴 safeArea 避免被 Home Indicator 遮挡
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Load

    /// 加载协议内容
    ///
    /// ## 流程
    /// 1. 显示菊花
    /// 2. 调 API
    /// 3. 成功：`render(content:)` 渲染 HTML
    /// 4. 失败：`fallbackToURL(_:)` 用 WebView 打开原始 URL
    private func loadAgreement() {
        indicator.startAnimating()

        AppLog.agreement.debug("加载协议内容：columnId=\(self.columnIdLog, privacy: .public)")

        service.fetchAgreement(columnId: columnId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.indicator.stopAnimating()

                    if case .failure(let error) = completion {
                        // 主动取消的请求不用处理
                        if case .cancelled = error { return }
                        AppLog.agreement.error(
                            "协议接口失败：\(error.logCode, privacy: .public)，尝试回退到 URL"
                        )
                        // 接口挂了 → 用原始 URL 兜底
                        // 错误描述来自 NetworkError.errorDescription（已本地化）
                        self.fallbackToURL(error.errorDescription ?? L("加载失败"))
                    }
                },
                receiveValue: { [weak self] content in
                    guard let self else { return }
                    self.render(content: content)
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Render

    /// 用接口返回的 HTML 渲染
    ///
    /// - Parameter content: 接口返回的协议内容
    private func render(content: AgreementContent) {
        // 用接口返回的 name 更新标题（避免硬编码）
        if let name = content.name, !name.isEmpty {
            title = name
        }

        // 内容为空：直接展示"暂无内容"占位
        guard content.hasContent else {
            AppLog.agreement.warning(
                "协议内容为空，columnId=\(self.columnIdLog, privacy: .public)"
            )
            webView.loadHTMLString(
                AgreementHTMLTemplate.wrap(L("暂无内容")),
                baseURL: nil
            )
            return
        }

        // 用统一模板包裹 HTML 片段
        let html = AgreementHTMLTemplate.wrap(content.content ?? "")
        webView.loadHTMLString(html, baseURL: nil)
    }

    /// 回退：打开原始 URL
    ///
    /// - Parameter message: 错误信息（若 `fallbackURL` 无效时用于弹错）
    private func fallbackToURL(_ message: String) {
        guard let s = fallbackURL, let url = URL(string: s) else {
            AppLog.agreement.error("回退 URL 无效，弹错并返回")
            showErrorAlert(message)
            return
        }

        AppLog.agreement.debug("回退到原始 URL：\(url.absoluteString, privacy: .public)")

        indicator.startAnimating()
        webView.load(URLRequest(url: url))
    }

    // MARK: - Error

    /// 展示错误弹窗（**带防重入**）
    ///
    /// - Parameter message: 错误信息（已本地化）
    private func showErrorAlert(_ message: String) {
        guard !hasShownErrorAlert else {
            AppLog.agreement.debug("已提示过错误，忽略重复弹窗")
            return
        }
        hasShownErrorAlert = true

        showAlert(
            message,
            title: L("提示"),
            popOnDismiss: true
        )
    }

    // MARK: - Push Helper

    /// 从任意 VC 跳转到协议页
    ///
    /// - Parameters:
    ///   - vc: 调用方
    ///   - columnId: 单页 KID（可选）
    ///   - title: 页面标题（**调用方应传入 `L(...)` 已本地化的字符串**）
    ///   - fallbackURL: 接口失败时回退的 URL
    static func push(from vc: UIViewController, columnId: Int?, title: String, fallbackURL: String? = nil) {
        let target = AgreementViewController(
            columnId: columnId,
            title: title,
            fallbackURL: fallbackURL
        )

        if let nav = vc.navigationController {
            // 有导航栈：正常 Push
            nav.pushViewController(target, animated: true)
        } else {
            // 无导航栈：包一层 NavigationController 后 Modal 呈现
            let nav = UINavigationController(rootViewController: target)
            nav.modalPresentationStyle = .fullScreen
            vc.present(nav, animated: true)
        }
    }
}

// MARK: - WKNavigationDelegate

extension AgreementViewController: WKNavigationDelegate {

    /// 加载完成
    ///
    /// - Parameters:
    ///   - webView: 触发的 WebView
    ///   - navigation: 导航对象
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        indicator.stopAnimating()
        AppLog.agreement.debug(
            "WebView 加载完成：\(webView.url?.absoluteString ?? "", privacy: .public)"
        )
    }

    /// 加载失败（页面已开始渲染后失败）
    ///
    /// - Parameters:
    ///   - webView: 触发的 WebView
    ///   - navigation: 导航对象
    ///   - error: 错误信息（`WKError`，其 `localizedDescription` 已本地化）
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        indicator.stopAnimating()

        // 主动取消（用户返回）不算错误
        if (error as NSError).code == NSURLErrorCancelled { return }

        AppLog.agreement.error(
            "WebView 加载失败：\(error.localizedDescription, privacy: .public)"
        )

        showErrorAlert(error.localizedDescription)
    }

    /// 加载失败（页面尚未渲染时失败，如 DNS / SSL / 离线）
    ///
    /// - Parameters:
    ///   - webView: 触发的 WebView
    ///   - navigation: 导航对象
    ///   - error: 错误信息
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        indicator.stopAnimating()

        // 主动取消（用户返回）不算错误
        if (error as NSError).code == NSURLErrorCancelled { return }

        AppLog.agreement.error(
            "WebView 预加载失败：\(error.localizedDescription, privacy: .public)"
        )

        showErrorAlert(error.localizedDescription)
    }

    /// 内存压力下 WebKit 内容进程可能被回收，页面白屏；重载当前 URL 即可恢复
    ///
    /// - Parameter webView: 触发的 WebView
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        AppLog.agreement.warning("WebView 内容进程被回收，重新加载")
        webView.reload()
    }
}

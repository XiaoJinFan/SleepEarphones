//
//  WebViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/18.
//

import UIKit
import WebKit

/// 通用网页浏览页
///
/// ## 调用方法
/// ```swift
/// // 1. Push 进栈（推荐）
/// WebViewController.push(from: self,
///                        urlString: "https://...",
///                        title: L("用户协议"))
///
/// // 2. 直接初始化后 present
/// let vc = WebViewController(urlString: "https://...")
/// present(vc, animated: true)
/// ```
///
@MainActor
final class WebViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        /// 进度条高度：使用 hairline（0.5pt），视觉更精致
        static let progressHeight: CGFloat = 0.5
    }

    // MARK: - Properties

    /// 页面地址（延迟到 `viewDidLoad` 才校验，避免 init 阶段副作用）
    private let urlString: String

    /// 自定义标题（若为 nil，则跟随网页标题）
    private let customTitle: String?

    /// KVO 观察者
    private var progressObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?

    /// 是否已经提示过加载错误（避免重复弹窗）
    private var hasShownErrorAlert = false

    /// URL 非法时记录标志，延迟到 `viewDidAppear` 弹窗
    private var shouldShowInvalidURLAlert = false

    // MARK: - UI

    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        // 允许使用 App 自身的 UserAgent（部分页面会据此区分客户端）
        config.applicationNameForUserAgent = "SleepEarphones"

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        // 页面背景跟随系统，避免深色模式白屏闪烁
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        // 内边距由页面自身控制，容器无需额外 inset
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        return webView
    }()

    private lazy var progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .bar)
        pv.progressTintColor = AppColor.Brand.primary
        pv.trackTintColor = .clear
        pv.progress = 0
        return pv
    }()

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameters:
    ///   - urlString: 要加载的网页地址（非法地址会在 `viewDidAppear` 中提示）
    ///   - title: 自定义标题（可选）；传 nil 则跟随网页自身标题。
    ///            调用方应传入 `L(...)` 已本地化的字符串
    init(urlString: String, title: String? = nil) {
        self.urlString = urlString
        self.customTitle = title
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadURL()
        observeWebView()
    }

    /// URL 非法时延后到 `viewDidAppear` 弹窗
    ///
    /// - Parameter animated: 是否动画
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if shouldShowInvalidURLAlert {
            shouldShowInvalidURLAlert = false
            showAlert(L("无效的网页地址"))
        }
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = AppColor.Background.primary
        title = customTitle ?? L("加载中…")

        view.addSubview(webView)
        view.addSubview(progressView)
    }

    private func setupConstraints() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // 进度条：紧贴安全区顶部
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: Layout.progressHeight),

            // 网页：底边贴 safeArea，避免内容被 Home Indicator 遮挡
            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        // Modal 场景：作为导航栈的根时显示关闭按钮
        //
        // - Push 进入：当前 VC 是导航栈的中间节点，系统会自动显示返回按钮
        // - Modal 进入：即使包了 NavigationController，也是栈的根，需要手动加关闭按钮
        if isPresentedAsModal {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(closeTapped)
            )
        }
    }

    /// 是否以 Modal 形式呈现
    ///
    /// - 判定逻辑：有 presentingViewController 且当前是导航栈的根（首个 VC）
    private var isPresentedAsModal: Bool {
        presentingViewController != nil
            && (navigationController?.viewControllers.first === self
                || navigationController == nil)
    }

    /// 加载 URL
    private func loadURL() {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              !scheme.isEmpty else {
            AppLog.ui.error("WebViewController URL 非法：\(self.urlString, privacy: .public)")
            shouldShowInvalidURLAlert = true
            return
        }
        webView.load(URLRequest(url: url))
    }

    /// 监听进度与标题
    private func observeWebView() {
        // 进度
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            let progress = Float(webView.estimatedProgress)
            DispatchQueue.main.async {
                guard let self else { return }
                self.progressView.setProgress(progress, animated: true)
                // 完成后隐藏进度条（保留 100% 一小段时间再隐藏，避免"啪"一下消失）
                if progress >= 1.0 {
                    UIView.animate(withDuration: AppSpacing.Animation.quick) {
                        self.progressView.alpha = 0
                    } completion: { _ in
                        self.progressView.isHidden = true
                        self.progressView.alpha = 1
                    }
                } else {
                    self.progressView.isHidden = false
                    self.progressView.alpha = 1
                }
            }
        }

        // 标题
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
            let webTitle = webView.title
            DispatchQueue.main.async {
                guard let self else { return }
                // 仅在未指定自定义标题时跟随网页标题
                guard self.customTitle == nil,
                      let webTitle, !webTitle.isEmpty else { return }
                self.title = webTitle
            }
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - Error Handling

    /// 展示加载错误
    ///
    /// - Parameter message: 错误描述（来自系统 `error.localizedDescription`，
    ///                      系统已本地化，**不再二次翻译**）
    ///
    private func presentLoadError(_ message: String) {
        guard !hasShownErrorAlert else { return }
        hasShownErrorAlert = true

        let alert = UIAlertController(
            title: L("加载失败"),
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L("重试"), style: .default) { [weak self] _ in
            self?.hasShownErrorAlert = false
            self?.loadURL()
        })
        alert.addAction(UIAlertAction(title: L("返回"), style: .cancel) { [weak self] _ in
            self?.dismissOrPop()
        })
        present(alert, animated: true)
    }

    /// 关闭当前页：Push 场景 pop，Modal 场景 dismiss
    private func dismissOrPop() {
        if let nav = navigationController, nav.viewControllers.first !== self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {

    /// 加载完成
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressView.isHidden = true
        AppLog.ui.debug("WebView 加载完成：\(webView.url?.absoluteString ?? "", privacy: .public)")
    }

    /// 加载失败（页面已开始渲染后失败）
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        progressView.isHidden = true
        AppLog.ui.error("WebView didFail: \(error.localizedDescription, privacy: .public)")
        // 主动取消（如用户返回上一页）不算错误
        if (error as NSError).code == NSURLErrorCancelled { return }
        presentLoadError(error.localizedDescription)
    }

    /// 加载失败（页面尚未渲染时失败，如 DNS / SSL / 离线）
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        progressView.isHidden = true
        AppLog.ui.error("WebView didFailProvisional: \(error.localizedDescription, privacy: .public)")
        if (error as NSError).code == NSURLErrorCancelled { return }
        presentLoadError(error.localizedDescription)
    }

    /// 内容进程被系统回收
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        AppLog.ui.warning("WebView 内容进程被回收，重新加载")
        webView.reload()
    }

    /// 证书挑战（预留）
    ///
    /// - 当前使用默认行为（系统证书校验）。
    /// - 若未来需要支持自签 / 过期证书（如内网测试环境），
    ///   在此实现 `URLAuthenticationChallenge` 处理逻辑。
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }
}

// MARK: - 便捷入口

extension WebViewController {

    /// 应用内打开网页（Push 或 Modal，由调用方环境决定）
    ///
    /// ## 调用方法
    /// ```swift
    /// WebViewController.push(from: self,
    ///                        urlString: "https://...",
    ///                        title: L("用户协议"))
    /// ```
    ///
    /// - Parameters:
    ///   - vc: 调用方 VC
    ///   - urlString: 网页地址
    ///   - title: 自定义标题（可选，调用方应传入 `L(...)` 已本地化的字符串）
    static func push(from vc: UIViewController, urlString: String, title: String? = nil) {
        let webVC = WebViewController(urlString: urlString, title: title)

        if let nav = vc.navigationController {
            nav.pushViewController(webVC, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: webVC)
            nav.modalPresentationStyle = .fullScreen
            vc.present(nav, animated: true)
        }
    }
}

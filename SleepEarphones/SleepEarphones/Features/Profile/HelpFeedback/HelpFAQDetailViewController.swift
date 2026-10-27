//
//  HelpFAQDetailViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import UIKit
import WebKit
import SnapKit


@MainActor
final class HelpFAQDetailViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        /// 进度条高度：hairline（0.5pt），视觉更精致
        static let progressHeight: CGFloat = 0.5
    }

    // MARK: - Properties

    /// 帮助文章（由调用方注入）
    private let item: HelpFAQItem

    /// KVO 观察者
    ///
    /// - Note: 无需在 `deinit` 里手动 `invalidate`——
    ///         `NSKeyValueObservation` 会在 observe 的对象释放时自动失效；
    ///         而且 Swift 6 下 `@MainActor` 类的 `deinit` 是 `nonisolated`，
    ///         直接访问本属性会触发并发警告。
    private var progressObservation: NSKeyValueObservation?

    /// 是否已经提示过加载错误（避免重复弹窗）
    private var hasShownErrorAlert = false

    // MARK: - UI

    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        // 透明背景：避免加载前闪现白/黑块
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.contentInsetAdjustmentBehavior = .automatic
        return wv
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
    /// - Parameter item: 帮助文章（含 HTML content）
    init(item: HelpFAQItem) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
        // 导航栏标题使用文章标题
        self.title = item.title
        // push 时自动隐藏 tabBar，pop 时自动恢复
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
        observeWebView()
        loadHTML()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = AppColor.Background.primary
        navigationItem.backButtonDisplayMode = .minimal

        view.addSubview(progressView)
        view.addSubview(webView)
    }

    private func setupConstraints() {
        // 进度条：紧贴安全区顶部
        progressView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Layout.progressHeight)
        }

        // 网页：填满进度条下方的剩余空间，底边贴 safeArea
        // - 底边贴 safeArea：避免内容被 Home Indicator 遮挡
        webView.snp.makeConstraints { make in
            make.top.equalTo(progressView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
    }

    /// 监听 `WKWebView.estimatedProgress`，驱动进度条
    ///
    /// - Note: KVO 回调不保证在主线程，内部统一切主。
    private func observeWebView() {
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            let progress = Float(webView.estimatedProgress)
            DispatchQueue.main.async {
                guard let self else { return }
                self.progressView.setProgress(progress, animated: true)

                if progress >= 1.0 {
                    // 完成后淡出进度条
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
    }

    // MARK: - Load

    /// 加载并渲染 HTML
    private func loadHTML() {
        AppLog.profile.debug(
            "渲染帮助详情：aid=\(self.item.id, privacy: .private) title=\(self.item.title, privacy: .private)"
        )

        // 用统一模板包装 HTML 片段（字体 / 行高 / 深色模式 / 表格样式等）
        let html = AgreementHTMLTemplate.wrap(item.content, title: item.title)
        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: - Error Handling

    /// 处理加载失败（带防重入）
    ///
    /// - Parameter error: WebKit 抛出的错误
    ///
    /// - Note: **只在首次失败时弹 Alert**——
    ///         若同一页面被多次失败回调触发（如重定向链中的某次失败），
    ///         只弹一次，避免用户连续关闭多个弹窗。
    private func handleLoadFailure(_ error: Error) {
        // 主动取消（用户返回上一页）不算错误
        if (error as NSError).code == NSURLErrorCancelled { return }

        AppLog.profile.error("帮助详情加载失败：\(error.localizedDescription, privacy: .public)")

        guard !hasShownErrorAlert else { return }
        hasShownErrorAlert = true

        let alert = UIAlertController(
            title: "加载失败",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
            self?.hasShownErrorAlert = false
            self?.loadHTML()
        })
        alert.addAction(UIAlertAction(title: "返回", style: .cancel) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - WKNavigationDelegate

extension HelpFAQDetailViewController: WKNavigationDelegate {

    /// 加载完成
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressView.isHidden = true
    }

    /// 加载失败（页面已开始渲染后失败）
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        progressView.isHidden = true
        handleLoadFailure(error)
    }

    /// 加载失败（页面尚未渲染时失败）
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        progressView.isHidden = true
        handleLoadFailure(error)
    }

    /// 内存压力下 WebKit 内容进程可能被回收，页面会白屏；重载当前 URL 即可恢复
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        AppLog.profile.warning("帮助详情内容进程被回收，重新加载")
        webView.reload()
    }
}

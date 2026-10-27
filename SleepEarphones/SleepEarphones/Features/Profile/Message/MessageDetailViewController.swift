//
//  MessageDetailViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import UIKit
import WebKit
import SnapKit


@MainActor
final class MessageDetailViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        /// 进度条高度：hairline（0.5pt）
        static let progressHeight: CGFloat = 0.5
        /// 内容左右边距
        static let horizontalInset: CGFloat = 20
        /// 标题与进度条间距
        static let titleTopInset: CGFloat = AppSpacing.md
        /// 标题与时间间距
        static let timeTopInset: CGFloat = AppSpacing.xs
        /// 时间高度
        static let timeHeight: CGFloat = 20
        /// 头部下方间距（头部与网页之间的间隔）
        static let headerBottomInset: CGFloat = AppSpacing.sm
    }

    // MARK: - Properties

    /// 消息模型（由调用方注入）
    private let message: MessageModel

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

    /// 标题
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Body.emphasized
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 0   // 标题可能多行
        return l
    }()

    /// 时间
    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Caption.regular
        l.textColor = AppColor.Text.secondary
        return l
    }()

    /// 网页容器（仅渲染正文）
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

    /// 进度条
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
    /// - Parameter message: 消息模型（含 HTML content）
    init(message: MessageModel) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
        // 导航栏标题用分类名（如"平台公告"）——标识页面类型
        // 文章标题在内容区显示——标识具体文章
        self.title = message.categoryName
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
        setupContent()
        observeWebView()
        loadHTML()
    }

    // MARK: - Setup

    private func setupUI() {
        // 白底（对齐 XIB）
        view.backgroundColor = AppColor.Background.primary
        navigationItem.backButtonDisplayMode = .minimal

        view.addSubview(progressView)
        view.addSubview(titleLabel)
        view.addSubview(timeLabel)
        view.addSubview(webView)
    }

    private func setupConstraints() {
        // 进度条：紧贴安全区顶部
        progressView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Layout.progressHeight)
        }

        // 标题：与进度条留出间距
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(progressView.snp.bottom).offset(Layout.titleTopInset)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        // 时间
        timeLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Layout.timeTopInset)
            make.leading.trailing.equalTo(titleLabel)
            make.height.equalTo(Layout.timeHeight)
        }

        // 网页：占据剩余空间，底边贴 safeArea 避免被 Home Indicator 遮挡
        webView.snp.makeConstraints { make in
            make.top.equalTo(timeLabel.snp.bottom).offset(Layout.headerBottomInset)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
    }

    /// 填充静态内容（标题 / 时间）
    private func setupContent() {
        titleLabel.text = message.title
        timeLabel.text = message.createTime
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

    /// 加载并渲染 HTML 正文
    private func loadHTML() {
        AppLog.profile.debug(
            "渲染消息详情：aid=\(self.message.id, privacy: .private)"
        )

        // 用统一模板包装 HTML 片段
        let html = AgreementHTMLTemplate.wrap(message.content, title: message.title)
        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: - Error Handling

    /// 处理加载失败（带防重入）
    ///
    /// - Parameter error: WebKit 抛出的错误
    ///
    /// - Note: **只在首次失败时弹 Alert**——
    ///         若同一页面被多次失败回调触发，只弹一次，避免连续弹窗。
    private func handleLoadFailure(_ error: Error) {
        // 主动取消（用户返回上一页）不算错误
        if (error as NSError).code == NSURLErrorCancelled { return }

        AppLog.profile.error("消息详情加载失败：\(error.localizedDescription, privacy: .public)")

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

extension MessageDetailViewController: WKNavigationDelegate {

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
        AppLog.profile.warning("消息详情内容进程被回收，重新加载")
        webView.reload()
    }
}

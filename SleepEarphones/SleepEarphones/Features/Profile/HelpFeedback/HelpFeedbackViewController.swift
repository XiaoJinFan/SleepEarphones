//
//  HelpFeedbackViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/16.
//

import UIKit
import SnapKit
import Combine

/// 帮助与反馈页
@MainActor
final class HelpFeedbackViewController: UIViewController {

    // MARK: - Properties

    /// 视图模型
    private let viewModel = HelpFeedbackViewModel()

    /// Combine 订阅容器
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI

    /// 帮助文章列表
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.showsVerticalScrollIndicator = false
        tv.contentInset = UIEdgeInsets(
            top: AppSpacing.xs,
            left: 0,
            bottom: AppSpacing.md,
            right: 0
        )
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 80
        tv.dataSource = self
        tv.delegate = self
        tv.register(FAQCell.self, forCellReuseIdentifier: FAQCell.reuseID)
        return tv
    }()

    /// 首屏加载菊花
    private lazy var loadingView: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(style: .medium)
        v.hidesWhenStopped = true
        v.color = AppColor.Text.tertiary
        return v
    }()

    /// 空数据占位视图
    private lazy var emptyView: EmptyStateView = {
        let v = EmptyStateView()
        v.configure(
            image: AppImage.Local.emptyData,
            text: "暂无帮助内容"
        )
        v.isHidden = true
        return v
    }()

    // MARK: - Init

    /// 初始化
    ///
    /// - Note: 用 `init()` 无参构造，无需 storyboard。
    init() {
        super.init(nibName: nil, bundle: nil)
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
        bindViewModel()

        // 首屏拉取帮助列表
        viewModel.loadFAQs()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "帮助与反馈"
        view.backgroundColor = AppColor.Background.secondary
        navigationItem.backButtonDisplayMode = .minimal

        view.addSubview(tableView)
        view.addSubview(loadingView)
        view.addSubview(emptyView)
    }

    private func setupConstraints() {
        // 列表：铺满全屏（contentInset 已在 tableView 内部处理）
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 菊花：居中
        loadingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        // 空态：顶部留一点边距，其余铺满
        emptyView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).inset(AppSpacing.xs)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.md)
            make.bottom.equalToSuperview()
        }
    }

    // MARK: - Binding

    private func bindViewModel() {
        // 列表变化：刷新表格 + 更新空态
        viewModel.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.tableView.reloadData()
                self.updateEmptyState()
            }
            .store(in: &cancellables)

        // 加载中：控制菊花 + 刷新空态
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self else { return }
                if isLoading {
                    self.loadingView.startAnimating()
                } else {
                    self.loadingView.stopAnimating()
                }
                self.updateEmptyState()
            }
            .store(in: &cancellables)

        // 错误信息：弹 Alert
        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.presentError(message)
            }
            .store(in: &cancellables)
    }

    // MARK: - Helpers

    /// 根据 ViewModel 状态决定是否展示空态
    private func updateEmptyState() {
        emptyView.isHidden = !viewModel.isEmpty
    }

    /// 弹出错误提示，关闭后清除 ViewModel 中的错误状态
    ///
    /// - Parameter message: 错误信息
    private func presentError(_ message: String) {
        showAlert(
            message,
            title: "提示",
            onConfirm: { [weak self] in
                self?.viewModel.clearError()
            }
        )
    }
}

// MARK: - UITableViewDataSource

extension HelpFeedbackViewController: UITableViewDataSource {

    /// 行数
    ///
    /// - Parameters:
    ///   - tableView: 目标表格
    ///   - section: 分组索引
    /// - Returns: 帮助文章数量
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.items.count
    }

    /// 单元格
    ///
    /// - Parameters:
    ///   - tableView: 目标表格
    ///   - indexPath: 行索引
    /// - Returns: 配置好的 `FAQCell`
    ///
    /// - Note: 用 `guard` 解包替代 `as!` 强制转换——
    ///         若 cell 注册 / Storyboard 配置错误，直接返回空白 cell 而非崩溃。
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: FAQCell.reuseID,
            for: indexPath
        ) as? FAQCell else {
            AppLog.ui.error("FAQCell 出队失败，检查 reuseID 注册")
            return UITableViewCell()
        }

        let item = viewModel.items[indexPath.row]
        cell.configure(title: item.title, subtitle: item.synopsis)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension HelpFeedbackViewController: UITableViewDelegate {

    /// 点击行 → 进入详情页
    ///
    /// - Parameters:
    ///   - tableView: 目标表格
    ///   - indexPath: 行索引
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = viewModel.items[indexPath.row]
        AppLog.profile.debug(
            "点击帮助文章：aid=\(item.id, privacy: .private) title=\(item.title, privacy: .private)"
        )

        // 无内容时不跳转（避免空白详情页）
        guard item.hasContent else {
            showToast("该文章暂无内容")
            return
        }

        let detailVC = HelpFAQDetailViewController(item: item)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

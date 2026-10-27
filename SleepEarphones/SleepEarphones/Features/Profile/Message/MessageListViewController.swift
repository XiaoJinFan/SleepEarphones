//
//  MessageListViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import UIKit
import SnapKit
import Combine

/// 消息中心列表页
@MainActor
final class MessageListViewController: UIViewController {

    // MARK: - Properties

    /// 视图模型
    private let viewModel = MessageListViewModel()

    /// Combine 订阅容器
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI

    /// 消息列表
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
        // 自适应高度：由 cell 内部约束推导
        // （MessageCell ~ 80pt / MessageImageCell ~ 200pt）
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 100
        tv.dataSource = self
        tv.delegate = self
        // 注册两种 cell
        tv.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseID)
        tv.register(MessageImageCell.self, forCellReuseIdentifier: MessageImageCell.reuseID)
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
            text: "暂无消息"
        )
        v.isHidden = true
        return v
    }()

    // MARK: - Init

    /// 初始化
    ///
    /// - Note: push 时自动隐藏 tabBar，pop 时自动恢复。
    init() {
        super.init(nibName: nil, bundle: nil)
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

        // 首屏拉取消息列表
        viewModel.loadMessages()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = AppColor.Background.secondary
        title = "我的消息"
        navigationItem.backButtonDisplayMode = .minimal

        view.addSubview(tableView)
        view.addSubview(loadingView)
        view.addSubview(emptyView)
    }

    private func setupConstraints() {
        // 列表：左右缩进 20pt，上下贴边
        tableView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.top.bottom.equalToSuperview()
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
        viewModel.$messages
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

extension MessageListViewController: UITableViewDataSource {

    /// 行数
    ///
    /// - Parameters:
    ///   - tableView: 目标表格
    ///   - section: 分组索引
    /// - Returns: 消息数量
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.messages.count
    }

    /// 单元格
    ///
    /// - Parameters:
    ///   - tableView: 目标表格
    ///   - indexPath: 行索引
    /// - Returns: 配置好的 Cell
    ///
    /// ## Cell 选择策略
    /// - 有图 → `MessageImageCell`（大卡片，200pt）
    /// - 无图 → `MessageCell`（小卡片，80pt）
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = viewModel.messages[indexPath.row]

        if message.hasImage {
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: MessageImageCell.reuseID,
                for: indexPath
            ) as? MessageImageCell else {
                AppLog.ui.error("MessageImageCell 出队失败，检查 reuseID 注册")
                return UITableViewCell()
            }
            cell.configure(with: message)
            return cell
        } else {
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: MessageCell.reuseID,
                for: indexPath
            ) as? MessageCell else {
                AppLog.ui.error("MessageCell 出队失败，检查 reuseID 注册")
                return UITableViewCell()
            }
            cell.configure(with: message)
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension MessageListViewController: UITableViewDelegate {

    /// 点击行 → 进入详情页
    ///
    /// - Parameters:
    ///   - tableView: 目标表格
    ///   - indexPath: 行索引
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let message = viewModel.messages[indexPath.row]
        AppLog.profile.debug(
            "点击消息：aid=\(message.id, privacy: .private) title=\(message.title, privacy: .private)"
        )

        // 无内容时不跳转（避免空白详情页）
        guard message.hasContent else {
            showToast("该消息暂无内容")
            return
        }

        let detailVC = MessageDetailViewController(message: message)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

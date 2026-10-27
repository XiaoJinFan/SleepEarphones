//
//  MyDeviceViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/11.
//

import UIKit
import Combine
import SnapKit

/// 我的设备页
@MainActor
final class MyDeviceViewController: UIViewController {

    // MARK: - Properties

    /// 设备列表 ViewModel（由外部注入或本页自建）
    private let viewModel: MyDeviceViewModel

    /// Combine 订阅容器
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI

    /// 设备列表
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
        tv.estimatedRowHeight = 140
        tv.dataSource = self
        tv.delegate = self
        tv.register(DeviceCell.self, forCellReuseIdentifier: DeviceCell.reuseID)
        return tv
    }()

    /// 下拉刷新
    private lazy var refreshControl: UIRefreshControl = {
        let rc = UIRefreshControl()
        rc.tintColor = AppColor.Text.secondary
        rc.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        return rc
    }()

    /// 空数据占位视图
    private lazy var emptyView: EmptyStateView = {
        let v = EmptyStateView(style: .device)
        v.isHidden = true
        return v
    }()

    /// 首次加载时的菊花
    private lazy var loadingView: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(style: .medium)
        v.hidesWhenStopped = true
        v.color = AppColor.Text.tertiary
        return v
    }()

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter viewModel: 外部注入的 ViewModel（如由「我的」页面共享）；
    ///                        传 nil 时本页自建一个新实例。
    ///
    /// - Note: `init` 已由 `@MainActor` 隔离，可以安全创建 `@MainActor` 的 ViewModel。
    init(viewModel: MyDeviceViewModel? = nil) {
        self.viewModel = viewModel ?? MyDeviceViewModel()
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
        bindViewModel()

        // 主动拉取一次数据，确保外部共享的 ViewModel 也保持最新
        viewModel.loadDevices()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 用户可能已登录 / 登出，检测是否需要刷新
        // （内部有 guard，userId 未变化时不会触发请求）
        viewModel.refreshIfUserChanged()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "我的设备"
        view.backgroundColor = AppColor.Background.secondary
        navigationItem.backButtonDisplayMode = .minimal

        tableView.refreshControl = refreshControl

        view.addSubview(tableView)
        view.addSubview(emptyView)
        view.addSubview(loadingView)

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        emptyView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).inset(AppSpacing.xs)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.md)
            make.bottom.equalToSuperview()
        }

        loadingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    // MARK: - Binding

    private func bindViewModel() {
        // 设备列表变化：刷新表格 + 更新空态
        viewModel.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.tableView.reloadData()
                self.updateEmptyState()
            }
            .store(in: &cancellables)

        // 加载状态变化：控制菊花与下拉刷新
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self else { return }
                if isLoading {
                    // 已有数据时不显示全屏菊花（避免刷新时闪烁）
                    if self.viewModel.devices.isEmpty {
                        self.loadingView.startAnimating()
                    }
                } else {
                    self.loadingView.stopAnimating()
                    self.refreshControl.endRefreshing()
                }
                self.updateEmptyState()
            }
            .store(in: &cancellables)

        // 错误信息：弹出提示
        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.presentError(message)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func handleRefresh() {
        viewModel.loadDevices(isRefresh: true)
    }

    // MARK: - Helpers

    /// 根据 ViewModel 状态决定是否展示空态
    private func updateEmptyState() {
        emptyView.isHidden = !viewModel.isEmpty
    }

    /// 弹出错误提示，关闭后清除 ViewModel 中的错误状态
    ///
    /// - Note: 使用 `UIViewController+Toast` 扩展的 `showAlert(_:title:popOnDismiss:onConfirm:)`。
    ///         原调用 `showAlert(message) { ... }` 依赖尾随闭包，
    ///         但扩展签名有 4 个参数，需显式命名 `onConfirm:`。
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

extension MyDeviceViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.devices.count
    }

    /// ✅ 用 guard 解包替代 `as!` 强制转换
    ///
    /// - 若 cell 注册 / Storyboard 配置错误，`as!` 直接崩溃
    /// - 改为 guard + 日志，即使出错也只返回空白 cell，不闪退
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: DeviceCell.reuseID,
            for: indexPath
        ) as? DeviceCell else {
            AppLog.ui.error("DeviceCell 出队失败，检查 reuseID 注册")
            return UITableViewCell()
        }

        cell.configure(with: viewModel.devices[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension MyDeviceViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let device = viewModel.devices[indexPath.row]
        AppLog.device.debug(
            "点击设备：\(device.id, privacy: .private) name=\(device.name, privacy: .private)"
        )
        // TODO: 跳转设备详情
    }
}

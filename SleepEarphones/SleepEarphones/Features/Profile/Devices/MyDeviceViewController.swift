//
//  MyDeviceViewController.swift
//  SleepEarphones
//

import UIKit
import Combine
import SnapKit

/// 我的设备页（纯展示页面，不涉及蓝牙连接）
@MainActor
final class MyDeviceViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: MyDeviceViewModel
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

    /// 空数据占位视图
    private lazy var emptyView: EmptyStateView = {
        let v = EmptyStateView(style: .device)
        v.isHidden = true
        return v
    }()

    // MARK: - Init

    /// 初始化
    /// - Parameter viewModel: 外部注入的 ViewModel（如由「我的」页面共享）
    init(viewModel: MyDeviceViewModel? = nil) {
        self.viewModel = viewModel ?? MyDeviceViewModel()
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
        bindViewModel()
    }

    // MARK: - Setup

    private func setupUI() {
        title = L("我的设备")
        view.backgroundColor = AppColor.Background.secondary
        navigationItem.backButtonDisplayMode = .minimal

        view.addSubview(tableView)
        view.addSubview(emptyView)

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        emptyView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).inset(AppSpacing.xs)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.md)
            make.bottom.equalToSuperview()
        }
    }

    // MARK: - Binding

    private func bindViewModel() {
        // 监听本地设备列表变化
        viewModel.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.tableView.reloadData()
                self.updateEmptyState()
            }
            .store(in: &cancellables)
    }

    // MARK: - Helpers

    private func updateEmptyState() {
        emptyView.isHidden = !viewModel.isEmpty
    }
}

// MARK: - UITableViewDataSource

extension MyDeviceViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.devices.count
    }

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

    /// 侧滑删除（操作本地数据库）
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: L("删除")) { [weak self] _, _, completionHandler in
            guard let self = self else { return }
            
            // 从 ViewModel 中删除（内部会通知 LocalDeviceManager 清理本地数据）
            self.viewModel.deleteDevice(at: indexPath.row)
            
            completionHandler(true)
            self.showToast(L("已删除"))
        }
        deleteAction.image = UIImage(systemName: "trash")
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }

    /// 纯展示页面：点击 Cell 不执行任何跳转或连接操作
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // 留空：不涉及任何蓝牙或网络操作
    }
}

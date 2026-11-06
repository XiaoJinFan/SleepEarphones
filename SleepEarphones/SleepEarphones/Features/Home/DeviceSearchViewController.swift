//
//  DeviceSearchViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/22.
//

import UIKit
import Combine
import LinkcosBluetooth
import SnapKit

/// 设备搜索页
@MainActor
final class DeviceSearchViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        /// 动画区域高度
        static let animationAreaHeight: CGFloat = 180
        /// 列表行高
        static let rowHeight: CGFloat = 84
    }

    // MARK: - Properties

    private let viewModel = HomeViewModel.shared
    private var cancellables = Set<AnyCancellable>()
    private var devices: [DeviceViewData] = []

    /// 正在连接的设备 ID（`DeviceViewData.id`）
    private var connectingDeviceID: String?

    // MARK: - UI

    private let animationView = SearchingAnimationView()

    /// 搜索主提示语
    private let searchingLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Caption.regular
        l.textColor = AppColor.Text.tertiary
        l.textAlignment = .center
        l.text = L("正在搜索附近设备…")
        return l
    }()

    /// 辅助操作提示语
    private let hintLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Caption.regular
        l.textColor = AppColor.Text.tertiary
        l.textAlignment = .center
        l.numberOfLines = 0
        l.text = L("请确认耳机已处于可配对状态，或点击右上方手动添加")
        return l
    }()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.rowHeight = Layout.rowHeight
        tv.dataSource = self
        tv.delegate = self
        tv.register(BleSearchDeviceCell.self, forCellReuseIdentifier: BleSearchDeviceCell.reuseID)
        return tv
    }()

    // MARK: - Init

    init() {
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupUI()
        setupConstraints()
        bindViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        animationView.start()

        // ✅ 关键顺序：先清空 → 再扫描
        viewModel.clearDevices()
        viewModel.startScan()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        animationView.stop()

        // 离开页面必须停止扫描，节约电量
        viewModel.stopScan()
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        title = L("添加设备")
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: AppColor.Text.primary]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = AppColor.Text.primary
        
        // 右上角手动添加按钮（四宫格图标）
        let manualAddBtn = UIButton(type: .system)
        manualAddBtn.setImage(
            UIImage(
                systemName: "circle.grid.2x2",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            ),
            for: .normal
        )
        manualAddBtn.tintColor = AppColor.Text.primary
        manualAddBtn.addTarget(self, action: #selector(manualAddTapped), for: .touchUpInside)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: manualAddBtn)
    }

    private func setupUI() {
        view.backgroundColor = AppColor.Background.primary
        view.addSubview(animationView)
        view.addSubview(searchingLabel)
        view.addSubview(hintLabel)
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        animationView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(AppSpacing.xxl)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(Layout.animationAreaHeight)
        }
        
        searchingLabel.snp.makeConstraints { make in
            make.top.equalTo(animationView.snp.bottom).offset(AppSpacing.md)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
        }
        
        hintLabel.snp.makeConstraints { make in
            make.top.equalTo(searchingLabel.snp.bottom).offset(AppSpacing.md)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(hintLabel.snp.bottom).offset(AppSpacing.xl)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
    }

    // MARK: - Binding

    private func bindViewModel() {
        // 设备列表更新
        viewModel.devicesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                guard let self = self else { return }
                self.devices = devices
                self.tableView.reloadData()
            }
            .store(in: &cancellables)

        // 连接状态更新
        viewModel.connectStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .connected:
                    self.connectingDeviceID = nil
                    // ✅ 用 ToastPresenter（keyWindow 上），避免 pop 后 Toast 不可见
                    ToastPresenter.success(L("连接成功"))
                    self.navigationController?.popViewController(animated: true)

                case .failed(let error):
                    self.showToast(L("连接失败：%@", error.localizedDescription))
                    self.connectingDeviceID = nil
                    self.tableView.reloadData()

                case .connecting:
                    break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func manualAddTapped() {
        // TODO: 跳转手动添加页面
        showToast(L("手动添加功能开发中"))
    }
}

// MARK: - UITableViewDataSource & Delegate

extension DeviceSearchViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: BleSearchDeviceCell.reuseID,
            for: indexPath
        ) as? BleSearchDeviceCell else {
            AppLog.ui.error("BleSearchDeviceCell 出队失败，检查 reuseID 注册")
            return UITableViewCell()
        }

        let device = devices[indexPath.row]
        let isConnecting = device.id == connectingDeviceID

        // imageURL 当前恒为 nil，用默认占位图兜底
        cell.configure(name: device.name, imageURL: nil, isConnecting: isConnecting)

        cell.onConnect = { [weak self] in
            guard let self = self else { return }
            // 正在连接其他设备时忽略——避免并发连接
            guard self.connectingDeviceID == nil else { return }

            self.connectingDeviceID = device.id
            self.tableView.reloadData()
            self.viewModel.connect(to: device.id)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let device = devices[indexPath.row]
        guard connectingDeviceID == nil else { return }

        connectingDeviceID = device.id
        tableView.reloadData()
        viewModel.connect(to: device.id)
    }
}

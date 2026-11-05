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
        static let animationAreaHeight: CGFloat = 280
        /// 列表行高
        static let rowHeight: CGFloat = 88
        /// "没有看到设备"提示的延迟（秒）
        static let emptyTipDelaySeconds: UInt64 = 8
    }

    // MARK: - Properties

    private let viewModel = HomeViewModel.shared
    private var cancellables = Set<AnyCancellable>()
    private var devices: [DeviceViewData] = []

    /// 正在连接的设备 ID（`DeviceViewData.id`）
    private var connectingDeviceID: String?

    private var emptyTipTask: Task<Void, Never>?

    // MARK: - UI

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Title.page
        l.textColor = AppColor.Text.primary
        l.text = L("搜索中…")
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Body.secondary
        l.textColor = AppColor.Text.secondary
        l.text = L("确保您的设备处于配对模式")
        l.numberOfLines = 0
        return l
    }()

    private let animationView = SearchingAnimationView()

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

    private lazy var emptyTipButton: UIButton = {
        var config = UIButton.Configuration.plain()
        var attr = AttributedString(L("没有看到设备？点击重新扫描"))
        attr.font = AppFont.Body.secondary
        attr.foregroundColor = AppColor.Brand.primary
        config.attributedTitle = attr
        let b = UIButton(configuration: config)
        b.isHidden = true
        b.addTarget(self, action: #selector(rescanTapped), for: .touchUpInside)
        return b
    }()

    // MARK: - Init

    init() {
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) { fatalError() }

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
        scheduleEmptyTip()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        animationView.stop()

        // 离开页面必须停止扫描，节约电量
        viewModel.stopScan()

        emptyTipTask?.cancel()
        emptyTipTask = nil
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        navigationItem.title = ""
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = .clear
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = AppColor.Text.primary
    }

    private func setupUI() {
        view.backgroundColor = AppColor.Background.secondary
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(animationView)
        view.addSubview(tableView)
        view.addSubview(emptyTipButton)
    }

    private func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(AppSpacing.sm)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(AppSpacing.sm)
            make.leading.trailing.equalTo(titleLabel)
        }
        animationView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(AppSpacing.md)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(Layout.animationAreaHeight)
        }
        emptyTipButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-AppSpacing.lg)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(animationView.snp.bottom).offset(AppSpacing.md)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(emptyTipButton.snp.top).offset(-AppSpacing.sm)
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
                if !devices.isEmpty {
                    self.emptyTipButton.isHidden = true
                }
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

                    // ✅ 用 ToastPresenter（keyWindow 上）——
                    //    `self.showToast` 挂在 VC 的 view 上，pop 后随 VC 销毁，
                    //    用户来不及看到"连接成功"的反馈。
                    ToastPresenter.success(L("连接成功"))
                    self.navigationController?.popViewController(animated: true)

                case .failed(let error):
                    // `error.localizedDescription` 来自 HomeViewModel 中的 `NSError`
                    // （其 `NSLocalizedDescriptionKey` 已用 `L(...)` 设置）
                    self.showToast(L("连接失败：%@", error.localizedDescription))
                    self.connectingDeviceID = nil
                    self.tableView.reloadData()

                case .connecting:
                    // `DeviceSearchViewController` 在 `didSelectRowAt` / `onConnect`
                    // 中已设置 `connectingDeviceID` 并 `reloadData`——
                    // 此处无需重复处理
                    break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Empty Tip

    /// 调度"没有看到设备"提示
    private func scheduleEmptyTip() {
        emptyTipTask?.cancel()
        emptyTipButton.isHidden = true
        emptyTipTask = Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: Layout.emptyTipDelaySeconds * 1_000_000_000
            )
            guard !Task.isCancelled, let self else { return }
            if self.devices.isEmpty {
                self.emptyTipButton.isHidden = false
            }
        }
    }

    // MARK: - Actions

    /// 点击"重新扫描"
    @objc private func rescanTapped() {
        viewModel.clearDevices()
        viewModel.startScan()
        scheduleEmptyTip()
    }
}

// MARK: - UITableViewDataSource

extension DeviceSearchViewController: UITableViewDataSource {

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

        // `imageURL` 当前恒为 `nil`——BLE 设备没有图片 URL，
        // 用 SF Symbol 兜底
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
}

// MARK: - UITableViewDelegate

extension DeviceSearchViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let device = devices[indexPath.row]
        guard connectingDeviceID == nil else { return }

        connectingDeviceID = device.id
        tableView.reloadData()
        viewModel.connect(to: device.id)
    }
}

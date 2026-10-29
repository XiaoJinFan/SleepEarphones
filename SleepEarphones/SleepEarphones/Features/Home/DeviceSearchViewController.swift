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

@MainActor
final class DeviceSearchViewController: UIViewController {

    private enum Layout {
        static let animationAreaHeight: CGFloat = 280
        static let rowHeight: CGFloat = 88
        static let emptyTipDelay: UInt64 = 8
    }

    private let viewModel = HomeViewModel.shared
    private var cancellables = Set<AnyCancellable>()
    private var devices: [DeviceViewData] = []
    private var connectingDeviceID: String?
    private var emptyTipTask: Task<Void, Never>?

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 28, weight: .bold)
        l.textColor = AppColor.Text.primary
        l.text = "搜索中..."
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Body.secondary
        l.textColor = AppColor.Text.secondary
        l.text = "确保您的设备处于配对模式"
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
        var attr = AttributedString("没有看到设备？点击重新扫描")
        attr.font = AppFont.Body.secondary
        attr.foregroundColor = AppColor.Brand.primary
        config.attributedTitle = attr
        let b = UIButton(configuration: config)
        b.isHidden = true
        b.addTarget(self, action: #selector(rescanTapped), for: .touchUpInside)
        return b
    }()

    init() {
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupUI()
        setupConstraints()
        bindViewModel()

        // 只在初次加载时清空，防止切后台重进导致列表被清空
        viewModel.clearDevices()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        animationView.start()

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

    private func bindViewModel() {
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

        viewModel.connectStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .connected:
                    self.connectingDeviceID = nil

                    // ✅ 用 ToastPresenter（keyWindow 上）——
                    //    `self.showToast` 在 pop 后随 view 销毁，用户看不到
                    ToastPresenter.success("连接成功")
                    self.navigationController?.popViewController(animated: true)

                case .failed(let error):
                    self.showToast("连接失败：\(error.localizedDescription)")
                    self.connectingDeviceID = nil
                    self.tableView.reloadData()

                case .connecting:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func scheduleEmptyTip() {
        emptyTipTask?.cancel()
        emptyTipButton.isHidden = true
        emptyTipTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Layout.emptyTipDelay * 1_000_000_000)
            guard !Task.isCancelled, let self else { return }
            if self.devices.isEmpty {
                self.emptyTipButton.isHidden = false
            }
        }
    }

    @objc private func rescanTapped() {
        viewModel.clearDevices()
        viewModel.startScan()
        scheduleEmptyTip()
    }
}

extension DeviceSearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: BleSearchDeviceCell.reuseID, for: indexPath) as? BleSearchDeviceCell else {
            return UITableViewCell()
        }

        let device = devices[indexPath.row]
        let isConnecting = device.id == connectingDeviceID

        cell.configure(name: device.name, imageURL: nil, isConnecting: isConnecting)
        cell.onConnect = { [weak self] in
            guard let self = self else { return }
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

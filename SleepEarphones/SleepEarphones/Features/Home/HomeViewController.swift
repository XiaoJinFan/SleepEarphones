//
//  HomeViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/5.
//

import UIKit
import Combine
import LinkcosBluetooth


@MainActor
final class HomeViewController: UIViewController {

    // MARK: - IBOutlet

    /// 空设备占位图（无设备时显示）
    @IBOutlet weak var nullDeviceImgView: UIImageView!

    /// 设备列表
    @IBOutlet weak var deviceCollectionView: UICollectionView!

    /// "添加设备"按钮
    @IBOutlet weak var addDeviceBtn: UIButton!

    // MARK: - Properties

    private let viewModel = HomeViewModel()
    private var cancellables = Set<AnyCancellable>()

    /// 数据源
    private var devices: [DeviceViewData] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        AppLog.app.debug("HomeViewController 已加载")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = false
        // 页面出现时开始扫描
        viewModel.startScan()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 页面消失时停止扫描（省电）
        viewModel.stopScan()
    }

    // MARK: - Setup

    private func setupUI() {

        // 1. 设置列表
        deviceCollectionView.delegate = self
        deviceCollectionView.dataSource = self
        deviceCollectionView.register(
            DeviceCardCell.self,
            forCellWithReuseIdentifier: DeviceCardCell.reuseID
        )

        // 2. 使用 CompositionalLayout 实现高度自适应（移除硬编码）
        deviceCollectionView.collectionViewLayout = makeCompositionalLayout()

        // 3. 添加设备按钮事件
        addDeviceBtn.layer.cornerRadius = AppSpacing.Corner.card
        addDeviceBtn.addTarget(self, action: #selector(addDeviceTapped), for: .touchUpInside)
    }

    /// 构建自适应高度的布局
    private func makeCompositionalLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(160) // 预估高度，实际由 AutoLayout 撑开
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(160)
            )
            let group = NSCollectionLayoutGroup.vertical(
                layoutSize: groupSize,
                subitems: [item]
            )

            let section = NSCollectionLayoutSection(group: group)
            // 列表底部留白，避免紧贴 tabBar
            section.contentInsets = NSDirectionalEdgeInsets(
                top: AppSpacing.xs,
                leading: 0,
                bottom: AppSpacing.md,
                trailing: 0
            )
            return section
        }
    }

    // MARK: - Binding

    private func bindViewModel() {
        // 1. 绑定设备列表
        viewModel.devicesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                guard let self = self else { return }
                self.devices = devices
                self.deviceCollectionView.reloadData()
            }
            .store(in: &cancellables)

        // 2. 绑定空视图状态
        viewModel.isEmptyPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEmpty in
                guard let self = self else { return }
                self.nullDeviceImgView.isHidden = !isEmpty
                self.deviceCollectionView.isHidden = isEmpty
            }
            .store(in: &cancellables)

        // 3. 绑定蓝牙开关状态
        viewModel.bleStatePublisher
            .receive(on: DispatchQueue.main)
            .dropFirst() // 忽略初始的 unknown 状态
            .sink { [weak self] state in
                self?.handleBleStateChange(state)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    /// 点击“添加设备”
    @objc private func addDeviceTapped() {
        // 清空旧列表并重新触发扫描
        viewModel.clearDevices()
        viewModel.startScan()
        showToast("正在重新扫描附近设备…")
    }

    // MARK: - BLE State Handling

    /// 处理手机蓝牙状态变化
    ///
    /// - Parameter state: 蓝牙适配器状态
    private func handleBleStateChange(_ state: BleDeviceState) {
        // 根据头文件，6 是蓝牙已开启，7 是未开启，5 是未授权
        switch state.rawValue {
        case 7: // BleDeviceStateBlePowerOff
            showAlert(
                "请前往系统设置打开蓝牙",
                title: "蓝牙未开启"
            )
        case 5: // BleDeviceStateUnauthorized
            showAlert(
                "请前往系统设置允许 App 使用蓝牙",
                title: "蓝牙权限未授权"
            )
        default:
            // 蓝牙已开启（6）或未知状态（4），无需提示
            break
        }
    }
}

// MARK: - UICollectionViewDelegate & DataSource

extension HomeViewController: UICollectionViewDelegate, UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return devices.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: DeviceCardCell.reuseID,
            for: indexPath
        ) as? DeviceCardCell else {
            AppLog.ui.error("DeviceCardCell 出队失败")
            return UICollectionViewCell()
        }

        let data = devices[indexPath.row]
        cell.configure(with: data)
        return cell
    }
}

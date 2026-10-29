//
//  HomeViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/5.
//

import UIKit
import Combine
import SnapKit

/// 首页 Tab
///
/// ## 连接状态判断（重要）
/// 本页的"已连接"判断分两层：
/// | 判据 | 来源 | 含义 |
/// |---|---|---|
/// | BLE 匹配 | `currentlyConnectedMac` / `currentlyConnectedUUID` | 蓝牙通道已建立 |
/// | 音频路由 | `isAudioRouted`（`isHeadsetPluggedIn()`） | 经典蓝牙音频已切到耳机 |
///
/// 三层状态：
/// - **已连接** = BLE 匹配 + 音频路由 → 完全可用（含听歌）
/// - **已配对** = BLE 匹配但音频未切 → 可控制 ANC / 看电量，但声音未走耳机
/// - **未连接** = BLE 不匹配
///
/// - Note: 音频切换有延迟（0.5~2s），VM 已做延迟兜底 + 路由通知监听——
///         本页无需关心时序，直接读 `isAudioRouted` 即可。
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
    private let viewModel = MyDeviceViewModel()
    private let bleViewModel = HomeViewModel.shared
    private var cancellables = Set<AnyCancellable>()

    /// 数据源
    private var devices: [DeviceModel] = []

    /// 标记：是否正在执行本地删除（用于拦截 reloadData 防止动画冲突）
    private var isDeletingLocally = false

    /// 当前 BLE 连接设备的 MAC
    private var currentConnectedMac: String?

    /// 当前 BLE 连接设备的 UUID
    private var currentConnectedUUID: String?

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

        // 每次进入都刷新一次（以防在其它页面添加了设备）
        viewModel.loadDevices()
    }

    // MARK: - Setup
    private func setupUI() {
        deviceCollectionView.delegate = self
        deviceCollectionView.dataSource = self
        deviceCollectionView.register(
            HomeDeviceCardCell.self,
            forCellWithReuseIdentifier: HomeDeviceCardCell.reuseID
        )
        deviceCollectionView.collectionViewLayout = makeCompositionalLayout()

        addDeviceBtn.layer.cornerRadius = AppSpacing.Corner.card
        addDeviceBtn.addTarget(self, action: #selector(addDeviceTapped), for: .touchUpInside)
    }

    /// 构建自适应高度的列表布局，并支持滑动删除
    private func makeCompositionalLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.showsSeparators = false
        config.backgroundColor = .clear

        // 侧滑删除配置
        config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self = self, indexPath.row < self.devices.count else { return nil }
            let device = self.devices[indexPath.row]

            let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
                guard let self = self else { return }

                // 1. 设置标识，防止数据源更新时触发全量 reloadData
                self.isDeletingLocally = true

                // 2. 移除本地数据
                self.viewModel.removeDeviceLocally(at: indexPath.row)

                // 3. 完成系统 UI 动画
                completion(true)
                self.isDeletingLocally = false

                // 4. 异步发起网络请求
                self.viewModel.requestDeleteDevice(id: device.id)
                    .receive(on: DispatchQueue.main)
                    .sink(
                        receiveCompletion: { [weak self] completion in
                            if case .failure(let error) = completion {
                                self?.showToast("删除失败: \(error.localizedDescription)")
                                self?.viewModel.loadDevices()
                            } else {
                                self?.showToast("删除成功")
                            }
                        },
                        receiveValue: { _ in }
                    )
                    .store(in: &self.cancellables)
            }
            deleteAction.image = UIImage(systemName: "trash")
            return UISwipeActionsConfiguration(actions: [deleteAction])
        }

        let layout = UICollectionViewCompositionalLayout { _, environment in
            let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: environment)
            section.contentInsets = NSDirectionalEdgeInsets(
                top: AppSpacing.xs, leading: 0, bottom: AppSpacing.md, trailing: 0
            )
            return section
        }
        return layout
    }

    // MARK: - Binding
    private func bindViewModel() {
        // 1. 服务器设备列表变化
        viewModel.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                guard let self = self else { return }
                self.devices = devices

                // 侧滑删除引发的变化 → 跳过 reloadData，避免重置动画
                if !self.isDeletingLocally {
                    self.deviceCollectionView.reloadData()
                }
                self.updateEmptyState()
            }
            .store(in: &cancellables)

        // 2. 加载状态
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateEmptyState() }
            .store(in: &cancellables)

        // 3. 错误提示
        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] msg in
                self?.showAlert(msg)
                self?.viewModel.clearError()
            }
            .store(in: &cancellables)

        // 4. 监听 BLE 实时连接状态
        //
        // - ✅ 用 `CombineLatest3` 合并三个信号：
        //   - MAC / UUID：BLE 匹配判据
        //   - isAudioRouted：音频路由判据
        // - 任意一个变化都会刷新 cell 的连接状态显示
        Publishers.CombineLatest3(
            bleViewModel.$currentlyConnectedMac,
            bleViewModel.$currentlyConnectedUUID,
            bleViewModel.$isAudioRouted
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] mac, uuid, _ in
            guard let self = self else { return }
            self.currentConnectedMac = mac
            self.currentConnectedUUID = uuid
            self.deviceCollectionView.reloadData()
        }
        .store(in: &cancellables)

        // 5. 监听连接结果反馈
        bleViewModel.connectStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .connected:
                    self?.showToast("设备连接成功")
                case .failed(let error):
                    self?.showToast("连接失败: \(error.localizedDescription)")
                case .connecting:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func updateEmptyState() {
        let isEmpty = devices.isEmpty && !viewModel.isLoading
        nullDeviceImgView.isHidden = !isEmpty
        deviceCollectionView.isHidden = isEmpty
    }

    // MARK: - Actions
    @objc private func addDeviceTapped() {
        let vc = DeviceSearchViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - UICollectionViewDelegate & DataSource
extension HomeViewController: UICollectionViewDelegate, UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return devices.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: HomeDeviceCardCell.reuseID,
            for: indexPath
        ) as? HomeDeviceCardCell else {
            return UICollectionViewCell()
        }

        let device = devices[indexPath.row]

        // MARK: 三态连接判断
        //
        // 1. BLE 匹配：该设备是当前 BLE 连接的设备吗？
        let isBleMatched = (currentConnectedMac != nil && device.mac == currentConnectedMac) ||
                           (currentConnectedUUID != nil && device.serialNumber == currentConnectedUUID)

        // 2. 音频路由：BLE 已匹配 + 经典蓝牙音频已切到耳机？
        //
        // - Note: `isHeadsetPluggedIn()` 内部检查 `connectDevice` 的音频路由——
        //         所以必须 `isBleMatched` 为前置条件，否则可能误判其他设备。
        let isAudioRouted = isBleMatched && bleViewModel.isAudioRouted

        cell.configure(
            with: device,
            isConnected: isAudioRouted,   // 完全就绪
            isPaired: isBleMatched        // 仅 BLE
        )

        cell.onReportTapped = { [weak self] in
            self?.showToast("睡眠报告页面开发中")
        }

        return cell
    }

    /// 点击 Cell 发起 BLE 连接
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        let device = devices[indexPath.row]
        let serialNumber = device.serialNumber

        guard !serialNumber.isEmpty else {
            showToast("该设备无序列号，无法连接")
            return
        }

        showToast("正在搜索并连接设备...")
        // 交由 ViewModel 智能匹配：已扫到立即连，没扫到则挂起 + 扫描
        bleViewModel.connectBySerialNumber(serialNumber)
    }
}

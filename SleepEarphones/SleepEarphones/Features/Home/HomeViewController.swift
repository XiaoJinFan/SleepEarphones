//
//  HomeViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/5.
//

import UIKit
import Combine
import SnapKit

@MainActor
final class HomeViewController: UIViewController {

    // MARK: - IBOutlet
    
    /// 首页标题文本
    @IBOutlet weak var HomeLab: UILabel!
    
    /// 空设备占位图（无设备时显示）
    @IBOutlet weak var nullDeviceImgView: UIImageView!

    /// 设备列表
    @IBOutlet weak var deviceCollectionView: UICollectionView!

    /// "添加设备"按钮
    @IBOutlet weak var addDeviceBtn: UIButton!

    // MARK: - Properties
    
    /// 蓝牙设备管理 ViewModel
    private let bleViewModel = HomeViewModel.shared
    private var cancellables = Set<AnyCancellable>()

    /// 本地数据库中的设备列表
    private var savedDevices: [DeviceModel] = []
    
    /// BLE 扫描到的实时设备列表
    private var bleDevices: [DeviceViewData] = []
    
    /// 正在尝试连接的设备序列号（用于连接成功后自动跳转）
    private var pendingConnectSerialNumber: String?
    
    /// 标记是否正在执行本地删除（避免动画冲突）
    private var isDeletingLocally = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        HomeLab.text = L("首页")
        addDeviceBtn.setTitle(L("添加设备"), for: .normal)
        
        setupUI()
        bindViewModel()
        AppLog.app.debug("HomeViewController 已加载")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = false
    }

    // MARK: - Setup

    private func setupUI() {
        deviceCollectionView.delegate = self
        deviceCollectionView.dataSource = self
        deviceCollectionView.register(HomeDeviceCardCell.self, forCellWithReuseIdentifier: HomeDeviceCardCell.reuseID)
        deviceCollectionView.collectionViewLayout = makeCompositionalLayout()

        addDeviceBtn.layer.cornerRadius = AppSpacing.Corner.card
        addDeviceBtn.addTarget(self, action: #selector(addDeviceTapped), for: .touchUpInside)
    }

    /// 构建自适应高度的列表布局，并支持滑动删除
    private func makeCompositionalLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.showsSeparators = false
        config.backgroundColor = .clear

        config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self = self, indexPath.row < self.savedDevices.count else { return nil }
            let device = self.savedDevices[indexPath.row]

            let deleteAction = UIContextualAction(style: .destructive, title: L("删除")) { [weak self] _, _, completion in
                guard let self = self else { completion(false); return }
                
                // 1. 检查当前要删除的设备是否正是已连接设备
                let isBleMatched = self.bleViewModel.currentlyConnectedUUID?.caseInsensitiveCompare(device.serialNumber) == .orderedSame ||
                                   (!device.mac.isEmpty && self.bleViewModel.currentlyConnectedMac?.caseInsensitiveCompare(device.mac) == .orderedSame)
                
                // 2. 如果已连接，必须先断开底层蓝牙连接
                if isBleMatched {
                    self.bleViewModel.disconnect()
                }

                // 3. 从本地数据库移除
                self.isDeletingLocally = true
                LocalDeviceManager.shared.removeDevice(bySerialNumber: device.serialNumber)
                completion(true)
                self.isDeletingLocally = false
                self.showToast(L("已删除"))
            }
            deleteAction.image = UIImage(systemName: "trash")
            return UISwipeActionsConfiguration(actions: [deleteAction])
        }

        let layout = UICollectionViewCompositionalLayout { _, environment in
            let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: environment)
            section.contentInsets = NSDirectionalEdgeInsets(top: AppSpacing.xs, leading: 0, bottom: AppSpacing.md, trailing: 0)
            return section
        }
        return layout
    }

    // MARK: - Binding

    /// 绑定 UI 与数据流
    private func bindViewModel() {
        // 1. 合并：本地设备列表 + 扫描实时列表 + 已连接设备快照
        Publishers.CombineLatest3(
            LocalDeviceManager.shared.devicesPublisher,
            bleViewModel.devicesPublisher,
            bleViewModel.$connectedDeviceData
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] localList, bleList, connectedData in
            guard let self = self else { return }
            self.savedDevices = localList
            self.bleDevices = bleList
            
            // 如果已连接的设备不在当前扫描列表中，手动加入以确保电量能正常展示
            if let connected = connectedData, !self.bleDevices.contains(where: { $0.id == connected.id }) {
                self.bleDevices.append(connected)
            }

            if !self.isDeletingLocally {
                self.deviceCollectionView.reloadData()
            }
            self.updateEmptyState()
        }
        .store(in: &cancellables)

        // 2. 监听蓝牙连接结果，处理连接成功后的自动跳转
        bleViewModel.connectStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                guard self.navigationController?.topViewController === self else { return }

                switch state {
                case .connected:
                    if let sn = self.pendingConnectSerialNumber,
                       let device = self.savedDevices.first(where: { $0.serialNumber == sn }) {
                        self.pendingConnectSerialNumber = nil
                        self.showToast(L("连接成功"))
                        LocalDeviceManager.shared.updateLastConnectionTime(for: sn)
                        
                        let vc = DeviceControllerView(device: device)
                        self.navigationController?.pushViewController(vc, animated: true)
                    }
                case .failed(let error):
                    self.pendingConnectSerialNumber = nil
                    
                    // ✅ 修复：如果是静默自动重连失败，不弹窗打扰用户，只记录日志
                    if !self.bleViewModel.isAutoReconnecting {
                        self.showToast(L("连接失败: %@", error.localizedDescription))
                    } else {
                        AppLog.device.warning("自动重连失败: \(error.localizedDescription)")
                    }
                case .connecting:
                    break
                }
            }
            .store(in: &cancellables)
    }

    /// 更新空状态
    private func updateEmptyState() {
        let isEmpty = savedDevices.isEmpty
        nullDeviceImgView.isHidden = !isEmpty
        deviceCollectionView.isHidden = isEmpty
    }
    
    // MARK: - Actions

    /// 点击添加设备
    @objc private func addDeviceTapped() {
        navigationController?.pushViewController(DeviceSearchViewController(), animated: true)
    }
}

// MARK: - UICollectionViewDelegate & DataSource

extension HomeViewController: UICollectionViewDelegate, UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return savedDevices.count
    }

    /// 配置设备卡片 Cell
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HomeDeviceCardCell.reuseID, for: indexPath) as! HomeDeviceCardCell
        let device = savedDevices[indexPath.row]

        // 从扫描列表（及合并的已连接快照）中匹配该设备的实时电量数据
        let bleData = bleDevices.first {
            $0.id.caseInsensitiveCompare(device.serialNumber) == .orderedSame ||
            (!device.mac.isEmpty && $0.id.caseInsensitiveCompare(device.mac) == .orderedSame)
        }
        
        // 判断该设备是否处于已连接状态（以 BLE 是否连上为准）
        let isBleMatched = bleViewModel.currentlyConnectedUUID?.caseInsensitiveCompare(device.serialNumber) == .orderedSame ||
                           (!device.mac.isEmpty && bleViewModel.currentlyConnectedMac?.caseInsensitiveCompare(device.mac) == .orderedSame)

        // 配置卡片，仅传入两态（已连接/未连接）
        cell.configure(
            with: device,
            bleData: bleData,
            isConnected: isBleMatched
        )

        cell.onReportTapped = { [weak self] in
            self?.showToast(L("睡眠报告页面开发中"))
        }

        return cell
    }

    /// 点击设备卡片（未连接则发起连接，已连接则跳转详情）
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let device = savedDevices[indexPath.row]

        let isBleMatched = bleViewModel.currentlyConnectedUUID?.caseInsensitiveCompare(device.serialNumber) == .orderedSame ||
                           (!device.mac.isEmpty && bleViewModel.currentlyConnectedMac?.caseInsensitiveCompare(device.mac) == .orderedSame)

        if isBleMatched {
            // 已连接：直接进入详情
            let vc = DeviceControllerView(device: device)
            navigationController?.pushViewController(vc, animated: true)
        } else {
            // ✅ 修复：如果后台正在自动重连，拦截用户操作，避免重复发起
            if bleViewModel.isAutoReconnecting {
                showToast(L("设备正在重连中，请稍候…"))
                return
            }
            
            // 未连接：发起连接
            showToast(L("正在连接 %@…", device.name))
            pendingConnectSerialNumber = device.serialNumber
            bleViewModel.connectBySerialNumber(device.serialNumber)
        }
    }
}

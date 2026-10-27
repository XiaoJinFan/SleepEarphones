//
//  HomeViewModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/22.
//

import Foundation
import Combine
import LinkcosBluetooth

@MainActor
final class HomeViewModel: NSObject {

    // MARK: - Output

    /// 设备列表数据流（已排序）
    let devicesPublisher = CurrentValueSubject<[DeviceViewData], Never>([])

    /// 是否为空状态流（控制空视图 / 列表的显隐）
    let isEmptyPublisher = CurrentValueSubject<Bool, Never>(true)

    /// 手机蓝牙适配器状态流
    let bleStatePublisher = CurrentValueSubject<BleDeviceState, Never>(.none)

    // MARK: - Private

    /// SDK 设备缓存（key: uuidStr）
    private var rawDevices: [String: LCBleDevice] = [:]

    /// 当前全局连接状态
    private var currentConnectState: BleDeviceConnectState = .disConnect

    /// 当前手机蓝牙状态（同步值，供 UI 快速读取）
    private(set) var currentBleState: BleDeviceState = .none

    /// 停止扫描的候选方法名（按可能性排序）
    private static let stopScanSelectorCandidates: [String] = [
        "stopScanBleDevice",
        "stopScan",
        "stopBleScan",
        "stopScanning"
    ]

    // MARK: - Init

    override init() {
        super.init()
        setupBluetoothSDK()
    }

    // MARK: - Public API

    /// 开始扫描 BLE 设备
    func startScan() {
        AppLog.device.debug("开始扫描 BLE 设备")
        LCBleDeviceManager.sharedInstance.scanBleDevice()
    }

    /// 停止扫描
    func stopScan() {
        let manager = LCBleDeviceManager.sharedInstance

        for name in Self.stopScanSelectorCandidates {
            let selector = NSSelectorFromString(name)
            guard manager.responds(to: selector) else { continue }

            // 无参数方法的安全调用
            _ = manager.perform(selector)
            AppLog.device.debug("停止扫描（调用 \(name, privacy: .public)）")
            return
        }

        // 所有候选都未命中——SDK 可能未提供停止 API，或名称不在候选列表
        AppLog.device.debug("SDK 未提供停止扫描 API（或方法名不在候选列表），忽略")
    }

    /// 清空设备列表
    func clearDevices() {
        AppLog.device.debug("清空设备列表（原 \(self.rawDevices.count, privacy: .public) 个）")
        rawDevices.removeAll()
        refreshData()
    }

    // MARK: - Setup

    /// 注册 BLE 代理
    private func setupBluetoothSDK() {
        LCBleDeviceManager.sharedInstance.addHandleDelegate(self)
        AppLog.device.debug("已注册 BLE 代理")
    }

    // MARK: - Data Refresh

    /// 触发数据重新计算并派发
    private func refreshData() {
        let isConnected = (currentConnectState == .connected)

        let deviceList = rawDevices.values
            .map { DeviceViewData(device: $0, isConnected: isConnected) }
            .sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }

        devicesPublisher.send(deviceList)
        isEmptyPublisher.send(deviceList.isEmpty)
    }
}

// MARK: - LCBleHandleDelegate

extension HomeViewModel: LCBleHandleDelegate {

    /// 设备连接状态变化
    ///
    /// - Parameter state: 当前连接状态
    nonisolated func deviceContectStateChange(state: BleDeviceConnectState) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            AppLog.device.debug(
                "BLE 连接状态变化：\(state.rawValue, privacy: .public)"
            )
            self.currentConnectState = state
            self.refreshData()
        }
    }

    /// 手机蓝牙适配器状态变化
    ///
    /// - Parameter state: 当前蓝牙状态（`blePowerOn` / `blePowerOff` / `unauthorized` / `none`）
    nonisolated func deviceManagerBleStateChange(state: BleDeviceState) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            AppLog.device.debug(
                "手机蓝牙状态变化：\(state.rawValue, privacy: .public)"
            )
            self.currentBleState = state
            self.bleStatePublisher.send(state)
        }
    }

    /// 发现设备列表（SDK 一次性推送多台设备）
    ///
    /// - Parameter devices: 发现的设备列表
    nonisolated func discoverDeviceList(devices: [LCBleDevice]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            for device in devices {
                self.rawDevices[device.uuidStr] = device
            }
            self.refreshData()
        }
    }

    /// 发现新设备（SDK 单台推送）
    ///
    /// - Parameter device: 发现的设备
    nonisolated func discoverNewDevice(device: LCBleDevice) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.rawDevices[device.uuidStr] = device
            self.refreshData()
        }
    }

    /// 设备属性更新（电量 / 充电状态 / ANC 模式等）
    ///
    /// - Parameter property: 更新后的属性快照
    nonisolated func devicePropertyUpdate(property: LCBleDeviceProperty) {
        Task { @MainActor [weak self] in
            self?.refreshData()
        }
    }

    /// 发现重复设备
    ///
    /// - Parameter device: 重复发现的设备
    nonisolated func discoverDuplicateDevice(device: LCBleDevice) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            AppLog.device.debug(
                "重复发现设备（已忽略）：\(device.uuidStr, privacy: .private)"
            )
        }
    }

    /// 设备 ANC 自适应状态变化
    ///
    /// - Parameter state: `true` = 自适应开始，`false` = 自适应结束
    nonisolated func deviceAncAutoFitState(_ state: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            AppLog.device.debug(
                "ANC 自适应状态：\(state ? "开始" : "结束", privacy: .public)"
            )
            // 首页无操作——仅日志
        }
    }
}

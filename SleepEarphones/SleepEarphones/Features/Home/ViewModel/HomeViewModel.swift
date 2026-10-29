//
//  HomeViewModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/22.
//

import Foundation
import Combine
import AVFoundation
import LinkcosBluetooth

/// 首页设备管理 ViewModel
///
/// ## 职责
/// - 作为 BLE SDK 的事件接收方，集中管理扫描 / 连接 / 属性更新
/// - 向 UI 层暴露纯净的 `DeviceViewData` 列表
/// - 处理"历史设备点击 → 扫描 → 自动连接"的智能流程
///
/// ## 与 SDK 的交互
/// | 场景 | SDK API |
/// |---|---|
/// | 扫描 | `scanBleDevice()` |
/// | 连接 | `connectDevice(_:timeOut:)` |
/// | 断开 | `disConnectDevice()` |
/// | 蓝牙状态 | `$bleState`（Publisher） |
/// | 连接状态 | `$connectState`（Publisher） |
/// | 设备发现 | `LCBleHandleDelegate` |
/// | **实时电量** | `deviceProperty`（快照）+ `deviceControl.readBattery()`（主动拉取） |
///
@MainActor
final class HomeViewModel: NSObject {

    // MARK: - Singleton

    static let shared = HomeViewModel()

    // MARK: - Connect State

    enum ConnectState {
        case connecting
        case connected
        case failed(Error)
    }

    // MARK: - Constants

    /// pending 连接的超时时长（秒）
    private static let pendingConnectTimeout: TimeInterval = 30

    /// SDK 连接超时（秒）
    private static let sdkConnectTimeout: TimeInterval = 10.0

    /// 连接成功后延迟检查音频路由的时间（纳秒）
    ///
    /// - Note: 经典蓝牙音频切换通常耗时 0.5~2s。
    private static let audioRouteRecheckDelay: UInt64 = 1_500_000_000

    /// VM 兜底连接超时（秒）
    private static let vmConnectTimeoutFallback: TimeInterval = sdkConnectTimeout + 2

    // MARK: - Output

    let devicesPublisher = CurrentValueSubject<[DeviceViewData], Never>([])
    let isEmptyPublisher = CurrentValueSubject<Bool, Never>(true)
    let bleStatePublisher = CurrentValueSubject<BleDeviceState, Never>(.none)
    let connectStatePublisher = PassthroughSubject<ConnectState, Never>()

    @Published private(set) var currentlyConnectedMac: String?
    @Published private(set) var currentlyConnectedUUID: String?

    /// 当前音频是否已路由到耳机
    @Published private(set) var isAudioRouted: Bool = false

    // MARK: - Private — State

    private var rawDevices: [String: LCBleDevice] = [:]
    private var currentConnectState: BleDeviceConnectState = .disConnect
    private(set) var currentBleState: BleDeviceState = .none
    private var connectingDeviceID: String?
    private var lastPublishedDevices: [DeviceViewData] = []
    private var isScanningDesired = false
    private var pendingConnectUUID: String?
    private var pendingTimeoutTask: Task<Void, Never>?

    /// VM 兜底连接超时任务
    private var connectTimeoutTask: Task<Void, Never>?

    private var cancellables = Set<AnyCancellable>()
    private var audioRouteObserver: NSObjectProtocol?

    // MARK: - Init

    private override init() {
        super.init()
        setupBluetoothSDK()
        setupAudioRouteObserver()
        bindSDKPublishers()
    }

    // MARK: - Public API

    func startScan() {
        isScanningDesired = true
        if currentBleState == .blePowerOn {
            performScan()
        }
    }

    func stopScan() {
        isScanningDesired = false
        AppLog.device.debug("⏹ 停止扫描意图")
    }

    func clearDevices() {
        AppLog.device.debug("清空设备列表")
        rawDevices.removeAll()
        lastPublishedDevices.removeAll()
        clearPendingConnect()
        refreshData(force: true)
    }

    /// 通过序列号（后端 `serialNumber`，即 BLE UUID）连接设备
    ///
    /// - Parameter serialNumber: 目标设备标识（来自 `DeviceModel.serialNumber`）
    func connectBySerialNumber(_ serialNumber: String) {
        let trimmed = serialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            AppLog.device.error("连接失败：serialNumber 为空")
            connectStatePublisher.send(.failed(
                NSError(domain: "BLE", code: -3, userInfo: [
                    NSLocalizedDescriptionKey: "设备序列号为空，无法连接"
                ])
            ))
            return
        }

        // 1. 精确匹配（最常见，SN 与 UUID 完全一致时命中）
        if let device = rawDevices[trimmed] {
            let deviceID = DeviceViewData.stableID(for: device)
            AppLog.device.info(
                "✅ 缓存命中（精确）：sn=\(trimmed, privacy: .public) uuid=\(device.uuidStr, privacy: .public)"
            )
            connect(to: deviceID)
            return
        }

        // 2. 模糊匹配（大小写不敏感 + 多字段）
        if let matched = findCachedDevice(by: trimmed) {
            let deviceID = DeviceViewData.stableID(for: matched)
            AppLog.device.info(
                "✅ 缓存命中（模糊）：sn=\(trimmed, privacy: .public) uuid=\(matched.uuidStr, privacy: .public)"
            )
            connect(to: deviceID)
            return
        }

        // 3. 未命中 → 挂起 + 扫描
        AppLog.device.warning(
            "⏳ 目标设备未在缓存中，开始扫描并等待：sn=\(trimmed, privacy: .public)"
        )
        connectStatePublisher.send(.connecting)
        clearPendingConnect()
        pendingConnectUUID = trimmed
        startScan()
        schedulePendingTimeout()
    }

    /// 连接指定设备（缓存 key）
    ///
    /// - Parameter deviceID: `rawDevices` 的 key（即 `DeviceViewData.stableID(for:)`）
    func connect(to deviceID: String) {
        // 缓存未命中：先尝试模糊查找一次（防御）
        guard let device = rawDevices[deviceID] else {
            if let matched = findCachedDevice(by: deviceID) {
                connect(to: DeviceViewData.stableID(for: matched))
                return
            }
            AppLog.device.error(
                "连接失败：设备不在缓存中 id=\(deviceID, privacy: .public)"
            )
            connectStatePublisher.send(.failed(
                NSError(domain: "BLE", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: "设备已离开附近，请重新扫描"
                ])
            ))
            return
        }

        // 已有连接进行中
        if let current = connectingDeviceID {
            if current == deviceID {
                // 同一设备重复点击 → 静默忽略
                AppLog.device.debug("已在该设备的连接中，忽略重复请求")
            } else {
                // 不同设备 → 明确提示用户
                AppLog.device.debug(
                    "已有其他设备连接进行中（\(current, privacy: .public)），拒绝本次请求"
                )
                connectStatePublisher.send(.failed(
                    NSError(domain: "BLE", code: -4, userInfo: [
                        NSLocalizedDescriptionKey: "请等待当前设备连接完成"
                    ])
                ))
            }
            return
        }

        // 正常发起连接
        connectStatePublisher.send(.connecting)
        connectingDeviceID = deviceID

        AppLog.device.warning(
            "🔗 尝试连接：name=\(device.name, privacy: .public) uuid=\(device.uuidStr, privacy: .public) mac=\(device.leftMacString, privacy: .public)"
        )

        // VM 兜底超时：防止 SDK 静默失败导致状态卡死
        scheduleConnectTimeoutFallback(deviceID: deviceID)

        LCBleDeviceManager.sharedInstance.connectDevice(
            device,
            timeOut: Self.sdkConnectTimeout
        )
    }

    // MARK: - Setup

    private func setupBluetoothSDK() {
        LCBleDeviceManager.sharedInstance.addHandleDelegate(self)
    }

    private func performScan() {
        AppLog.device.warning("▶️ 调用 SDK 开始扫描 BLE 设备")
        LCBleDeviceManager.sharedInstance.scanBleDevice()
    }

    /// 监听音频路由变化
    private func setupAudioRouteObserver() {
        audioRouteObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                AppLog.device.debug("检测到音频路由变化，重新检查路由状态")
                self?.updateAudioRouted()
            }
        }
    }

    // MARK: - SDK Publisher Bindings

    private func bindSDKPublishers() {
        let manager = LCBleDeviceManager.sharedInstance

        manager.$bleState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.handleBleStateChange(state)
                }
            }
            .store(in: &cancellables)

        manager.$connectState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.handleConnectStateChange(state)
                }
            }
            .store(in: &cancellables)
    }

    /// 处理蓝牙适配器状态变化
    private func handleBleStateChange(_ state: BleDeviceState) {
        currentBleState = state
        bleStatePublisher.send(state)

        if state == .blePowerOn, isScanningDesired {
            performScan()
        }
    }

    /// 处理连接状态变化
    private func handleConnectStateChange(_ state: BleDeviceConnectState) {
        currentConnectState = state

        switch state {
        case .connected:
            connectStatePublisher.send(.connected)

            if let device = LCBleDeviceManager.sharedInstance.connectDevice {
                currentlyConnectedMac = device.leftMacString
                currentlyConnectedUUID = device.uuidStr
                AppLog.device.debug(
                    "已连接：name=\(device.name, privacy: .public) uuid=\(device.uuidStr, privacy: .public) mac=\(device.leftMacString, privacy: .public)"
                )
            } else {
                AppLog.device.warning("连接成功但 SDK connectDevice 为 nil")
            }

            // 清理连接状态（含 VM 兜底超时任务）
            connectingDeviceID = nil
            connectTimeoutTask?.cancel()
            connectTimeoutTask = nil
            clearPendingConnect()

            // ✅ 主动拉取电量
            requestBatteryRead()

            // ✅ 立即检查音频路由 + 延迟兜底（等经典蓝牙音频切换）
            updateAudioRouted()
            scheduleAudioRouteRecheck()

        case .disConnect:
            currentlyConnectedMac = nil
            currentlyConnectedUUID = nil
            connectingDeviceID = nil
            connectTimeoutTask?.cancel()
            connectTimeoutTask = nil
            isAudioRouted = false

        case .connectTimeout:
            connectingDeviceID = nil
            connectTimeoutTask?.cancel()
            connectTimeoutTask = nil
            connectStatePublisher.send(.failed(
                NSError(domain: "BLE", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "连接超时"
                ])
            ))

        case .connecting:
            // `connect(to:)` 已发过 `.connecting`——不重复发
            break

        @unknown default:
            // SDK 未来新增的 case——记录日志但不崩溃
            AppLog.device.warning(
                "收到未知连接状态：rawValue=\(state.rawValue)"
            )
        }

        refreshData()
    }

    /// 主动拉取电量
    private func requestBatteryRead() {
        AppLog.device.debug("主动拉取设备电量")
        LCBleDeviceManager.sharedInstance.deviceControl.readBattery()
    }

    /// 延迟重查音频路由
    private func scheduleAudioRouteRecheck() {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.audioRouteRecheckDelay)
            guard !Task.isCancelled else { return }
            self?.updateAudioRouted()
        }
    }

    /// 更新音频路由状态（仅在值变化时发布）
    private func updateAudioRouted() {
        let routed = LCBleDeviceManager.sharedInstance.isHeadsetPluggedIn()
        if isAudioRouted != routed {
            isAudioRouted = routed
            AppLog.device.debug("音频路由状态更新：isAudioRouted=\(routed)")
        }
    }

    // MARK: - Connect Timeout Fallback

    /// 调度 VM 兜底连接超时
    ///
    /// - Parameter deviceID: 正在连接的设备 ID
    private func scheduleConnectTimeoutFallback(deviceID: String) {
        connectTimeoutTask?.cancel()
        connectTimeoutTask = Task { [weak self] in
            let nanos = UInt64(Self.vmConnectTimeoutFallback * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            guard let self, self.connectingDeviceID == deviceID else { return }

            AppLog.device.warning(
                "⏱ VM 兜底超时：\(Self.vmConnectTimeoutFallback)s 内未收到 SDK 连接状态回调，强制清理"
            )
            self.connectingDeviceID = nil
            self.connectTimeoutTask = nil
            self.connectStatePublisher.send(.failed(
                NSError(domain: "BLE", code: -5, userInfo: [
                    NSLocalizedDescriptionKey: "连接超时，请重试"
                ])
            ))
        }
    }

    // MARK: - Pending Connect

    private func schedulePendingTimeout() {
        pendingTimeoutTask?.cancel()
        pendingTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.pendingConnectTimeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard let self, self.pendingConnectUUID != nil else { return }

            AppLog.device.warning(
                "pending 连接超时（\(Self.pendingConnectTimeout)s），清理挂起状态"
            )
            self.connectStatePublisher.send(.failed(
                NSError(domain: "BLE", code: -7, userInfo: [
                    NSLocalizedDescriptionKey: "未找到目标设备，请确认设备处于配对模式"
                ])
            ))
            self.clearPendingConnect()
        }
    }

    private func clearPendingConnect() {
        pendingConnectUUID = nil
        pendingTimeoutTask?.cancel()
        pendingTimeoutTask = nil
    }

    /// 检查新发现的设备是否命中 pending 目标
    ///
    /// - Parameter device: 新发现的设备
    private func checkPendingConnect(for device: LCBleDevice) {
        guard let pending = pendingConnectUUID else { return }

        let target = pending.uppercased()
        let isMatch = device.uuidStr.uppercased() == target
            || device.leftMacString.uppercased() == target
            || device.name.uppercased() == target
        guard isMatch else { return }

        AppLog.device.warning(
            "✅ 发现待连接设备，自动发起连接：name=\(device.name, privacy: .public) uuid=\(device.uuidStr, privacy: .public)"
        )
        clearPendingConnect()
        connect(to: DeviceViewData.stableID(for: device))
    }

    /// 在 `rawDevices` 中查找匹配的设备（大小写不敏感 + 多字段）
    ///
    /// - Parameter identifier: 目标标识
    /// - Returns: 命中的设备；未命中返回 nil
    private func findCachedDevice(by identifier: String) -> LCBleDevice? {
        let target = identifier.uppercased()
        return rawDevices.values.first { device in
            device.uuidStr.uppercased() == target
                || device.leftMacString.uppercased() == target
                || device.name.uppercased() == target
        }
    }

    // MARK: - Data Refresh

    /// 刷新设备列表
    private func refreshData(force: Bool = false) {
        let isConnected = (currentConnectState == .connected)
        let manager = LCBleDeviceManager.sharedInstance
        let connectedUUID = manager.connectDevice?.uuidStr
        let deviceProperty = manager.deviceProperty

        let deviceList = rawDevices.values
            .map { device -> DeviceViewData in
                let property: LCBleDeviceProperty? = (device.uuidStr == connectedUUID)
                    ? deviceProperty
                    : nil
                return DeviceViewData(device: device, isConnected: isConnected, property: property)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        guard force || deviceList != lastPublishedDevices else { return }
        lastPublishedDevices = deviceList

        devicesPublisher.send(deviceList)
        isEmptyPublisher.send(deviceList.isEmpty)
    }
}

// MARK: - LCBleHandleDelegate

extension HomeViewModel: LCBleHandleDelegate {

    nonisolated func discoverDeviceList(devices: [LCBleDevice]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            for device in devices {
                // 🔍 详细日志：便于排查"设备是否被 SDK 回调"
//                AppLog.device.info(
//                    "📡 发现设备（列表）：name=\(device.name, privacy: .public) uuid=\(device.uuidStr, privacy: .public) mac=\(device.leftMacString, privacy: .public) vendorId=\(device.vendorId) flagId=\(device.flagId)"
//                )
                self.rawDevices[DeviceViewData.stableID(for: device)] = device
                self.checkPendingConnect(for: device)
            }
            self.refreshData()
        }
    }

    nonisolated func discoverNewDevice(device: LCBleDevice) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            AppLog.device.info(
                "📡 发现设备（新）：name=\(device.name, privacy: .public) uuid=\(device.uuidStr, privacy: .public) mac=\(device.leftMacString, privacy: .public) vendorId=\(device.vendorId) flagId=\(device.flagId)"
            )
            self.rawDevices[DeviceViewData.stableID(for: device)] = device
            self.checkPendingConnect(for: device)
            self.refreshData()
        }
    }

    nonisolated func discoverDuplicateDevice(device: LCBleDevice) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let key = DeviceViewData.stableID(for: device)
            if self.rawDevices[key] == nil {
                AppLog.device.info(
                    "📡 发现设备（重复-首次加入）：name=\(device.name, privacy: .public) uuid=\(device.uuidStr, privacy: .public)"
                )
                self.rawDevices[key] = device
                self.checkPendingConnect(for: device)
                self.refreshData()
            }
        }
    }

    nonisolated func devicePropertyUpdate(property: LCBleDeviceProperty) {
        Task { @MainActor [weak self] in
            self?.refreshData()
        }
    }

    nonisolated func deviceAncAutoFitState(_ state: Bool) {
        // 当前未使用，保留空实现
    }
}

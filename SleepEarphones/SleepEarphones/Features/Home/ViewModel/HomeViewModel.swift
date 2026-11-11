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

@MainActor
final class HomeViewModel: NSObject {

    // MARK: - Singleton

    /// 共享实例
    static let shared = HomeViewModel()

    // MARK: - Connect State

    /// 连接状态（供 UI 订阅）
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
    private static let audioRouteRecheckDelay: UInt64 = 1_500_000_000

    /// VM 兜底连接超时（秒）
    private static let vmConnectTimeoutFallback: TimeInterval = sdkConnectTimeout + 2
    
    /// 单个设备自动重连的最大尝试次数
    private static let maxReconnectAttempts = 3
    
    /// 自动重连等待延迟（秒）
    private static let reconnectDelaySeconds: UInt64 = 2

    // MARK: - Output

    /// 设备列表（供 `DeviceSearchViewController` 订阅）
    let devicesPublisher = CurrentValueSubject<[DeviceViewData], Never>([])

    /// 是否为空
    let isEmptyPublisher = CurrentValueSubject<Bool, Never>(true)

    /// 蓝牙适配器状态
    let bleStatePublisher = CurrentValueSubject<BleDeviceState, Never>(.none)

    /// 连接状态（供 UI 展示"连接中 / 连接成功 / 连接失败"）
    let connectStatePublisher = PassthroughSubject<ConnectState, Never>()

    /// 当前已连接设备的 MAC（左耳 MAC）
    @Published private(set) var currentlyConnectedMac: String?

    /// 当前已连接设备的 UUID
    @Published private(set) var currentlyConnectedUUID: String?

    /// 当前音频是否已路由到耳机
    @Published private(set) var isAudioRouted: Bool = false
    
    /// 当前连接设备的数据信息
    @Published private(set) var connectedDeviceData: DeviceViewData?
    
    /// 是否正在自动重连中（供 UI 展示“重新连接中…”状态）
    @Published private(set) var isAutoReconnecting: Bool = false

    // MARK: - Private — State

    /// 原始设备缓存（key = `DeviceViewData.stableID`）
    private var rawDevices: [String: LCBleDevice] = [:]

    /// 当前 BLE 连接状态（SDK 原始枚举）
    private var currentConnectState: BleDeviceConnectState = .disConnect

    /// 当前蓝牙适配器状态
    private(set) var currentBleState: BleDeviceState = .none

    /// 正在连接的设备 ID（防止并发连接）
    private var connectingDeviceID: String?

    /// 上次发布给 UI 的设备列表（用于 diff，避免无变化时重复发布）
    private var lastPublishedDevices: [DeviceViewData] = []

    /// 是否希望扫描（由 `startScan` / `stopScan` 控制）
    private var isScanningDesired = false

    /// pending 连接的目标标识（UUID / MAC / name 之一）
    private var pendingConnectUUID: String?

    /// pending 连接的超时任务
    private var pendingTimeoutTask: Task<Void, Never>?

    /// VM 兜底连接超时任务
    private var connectTimeoutTask: Task<Void, Never>?

    /// 音频路由延迟重查任务（连接成功 1.5s 后执行）
    private var audioRouteRecheckTask: Task<Void, Never>?

    /// Combine 订阅容器
    private var cancellables = Set<AnyCancellable>()

    /// 音频路由变化通知观察者
    private var audioRouteObserver: NSObjectProtocol?
    
    // --- 自动重连相关状态 ---
    
    /// 自动重连队列（存放待重连的 SerialNumber，按最近连接时间排序）
    private var reconnectQueue: [String] = []
    
    /// 是否被用户手动断开（如果是，则不自动重连）
    private var isManuallyDisconnected = false
    
    /// 当前重连设备已经尝试的次数
    private var currentReconnectAttempts = 0
    
    /// 重连任务句柄
    private var reconnectTask: Task<Void, Never>?

    // MARK: - Init

    private override init() {
        super.init()
        setupBluetoothSDK()
        setupAudioRouteObserver()
        bindSDKPublishers()
        
        // App 启动时尝试自动重连
        attemptStartupReconnect()
    }

    // MARK: - Public API
    
    /// 主动断开当前蓝牙连接（用户手动操作）
    func disconnect() {
        AppLog.device.info("用户主动断开当前设备连接")
        // 标记为手动断开，阻止自动重连触发
        isManuallyDisconnected = true
        clearReconnectQueue()
        LCBleDeviceManager.sharedInstance.disConnectDevice()
    }

    /// 开始扫描
    func startScan() {
        isScanningDesired = true
        if currentBleState == .blePowerOn { performScan() }
    }

    /// 停止扫描
    func stopScan() {
        isScanningDesired = false
    }

    /// 清空设备列表
    func clearDevices() {
        rawDevices.removeAll()
        lastPublishedDevices.removeAll()
        clearPendingConnect()
        refreshData(force: true)
    }

    /// 发起连接（用户手动点击触发）
    ///
    /// - Parameter serialNumber: 目标设备标识
    func connectBySerialNumber(_ serialNumber: String) {
        // ✅ 用户手动点击连接，说明意图明确，直接清空重连队列，重置状态
        isManuallyDisconnected = false
        clearReconnectQueue()
        
        let trimmed = serialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            connectStatePublisher.send(.failed(NSError(domain: "BLE", code: -3, userInfo: [NSLocalizedDescriptionKey: L("设备序列号为空，无法连接")])))
            return
        }

        if currentConnectState == .connected, let uuid = currentlyConnectedUUID, uuid.caseInsensitiveCompare(trimmed) == .orderedSame {
            connectStatePublisher.send(.connected)
            return
        }

        if let device = rawDevices[trimmed] {
            connect(to: DeviceViewData.stableID(for: device))
            return
        }

        if let matched = findCachedDevice(by: trimmed) {
            connect(to: DeviceViewData.stableID(for: matched))
            return
        }

        connectStatePublisher.send(.connecting)
        clearPendingConnect()
        pendingConnectUUID = trimmed
        startScan()
        schedulePendingTimeout()
    }

    /// 连接指定设备（缓存 key）
    ///
    /// - Parameter deviceID: `rawDevices` 的 key
    func connect(to deviceID: String) {
        guard let device = rawDevices[deviceID] else {
            if let matched = findCachedDevice(by: deviceID) {
                connect(to: DeviceViewData.stableID(for: matched))
                return
            }
            connectStatePublisher.send(.failed(NSError(domain: "BLE", code: -2, userInfo: [NSLocalizedDescriptionKey: L("设备已离开附近，请重新扫描")])))
            return
        }

        if currentConnectState == .connected, let uuid = currentlyConnectedUUID, uuid.caseInsensitiveCompare(device.uuidStr) == .orderedSame {
            connectStatePublisher.send(.connected)
            return
        }

        if let current = connectingDeviceID {
            if current != deviceID {
                connectStatePublisher.send(.failed(NSError(domain: "BLE", code: -4, userInfo: [NSLocalizedDescriptionKey: L("请等待当前设备连接完成")])))
            }
            return
        }

        // 非自动重连时，才对外发布 .connecting 状态
        if !isAutoReconnecting {
            connectStatePublisher.send(.connecting)
        }
        
        connectingDeviceID = deviceID
        scheduleConnectTimeoutFallback(deviceID: deviceID)
        LCBleDeviceManager.sharedInstance.connectDevice(device, timeOut: Self.sdkConnectTimeout)
    }

    // MARK: - Setup & Bindings

    /// 注册 SDK delegate
    private func setupBluetoothSDK() {
        LCBleDeviceManager.sharedInstance.addHandleDelegate(self)
    }

    /// 调用 SDK 开始扫描
    private func performScan() {
        guard isScanningDesired else { return }
        LCBleDeviceManager.sharedInstance.scanBleDevice()
    }

    /// 监听音频路由变化
    private func setupAudioRouteObserver() {
        audioRouteObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance(), queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateAudioRouted() }
        }
    }

    // MARK: - SDK Publisher Bindings

    /// 订阅 SDK 的 Combine Publisher
    private func bindSDKPublishers() {
        let manager = LCBleDeviceManager.sharedInstance

        manager.$bleState.receive(on: DispatchQueue.main).sink { [weak self] state in
            MainActor.assumeIsolated { self?.handleBleStateChange(state) }
        }.store(in: &cancellables)

        manager.$connectState.receive(on: DispatchQueue.main).sink { [weak self] state in
            MainActor.assumeIsolated { self?.handleConnectStateChange(state) }
        }.store(in: &cancellables)
    }

    /// 处理蓝牙适配器状态变化
    private func handleBleStateChange(_ state: BleDeviceState) {
        currentBleState = state
        bleStatePublisher.send(state)
        
        if state == .blePowerOn {
            if isScanningDesired { performScan() }
            // 蓝牙刚开启，如果当前未连接，触发自动重连
            if currentConnectState == .disConnect {
                attemptStartupReconnect()
            }
        }
    }

    /// 处理连接状态变化
    private func handleConnectStateChange(_ state: BleDeviceConnectState) {
        currentConnectState = state

        switch state {
        case .connected:
            // ✅ 连接成功：清空队列，重置所有重连状态
            isAutoReconnecting = false
            isManuallyDisconnected = false
            clearReconnectQueue()
            
            connectStatePublisher.send(.connected)

            if let device = LCBleDeviceManager.sharedInstance.connectDevice {
                currentlyConnectedMac = device.leftMacString
                currentlyConnectedUUID = device.uuidStr
                
                let property = LCBleDeviceManager.sharedInstance.deviceProperty
                connectedDeviceData = DeviceViewData(device: device, isConnected: true, property: property)
            }

            connectingDeviceID = nil
            connectTimeoutTask?.cancel()
            connectTimeoutTask = nil
            clearPendingConnect()

            LCBleDeviceManager.sharedInstance.deviceControl.readBattery()
            updateAudioRouted()
            scheduleAudioRouteRecheck()

        case .disConnect:
            let wasConnected = (currentlyConnectedUUID != nil)
            
            currentlyConnectedMac = nil
            currentlyConnectedUUID = nil
            connectedDeviceData = nil
            connectingDeviceID = nil
            connectTimeoutTask?.cancel()
            connectTimeoutTask = nil
            isAudioRouted = false

            // 如果是从已连接状态意外掉线，且不是用户手动断开，则触发重连
            if wasConnected && !isManuallyDisconnected {
                attemptAutoReconnect()
            }

        case .connectTimeout:
            connectingDeviceID = nil
            connectTimeoutTask?.cancel()
            connectTimeoutTask = nil
            connectedDeviceData = nil
            
            if !isAutoReconnecting {
                connectStatePublisher.send(.failed(NSError(domain: "BLE", code: -1, userInfo: [NSLocalizedDescriptionKey: L("连接超时")])))
            }
            
            // 超时也触发重连逻辑
            if !isManuallyDisconnected {
                attemptAutoReconnect()
            }

        default:
            break
        }

        refreshData()
    }
    
    // MARK: - Auto Reconnect Logic

    /// 启动时尝试重连上次使用的多个设备
    private func attemptStartupReconnect() {
        guard currentBleState == .blePowerOn, currentConnectState == .disConnect else { return }
        
        // 取出所有本地设备，按 lastConnectionTime 降序排列
        let sortedDevices = LocalDeviceManager.shared.devices
            .filter { !$0.lastConnectionTime.isEmpty }
            .sorted { $0.lastConnectionTime > $1.lastConnectionTime }
            
        if sortedDevices.isEmpty { return }
        
        AppLog.device.info("启动自动重连，建立重连队列，共 \(sortedDevices.count) 台设备")
        isAutoReconnecting = true
        
        // 填充重连队列
        reconnectQueue = sortedDevices.map { $0.serialNumber }
        currentReconnectAttempts = 0
        
        startNextReconnect()
    }

    /// 意外断开后的重连尝试
    private func attemptAutoReconnect() {
        // 如果队列为空，说明没有指定目标，需要重新建立队列
        if reconnectQueue.isEmpty {
            AppLog.device.info("设备意外断开，触发自动重连机制")
            isAutoReconnecting = true
            
            // 优先把刚刚断开的设备放回队列最前面，其余按时间排序
            let sortedDevices = LocalDeviceManager.shared.devices
                .filter { !$0.lastConnectionTime.isEmpty }
                .sorted { $0.lastConnectionTime > $1.lastConnectionTime }
            
            reconnectQueue = sortedDevices.map { $0.serialNumber }
        }
        
        startNextReconnect()
    }

    /// 执行队列中的下一个重连任务
    private func startNextReconnect() {
        guard !isManuallyDisconnected else { return }
        
        // 1. 队列空了，代表全部设备重连失败
        guard !reconnectQueue.isEmpty else {
            AppLog.device.warning("自动重连队列已空，停止重连")
            isAutoReconnecting = false
            return
        }
        
        // 2. 取出队首设备的 serialNumber
        let targetSerial = reconnectQueue[0]
        
        // 3. 检查当前重试次数
        if currentReconnectAttempts >= Self.maxReconnectAttempts {
            AppLog.device.warning("设备 \(targetSerial) 重连达到最大次数，尝试下一个设备")
            reconnectQueue.removeFirst() // 剔除当前设备
            currentReconnectAttempts = 0 // 重置计数器
            startNextReconnect() // 尝试下一个
            return
        }
        
        currentReconnectAttempts += 1
        AppLog.device.info("尝试自动重连第 \(self.currentReconnectAttempts) 次，目标：\(targetSerial)")
        
        // 4. 延迟后发起连接
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.reconnectDelaySeconds * 1_000_000_000)
            guard !Task.isCancelled, let self = self, !self.isManuallyDisconnected else { return }
            
            // 调用连接逻辑（这里会复用原有的 connectBySerialNumber，但注意要把 isManuallyDisconnected 临时维护好）
            self.internalReconnectConnect(serialNumber: targetSerial)
        }
    }

    /// 内部专用的重连连接方法，不打断队列状态
    private func internalReconnectConnect(serialNumber: String) {
        let trimmed = serialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            reconnectQueue.removeFirst()
            startNextReconnect()
            return
        }

        // 如果设备在缓存里，直接连
        if let device = rawDevices[trimmed] {
            self.connectForReconnect(to: DeviceViewData.stableID(for: device))
            return
        }

        if let matched = findCachedDevice(by: trimmed) {
            self.connectForReconnect(to: DeviceViewData.stableID(for: matched))
            return
        }
        
        // 如果不在缓存，针对重连逻辑，说明设备不在身边，直接判定失败，试下一个
        AppLog.device.warning("设备 \(trimmed) 不在扫描缓存中，跳过")
        reconnectQueue.removeFirst()
        currentReconnectAttempts = 0
        startNextReconnect()
    }
    
    /// 专供重连使用的底层连接方法（不触发 .connecting 对外发布）
    private func connectForReconnect(to deviceID: String) {
        guard let device = rawDevices[deviceID] else { return }
        
        connectingDeviceID = deviceID
        scheduleConnectTimeoutFallback(deviceID: deviceID)
        LCBleDeviceManager.sharedInstance.connectDevice(device, timeOut: Self.sdkConnectTimeout)
    }

    /// 清空重连队列
    private func clearReconnectQueue() {
        reconnectQueue.removeAll()
        currentReconnectAttempts = 0
        isAutoReconnecting = false
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    // MARK: - Helpers

    private func scheduleAudioRouteRecheck() {
        audioRouteRecheckTask?.cancel()
        audioRouteRecheckTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.audioRouteRecheckDelay)
            guard !Task.isCancelled else { return }
            self?.updateAudioRouted()
        }
    }

    /// 更新音频路由状态（仅在值变化时发布）
    private func updateAudioRouted() {
        let routed = LCBleDeviceManager.sharedInstance.isHeadsetPluggedIn()
        if isAudioRouted != routed { isAudioRouted = routed }
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
            guard !Task.isCancelled, let self, self.connectingDeviceID == deviceID else { return }

            self.connectingDeviceID = nil
            self.connectTimeoutTask = nil
            self.connectedDeviceData = nil
            self.connectStatePublisher.send(.failed(NSError(domain: "BLE", code: -5, userInfo: [NSLocalizedDescriptionKey: L("连接超时，请重试")])))
        }
    }

    /// 调度 pending 连接的超时
    private func schedulePendingTimeout() {
        pendingTimeoutTask?.cancel()
        pendingTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.pendingConnectTimeout * 1_000_000_000))
            guard !Task.isCancelled, let self, self.pendingConnectUUID != nil else { return }

            self.connectStatePublisher.send(.failed(NSError(domain: "BLE", code: -7, userInfo: [NSLocalizedDescriptionKey: L("未找到目标设备，请确认设备处于配对模式")])))
            self.clearPendingConnect()
        }
    }

    /// 清空 pending 状态
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
        let isMatch = device.uuidStr.uppercased() == target || device.leftMacString.uppercased() == target || device.name.uppercased() == target
        guard isMatch else { return }

        clearPendingConnect()
        connect(to: DeviceViewData.stableID(for: device))
    }

    
    private func findCachedDevice(by identifier: String) -> LCBleDevice? {
        let target = identifier.uppercased()
        return rawDevices.values.first { device in
            device.uuidStr.uppercased() == target || device.leftMacString.uppercased() == target || device.name.uppercased() == target
        }
    }

    @discardableResult
    private func upsertDevice(_ device: LCBleDevice) -> Bool {
        let key = DeviceViewData.stableID(for: device)
        guard rawDevices[key] == nil else { return false }
        rawDevices[key] = device
        return true
    }

    private func refreshData(force: Bool = false) {
        let manager = LCBleDeviceManager.sharedInstance
        let connectedUUID = manager.connectDevice?.uuidStr
        let deviceProperty = manager.deviceProperty

        let deviceList = rawDevices.values.map { device -> DeviceViewData in
            let isThisDeviceConnected = (device.uuidStr == connectedUUID)
            let property: LCBleDeviceProperty? = isThisDeviceConnected ? deviceProperty : nil
            
            return DeviceViewData(
                device: device,
                isConnected: isThisDeviceConnected,
                property: property
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

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
            var hasNewDevice = false
            for device in devices {
                if self.upsertDevice(device) { hasNewDevice = true }
                self.checkPendingConnect(for: device)
            }
            if hasNewDevice { self.refreshData() }
        }
    }

    nonisolated func discoverNewDevice(device: LCBleDevice) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.upsertDevice(device) { self.refreshData() }
            self.checkPendingConnect(for: device)
        }
    }

    nonisolated func discoverDuplicateDevice(device: LCBleDevice) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.upsertDevice(device) {
                self.refreshData()
                self.checkPendingConnect(for: device)
            }
        }
    }

    nonisolated func devicePropertyUpdate(property: LCBleDeviceProperty) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            if let connectedDevice = LCBleDeviceManager.sharedInstance.connectDevice {
                self.connectedDeviceData = DeviceViewData(device: connectedDevice, isConnected: true, property: property)
            }
            self.refreshData()
        }
    }

    nonisolated func deviceAncAutoFitState(_ state: Bool) {}
}

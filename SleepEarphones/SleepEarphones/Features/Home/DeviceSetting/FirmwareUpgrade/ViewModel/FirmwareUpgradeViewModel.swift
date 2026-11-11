//
//  FirmwareUpgradeViewModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/11/7.
//

import Foundation
import Combine
import LinkcosBluetooth

enum FirmwareUpgradeState: Equatable {
    case idle
    case downloading(progress: Float)
    case upgrading(progress: Float)
    case completed
    case failed(String)
    
    static func == (lhs: FirmwareUpgradeState, rhs: FirmwareUpgradeState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.completed, .completed): return true
        case let (.downloading(l), .downloading(r)): return l == r
        case let (.upgrading(l), .upgrading(r)): return l == r
        case let (.failed(l), .failed(r)): return l == r
        default: return false
        }
    }
}

@MainActor
final class FirmwareUpgradeViewModel {
    
    // MARK: - Output
    @Published private(set) var state: FirmwareUpgradeState = .idle
    
    // 版本号目前 DeviceModel 里没有，暂时写死（后续可接入接口）
    @Published private(set) var currentVersion: String = "v2.10.3"
    @Published private(set) var newVersion: String = "v2.10.4"
    @Published private(set) var packageSize: String = "33M"
    
    /// 实时耳机电量（0-100）
    @Published private(set) var batteryLevel: Int = 0
    /// 是否已连接蓝牙
    @Published private(set) var isDeviceConnected: Bool = false
    
    private let minimumBatteryLevel = 30
    private var upgradeTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    init() {
        bindDeviceState()
    }
    
    // MARK: - Bind BLE State
    private func bindDeviceState() {
        let homeVM = HomeViewModel.shared
        
        // 监听连接状态
        homeVM.$currentlyConnectedUUID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] uuid in
                self?.isDeviceConnected = (uuid != nil)
            }
            .store(in: &cancellables)
            
        // 监听设备实时电量（这里取左耳电量）
        LCBleDeviceManager.sharedInstance.deviceProperty.$leftBattery
            .receive(on: DispatchQueue.main)
            .sink { [weak self] battery in
                self?.batteryLevel = max(0, battery)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    func checkCanUpgrade() -> String? {
        if !isDeviceConnected { return L("设备未连接，请先连接蓝牙耳机") }
        if batteryLevel < minimumBatteryLevel { return L("耳机电量过低（\(batteryLevel)%），请充电后再试") }
        return nil
    }
    
    func startUpgrade() {
        guard case .idle = state else { return }
        if let errorMsg = checkCanUpgrade() {
            state = .failed(errorMsg)
            return
        }
        
        upgradeTask?.cancel()
        upgradeTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.simulateDownload()
                if !self.isDeviceConnected {
                    throw NSError(domain: "OTA", code: -1, userInfo: [NSLocalizedDescriptionKey: L("设备已断开连接，升级失败")])
                }
                try await self.simulateOTATransfer()
                self.state = .completed
            } catch is CancellationError {
            } catch {
                self.state = .failed(error.localizedDescription)
            }
        }
    }
    
    func cancelUpgrade() {
        upgradeTask?.cancel()
        upgradeTask = nil
    }
    
    // MARK: - Simulate Logic
    private func simulateDownload() async throws {
        let totalSteps = 20
        for i in 1...totalSteps {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 100_000_000)
            self.state = .downloading(progress: Float(i) / Float(totalSteps))
        }
    }
    
    private func simulateOTATransfer() async throws {
        let totalSteps = 50
        for i in 1...totalSteps {
            try Task.checkCancellation()
            if !self.isDeviceConnected {
                throw NSError(domain: "OTA", code: -2, userInfo: [NSLocalizedDescriptionKey: L("升级过程中蓝牙断开，请保持设备在连接范围内")])
            }
            try await Task.sleep(nanoseconds: 100_000_000)
            self.state = .upgrading(progress: Float(i) / Float(totalSteps))
        }
    }
}

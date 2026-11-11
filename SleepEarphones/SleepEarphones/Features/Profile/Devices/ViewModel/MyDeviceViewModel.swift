//
//  MyDeviceViewModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/11.
//

import Foundation
import Combine


@MainActor
final class MyDeviceViewModel {

    // MARK: - Output

    /// 设备列表
    @Published private(set) var devices: [DeviceModel] = []

    /// 设备总数
    @Published private(set) var totalCount: Int = 0

    /// 空数据状态
    var isEmpty: Bool {
        devices.isEmpty
    }

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        bindLocalDatabase()
    }

    // MARK: - Binding

    /// 绑定本地数据库的数据流
    private func bindLocalDatabase() {
        LocalDeviceManager.shared.devicesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newDevices in
                guard let self = self else { return }
                self.devices = newDevices
                self.totalCount = newDevices.count
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    /// 删除设备
    /// - Parameter index: 设备在列表中的索引
    func deleteDevice(at index: Int) {
        guard index < devices.count else { return }
        let device = devices[index]
        // 直接操作本地数据库
        LocalDeviceManager.shared.removeDevice(bySerialNumber: device.serialNumber)
        AppLog.device.debug("从本地数据库删除设备: \(device.name)")
    }
}

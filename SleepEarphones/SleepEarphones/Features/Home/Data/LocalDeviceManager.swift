import Foundation
import Combine

/// 本地设备数据管理器（完全替代后台接口，负责持久化）
@MainActor
final class LocalDeviceManager {
    
    /// 单例
    static let shared = LocalDeviceManager()
    
    private let userDefaults = UserDefaults.standard
    private let devicesKey = "com.sleepearphones.savedDevices"
    
    /// 使用 Combine 发布设备列表变化
    let devicesSubject: CurrentValueSubject<[DeviceModel], Never>
    
    /// 发布者，供 UI 订阅
    var devicesPublisher: AnyPublisher<[DeviceModel], Never> {
        devicesSubject.eraseToAnyPublisher()
    }
    
    /// 当前缓存的设备列表快照
    var devices: [DeviceModel] {
        devicesSubject.value
    }
    
    /// 私有化初始化，从本地读取已保存的数据
    private init() {
        if let data = userDefaults.data(forKey: devicesKey),
           let decoded = try? JSONDecoder().decode([DeviceModel].self, from: data) {
            devicesSubject = CurrentValueSubject(decoded)
        } else {
            devicesSubject = CurrentValueSubject([])
        }
    }
    
    // MARK: - CRUD
    
    /// 添加或更新设备
    ///
    /// - Parameter device: 需要保存的设备模型
    func saveDevice(_ device: DeviceModel) {
        var current = devicesSubject.value
        if let index = current.firstIndex(where: { $0.serialNumber == device.serialNumber }) {
            current[index] = device
        } else {
            current.insert(device, at: 0)
        }
        updateAndPersist(current)
    }
    
    /// 删除设备
    ///
    /// - Parameter serialNumber: 目标设备的序列号
    func removeDevice(bySerialNumber serialNumber: String) {
        var current = devicesSubject.value
        current.removeAll { $0.serialNumber == serialNumber }
        updateAndPersist(current)
    }
    
    /// 更新设备最后连接时间
    ///
    /// - Parameter serialNumber: 目标设备的序列号
    func updateLastConnectionTime(for serialNumber: String) {
        var current = devicesSubject.value
        if let index = current.firstIndex(where: { $0.serialNumber == serialNumber }) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            let timeStr = formatter.string(from: Date())
            
            let old = current[index]
            let updated = DeviceModel(
                id: old.id,
                name: old.name,
                status: .connected,
                imageURL: old.imageURL,
                mac: old.mac,
                serialNumber: old.serialNumber,
                batteryLevel: old.batteryLevel,
                leftBattery: old.leftBattery,
                rightBattery: old.rightBattery,
                hasSleepReport: old.hasSleepReport,
                nickname: old.nickname,
                lastConnectionTime: timeStr
            )
            current[index] = updated
            updateAndPersist(current)
        }
    }
    
    /// 更新列表并同步到本地存储
    ///
    /// - Parameter newList: 更新后的列表数据
    private func updateAndPersist(_ newList: [DeviceModel]) {
        devicesSubject.send(newList)
        if let data = try? JSONEncoder().encode(newList) {
            userDefaults.set(data, forKey: devicesKey)
        }
    }
}

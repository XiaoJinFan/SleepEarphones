//
//  AlarmManager.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/11/7.
//

import Foundation
import Combine

// MARK: - Model

/// 闹钟数据模型（移到此处以便全局使用）
struct AlarmModel: Identifiable, Equatable, Codable {
    /// 本地唯一标识
    let id: UUID
    /// 时间字符串（如 "23:59"）
    var time: String
    /// 是否启用
    var isEnabled: Bool

    init(id: UUID = UUID(), time: String, isEnabled: Bool = true) {
        self.id = id
        self.time = time
        self.isEnabled = isEnabled
    }
}

// MARK: - Manager

/// 全局闹钟管理器（单例）
@MainActor
final class AlarmManager {
    static let shared = AlarmManager()
    
    private let userDefaults = UserDefaults.standard
    private let alarmsKey = "com.sleepearphones.alarms"
    
    /// 使用 CurrentValueSubject 方便 Combine 订阅
    let alarmsSubject: CurrentValueSubject<[AlarmModel], Never>
    
    /// 暴露给外部的 Publisher
    var alarmsPublisher: AnyPublisher<[AlarmModel], Never> {
        alarmsSubject.eraseToAnyPublisher()
    }
    
    /// 当前缓存的闹钟
    var alarms: [AlarmModel] {
        alarmsSubject.value
    }
    
    private init() {
        // 初始化时从 UserDefaults 读取
        if let data = userDefaults.data(forKey: alarmsKey),
           let decoded = try? JSONDecoder().decode([AlarmModel].self, from: data) {
            alarmsSubject = CurrentValueSubject(decoded)
        } else {
            // 默认给两条测试数据
            let defaults = [
                AlarmModel(time: "08:00", isEnabled: true),
                AlarmModel(time: "13:30", isEnabled: true)
            ]
            alarmsSubject = CurrentValueSubject(defaults)
            saveToDisk(defaults)
        }
    }
    
    /// 添加闹钟
    func addAlarm(_ alarm: AlarmModel) {
        var current = alarms
        current.append(alarm)
        updateAlarms(current)
    }
    
    /// 删除闹钟
    func deleteAlarm(at index: Int) {
        var current = alarms
        guard index < current.count else { return }
        current.remove(at: index)
        updateAlarms(current)
    }
    
    /// 更新闹钟开关状态
    func updateAlarmState(id: UUID, isEnabled: Bool) {
        var current = alarms
        if let index = current.firstIndex(where: { $0.id == id }) {
            current[index].isEnabled = isEnabled
            updateAlarms(current)
        }
    }
    
    /// 覆盖更新并同步到本地存储
    private func updateAlarms(_ newAlarms: [AlarmModel]) {
        alarmsSubject.send(newAlarms)
        saveToDisk(newAlarms)
    }
    
    private func saveToDisk(_ alarms: [AlarmModel]) {
        if let data = try? JSONEncoder().encode(alarms) {
            userDefaults.set(data, forKey: alarmsKey)
        }
    }
    
    // MARK: - Helper (供 SleepMonitor 使用)
    
    /// 获取距离当前时间最近的未来闹钟（仅限已启用的）
    var nearestActiveAlarmTime: String? {
        // 只筛选已开启的闹钟
        let activeAlarms = alarms.filter { $0.isEnabled }
        guard !activeAlarms.isEmpty else { return nil }
        
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTotalMinutes = currentHour * 60 + currentMinute
        
        var minDiff = Int.max
        var nearest: String? = nil
        
        for alarm in activeAlarms {
            let parts = alarm.time.split(separator: ":")
            guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { continue }
            
            let targetTotalMinutes = h * 60 + m
            var diff = targetTotalMinutes - currentTotalMinutes
            if diff <= 0 {
                diff += 24 * 60 // 如果今天的时间已过，算作明天的闹钟
            }
            
            if diff < minDiff {
                minDiff = diff
                nearest = alarm.time
            }
        }
        
        return nearest
    }
}

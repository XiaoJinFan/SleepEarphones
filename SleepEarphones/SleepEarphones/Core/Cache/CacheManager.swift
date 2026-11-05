//
//  CacheManager.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/16.
//

import Foundation
import Kingfisher

/// 应用缓存管理器
///
/// ## 调用方法
///
/// // 1. 统计缓存大小（字节）
/// let bytes = await CacheManager.calculateCacheSize()
///
/// // 2. 格式化展示（**已本地化单位**）
/// let text = CacheManager.formattedSize(bytes)   // 如 "12.5 MB"（中/英）/"12,5 Mo"（法）
///
/// // 3. 清空所有缓存
/// await CacheManager.clearCache()
///
enum CacheManager {

    // MARK: - Constants

    /// 目录大小枚举时的 resource keys
    private static let sizeResourceKeys: Set<URLResourceKey> = [
        .fileSizeKey,
        .isRegularFileKey
    ]

    /// 复用的字节格式化器
    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        // 跟随系统语言（如法语环境显示 "Ko" / "Mo" / "Go"）
        f.includesUnit = true
        f.isAdaptive = true
        return f
    }()

    /// 专门用于缓存 IO 的串行队列
    private static let ioQueue = DispatchQueue(
        label: "com.sleepearphones.cache.io",
        qos: .utility
    )

    // MARK: - Calculate

    /// 异步统计当前缓存占用（字节）
    ///
    /// - Returns: 总字节数
    static func calculateCacheSize() async -> Int64 {
        await withCheckedContinuation { (continuation: CheckedContinuation<Int64, Never>) in
            ioQueue.async {
                let diskSize = directorySize(at: cachesDirectory)
                // URLCache 的 currentDiskUsage 是同步属性，读它开销不大
                let urlCacheSize = Int64(URLCache.shared.currentDiskUsage)
                continuation.resume(returning: diskSize + urlCacheSize)
            }
        }
    }

    /// 将字节数格式化为可读文本（如 `"12.5 MB"`）
    ///
    /// - Parameter bytes: 字节数；`<= 0` 时也返回 `0` 对应的格式化字符串
    /// - Returns: 人类可读的字符串（**已本地化单位**）
    ///
    static func formattedSize(_ bytes: Int64) -> String {
        byteFormatter.string(fromByteCount: max(0, bytes))
    }

    // MARK: - Clear

    /// 清除所有缓存
    ///
    /// ## 清理顺序（重要，不要随意调整）
    /// 1. **Kingfisher 内存缓存**——同步，先在内存层断开
    /// 2. **Kingfisher 磁盘缓存**——异步，等待完成
    /// 3. **URLCache**——在 ioQueue 上执行
    /// 4. **Caches 目录剩余文件**——清理 Kingfisher 之外的其他缓存
    ///
    static func clearCache() async {
        // 1. Kingfisher 内存缓存（线程安全，可在任意线程调用）
        ImageCache.default.clearMemoryCache()

        // 2. Kingfisher 磁盘缓存（异步，completion 在任意线程回调）
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ImageCache.default.clearDiskCache {
                continuation.resume()
            }
        }

        // 3. URLCache
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ioQueue.async {
                URLCache.shared.removeAllCachedResponses()
                continuation.resume()
            }
        }

        // 4. Caches 目录剩余文件（含 Kingfisher 目录之外的其他缓存）
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ioQueue.async {
                clearDirectory(at: cachesDirectory)
                continuation.resume()
            }
        }

        AppLog.cache.debug("缓存已清除")
    }

    // MARK: - Helpers

    /// App 沙盒的 `Caches` 目录
    ///
    /// - Returns: Caches 目录 URL
    ///
    private static var cachesDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    /// 递归计算目录大小（需在后台队列执行）
    ///
    /// - Parameter url: 目标目录
    /// - Returns: 目录内所有**普通文件**的字节数总和
    ///
    private static func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(sizeResourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: sizeResourceKeys)
            if values?.isRegularFile == true, let size = values?.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    /// 清空目录内容但保留目录本身（需在后台队列执行）
    ///
    /// - Parameter url: 目标目录
    /// 
    private static func clearDirectory(at url: URL) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        for item in items {
            do {
                try fm.removeItem(at: item)
            } catch {
                // 正在使用中的文件可能删除失败，忽略即可
                AppLog.cache.debug(
                    "删除缓存项失败：\(item.lastPathComponent, privacy: .public) - \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}

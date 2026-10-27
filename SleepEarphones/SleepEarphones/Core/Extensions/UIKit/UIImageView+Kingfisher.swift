//
//  UIImageView+Kingfisher.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/16.
//

import UIKit
import Kingfisher

// MARK: - 统一图片加载

@MainActor
extension UIImageView {

    /// 使用 Kingfisher 加载网络图片（统一占位图与淡入过渡）
    ///
    /// - Parameters:
    ///   - urlString: 图片 URL；为 nil / 无效时仅展示占位图
    ///   - placeholder: 占位图，支持 `String`（资源名）或 `UIImage`；传 nil 则不显示占位图
    ///   - fadeDuration: 淡入时长，传 0 关闭过渡动画
    ///   - customOptions: 自定义 Kingfisher 选项；传 nil 时使用默认（`.cacheOriginalImage`）
    ///   - completion: 可选加载完成回调
    ///   
    func setImage(_ urlString: String?, placeholder: Any? = nil, fadeDuration: TimeInterval = 0.25, options customOptions: KingfisherOptionsInfo? = nil, completion: (@Sendable (Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) {
        // 解析占位图：支持 String（资源名）与 UIImage 两种类型
        let placeholderImage = Self.resolvePlaceholder(placeholder)

        // URL 非法：只展示占位图，避免发起无效请求
        guard let urlString,
              !urlString.isEmpty,
              let url = URL(string: urlString) else {
            image = placeholderImage
            return
        }

        // 组装选项
        var options: KingfisherOptionsInfo = customOptions ?? [.cacheOriginalImage]
        if fadeDuration > 0 {
            options.append(.transition(.fade(fadeDuration)))
        }

        kf.setImage(
            with: url,
            placeholder: placeholderImage,
            options: options,
            completionHandler: completion
        )
    }

    /// 取消当前加载任务（列表 Cell 复用时调用）
    ///
    /// - Parameter clearImage: 是否同时清空 `image`；默认 `true`
    ///
    /// - Note: 同时清空 `image` 可避免 Cell 复用时残留上一张图。
    ///         如果不希望清空，只调 `kf.cancelDownloadTask()` 即可。
    func cancelRemoteImageLoad(clearImage: Bool = true) {
        kf.cancelDownloadTask()
        if clearImage {
            image = nil
        }
    }

    // MARK: - Private

    /// 解析占位图参数
    ///
    /// - Parameter placeholder: 支持 `String` / `UIImage` / nil
    /// - Returns: 解析后的 UIImage；无法解析时返回 nil
    private static func resolvePlaceholder(_ placeholder: Any?) -> UIImage? {
        switch placeholder {
        case let name as String:
            return UIImage(named: name)
        case let image as UIImage:
            return image
        default:
            return nil
        }
    }
}

// MARK: - 预加载

/// Kingfisher 图片预取工具
///
/// ## 调用方法
/// ```swift
/// // 1. push 前预取（页面几乎瞬显，避免占位图闪烁）
/// ImagePrefetch.start([AppImage.Remote.companyLogo])
/// let vc = AboutUsViewController()
/// navigationController?.pushViewController(vc, animated: true)
///
/// // 2. 转场 / 内存警告时主动取消
/// ImagePrefetch.cancel()
/// 
@MainActor
enum ImagePrefetch {

    // MARK: - Holder
    
    @MainActor
    private final class Holder {
        static var current: Kingfisher.ImagePrefetcher?
    }

    // MARK: - Public API

    /// 启动预取（自动取消上一次未完成的预取任务）
    ///
    /// - Parameter urlStrings: 待预取的 URL 字符串数组
    static func start(_ urlStrings: [String]) {
        let urls = urlStrings.compactMap { URL(string: $0) }
        guard !urls.isEmpty else {
            AppLog.ui.debug("ImagePrefetch 跳过：URL 列表为空或全部非法")
            return
        }

        let prefetcher = Kingfisher.ImagePrefetcher(
            urls: urls,
            options: [.cacheOriginalImage]
        )

        // 取消上一次
        Holder.current?.stop()

        Holder.current = prefetcher
        prefetcher.start()

        AppLog.ui.debug("ImagePrefetch 已启动 \(urls.count) 个 URL")
    }

    /// 主动取消预取
    ///
    /// - Note: 一般无需手动调用——`start` 会自动取消上一次。
    ///         页面转场 / 内存警告时调用更保险。
    static func cancel() {
        Holder.current?.stop()
        Holder.current = nil
        AppLog.ui.debug("ImagePrefetch 已取消")
    }
}

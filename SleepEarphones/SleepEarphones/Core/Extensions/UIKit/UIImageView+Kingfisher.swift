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
    /// ## 调用方法
    /// ```swift
    /// // 1. 字符串资源名作占位图
    /// imageView.setImage(url, placeholder: "空数据占位图")
    ///
    /// // 2. UIImage 作占位图
    /// imageView.setImage(url, placeholder: AppImage.Local.avatarPlaceholder)
    ///
    /// // 3. 无占位图
    /// imageView.setImage(url, placeholder: nil)
    ///
    /// // 4. 关闭淡入动画
    /// imageView.setImage(url, fadeDuration: 0)
    ///
    /// // 5. 自定义 options（覆盖默认的 `.cacheOriginalImage`）
    /// imageView.setImage(url, options: [.memoryCacheExpiration(.seconds(300))])
    /// ```
    ///
    /// - Parameters:
    ///   - urlString: 图片 URL；为 nil / 无效时仅展示占位图
    ///   - placeholder: 占位图，支持 `String`（资源名）或 `UIImage`；传 nil 则不显示占位图
    ///                  - ⚠️ **历史设计**：`Any?` 类型是为了同时兼容两种输入
    ///                    （资源名字符串 / UIImage 实例）。
    ///                    理想方案是拆成两个重载方法，但会破坏所有现有调用方，
    ///                    因此保留 `Any?` 并在 `resolvePlaceholder` 中分派。
    ///                    未来重构时可引入 `ImagePlaceholder` 枚举替代。
    ///   - fadeDuration: 淡入时长（秒），传 `<= 0` 关闭过渡动画
    ///   - customOptions: 自定义 Kingfisher 选项；传 nil 时使用默认（`.cacheOriginalImage`）
    ///                    - ⚠️ 传入的 options 会**替换**默认值，而非追加。
    ///                      若需要 `.cacheOriginalImage`，请在 `customOptions` 中显式包含。
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
    /// - Parameter placeholder: 支持 `String`（资源名）/ `UIImage` / nil
    /// - Returns: 解析后的 UIImage；无法解析时返回 nil
    ///
    private static func resolvePlaceholder(_ placeholder: Any?) -> UIImage? {
        switch placeholder {
        case let name as String:
            // 资源名不存在时，`UIImage(named:)` 返回 nil。
            // 记 debug 日志（而非 error）——调用方可能有意"按需加载"占位图，
            // 缺图不应视为错误；但 debug 日志有助于排查拼写问题。
            if let image = UIImage(named: name) {
                return image
            }
            AppLog.ui.debug(
                "图片占位资源未找到：\(name, privacy: .public)（回退到无占位图）"
            )
            return nil

        case let image as UIImage:
            return image

        case .none:
            return nil

        default:
            // 调用方传了既不是 String 也不是 UIImage 的类型
            AppLog.ui.debug(
                "占位图参数类型不支持：\(type(of: placeholder), privacy: .public)（仅支持 String / UIImage）"
            )
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
/// ```
///
@MainActor
enum ImagePrefetch {

    // MARK: - Holder

    /// 预取器持有者
    @MainActor
    private final class Holder {
        static var current: Kingfisher.ImagePrefetcher?
    }

    // MARK: - Public API

    /// 启动预取（自动取消上一次未完成的预取任务）
    ///
    /// - Parameter urlStrings: 待预取的 URL 字符串数组
    /// 
    static func start(_ urlStrings: [String]) {
        // 1. 过滤非法 URL（同时记录失败项便于排查）
        var urls: [URL] = []
        urls.reserveCapacity(urlStrings.count)

        for raw in urlStrings {
            guard let url = URL(string: raw) else {
                // Debug 才输出，避免 Release 下的日志噪声
                AppLog.ui.debug(
                    "ImagePrefetch 跳过非法 URL：\(raw, privacy: .public)"
                )
                continue
            }
            urls.append(url)
        }

        guard !urls.isEmpty else {
            AppLog.ui.debug("ImagePrefetch 跳过：URL 列表为空或全部非法")
            return
        }

        // 2. 取消上一次
        Holder.current?.stop()

        // 3. 创建新预取器
        let prefetcher = Kingfisher.ImagePrefetcher(
            urls: urls,
            options: [.cacheOriginalImage]
        )
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

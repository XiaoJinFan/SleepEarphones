//
//  AppImage.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import UIKit

/// 全局图片资源定义
///
/// ## 资源命名约定
/// - **本地图片**：使用中文名（如"设置头像占位图"）——这是项目历史遗留，
///   Asset Catalog 中的资源名与代码 `image(named:)` 的字符串必须一致。
///   **改进方向**：未来逐步迁移为英文名（如 `avatar_placeholder`），
///   迁移时需同步修改 `.xcassets` 中的文件夹名与代码中的字符串。
/// - **SF Symbols**：使用官方 Symbol Name（如 `"chevron.right"`）——
///   由系统提供，跨 iOS 版本稳定。
/// - **远程图片**：直接存 URL 字符串。
///
/// ## 关于图片缺失
/// `image(named:)` 找不到资源时：
/// - **Debug**：输出 error 日志 + `assertionFailure`（立即暴露问题）
/// - **Release**：输出 error 日志 + 返回 1×1 透明占位图（不崩溃）
///
/// 这样既保证了开发期问题可见，又避免了线上因某个图标遗漏导致闪退。
enum AppImage {

    // MARK: - Local（本地资源）

    /// 本地图片资源（Assets.xcassets）
    ///
    enum Local {

        // MARK: 占位图

        /// 头像占位图
        static let avatarPlaceholder = image(named: "设置头像占位图")

        /// 设备占位图
        static let devicePlaceholder = image(named: "设备占位图")

        /// 空数据占位图（列表空态、详情占位通用）
        static let emptyData = image(named: "空数据占位图")

        /// 通用 logo 占位（登录页 / 注册页 / 关于我们）
        static let logoPlaceholder = image(named: "logo_placeholder")

        // MARK: Tab 图标

        /// Tab - 首页
        static let tabHome = image(named: "home_un")

        /// Tab - 记录
        static let tabSleep = image(named: "record_un")

        /// Tab - 音乐
        static let tabMusic = image(named: "music_un")

        /// Tab - 我的
        static let tabMine = image(named: "mine_un")

        // MARK: 页面装饰

        /// 联系我们 - 顶部装饰图
        static let contactUsHeader = image(named: "contactUsVC_header")

        // MARK: 登录 / 注册输入区图标

        /// 手机号输入图标
        static let iconPhone = image(named: "手机登录")

        /// 邮箱输入图标
        static let iconEmail = image(named: "邮箱登录")

        /// 验证码输入图标
        static let iconCode = image(named: "验证码")

        /// 密码输入图标
        static let iconPassword = image(named: "密码")

        /// 下拉箭头（区号选择）
        static let iconArrowDown = image(named: "向下箭头")

        // MARK: 三方登录

        /// 游客登录图标
        static let iconGuestLogin = image(named: "guest_login")

        /// 微信登录图标
        static let iconWeChatLogin = image(named: "微信登录")

        /// Apple 登录图标
        static let iconAppleLogin = image(named: "Apple登录")
    }

    // MARK: - Device（设备详情与控制相关）

    /// 设备详情页及 BLE 功能相关的图片
    enum Device {

        // MARK: 设备主体

        /// 设备默认大图（详情页顶部）
        static let defaultDeviceLarge = image(named: "设备占位图")

        // MARK: 电量

        /// 左耳电量图标
        static let leftEar = image(named: "左耳电量")

        /// 右耳电量图标
        static let rightEar = image(named: "右耳电量")

        /// 充电仓图标
        static let batteryBox = image(named: "充电仓")

        // MARK: 睡眠卡片

        /// 声音库图标
        static let soundLibrary = image(named: "声音库")

        /// 睡眠报告图标
        static let sleepReport = image(named: "睡眠报告")

        // MARK: 设置列表图标

        /// 睡眠模式图标
        static let iconMoon = image(named: "睡眠模式")

        /// 智能音量图标
        static let iconVolume = image(named: "智能音量")

        /// 闹钟模式图标
        static let iconAlarm = image(named: "闹钟模式")

        /// 睡眠定时图标
        static let iconTimer = image(named: "睡眠定时")

        /// 手势控制图标
        static let iconFinger = image(named: "手势控制")

        /// 音效图标
        static let iconSpeaker = image(named: "音效")

        // MARK: 其他

        /// 帮助信息图标（问号）
        static let iconInfo = image(named: "疑问")

        /// 列表右侧箭头
        static let iconArrowNext = UIImage(systemName: "chevron.right")
    }

    // MARK: - Remote（远程图片地址）

    /// 远程图片 URL
    ///
    /// - Note: 调用方配合 `UIImageView.setImage(_:)` 使用。
    enum Remote {

        /// 关于我们 - 公司 logo
        static let companyLogo = "https://zhongtai.zhongbenruanjian.com/imgTheme/0/2/7587/1567392?1750041113530"

        /// 证照信息 - 企业资质
        static let licenseCertificate = "https://zhongtai.zhongbenruanjian.com/imgTheme/0/2/7587/1457980"
    }

    // MARK: - System（SF Symbols）

    /// SF Symbols 系统图标
    ///
    enum System {

        /// 右箭头（列表项尾部）
        static let chevronRight: UIImage = symbol(named: "chevron.right")

        /// 关闭
        static let close: UIImage = symbol(named: "xmark")

        /// 电话
        static let phoneFill: UIImage = symbol(named: "phone.fill")

        /// 邮件
        static let envelopeFill: UIImage = symbol(named: "envelope.fill")

        /// 眼睛 - 隐藏密码
        static let eyeSlashFill: UIImage = symbol(named: "eye.slash.fill")

        /// 眼睛 - 显示密码
        static let eyeFill: UIImage = symbol(named: "eye.fill")

        /// 协议未勾选圆圈
        static let circle: UIImage = symbol(named: "circle")

        /// 协议已勾选圆圈
        static let checkmarkCircleFill: UIImage = symbol(named: "checkmark.circle.fill")
    }

    // MARK: - Helper

    /// 1×1 透明兜底图（全局缓存，只生成一次）
    private static let placeholderPixel: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }()

    /// 加载本地图片并做缺失检查
    ///
    /// - Parameter name: `Assets.xcassets` 中的图片名
    /// - Returns: 加载到的图片；缺失时返回 **1×1 透明图**
    ///
    private static func image(named name: String) -> UIImage {
        if let image = UIImage(named: name) {
            return image
        }

        AppLog.ui.error("图片资源缺失：\(name, privacy: .public)")
        #if DEBUG
        assertionFailure("图片资源缺失：\(name)（请检查 Assets.xcassets）")
        #endif
        return placeholderPixel
    }

    /// 加载 SF Symbol 并做缺失检查
    ///
    /// - Parameter name: SF Symbol 名（如 `"chevron.right"`）
    /// - Returns: 加载到的符号图；名称无效时返回 1×1 透明图
    ///
    private static func symbol(named name: String) -> UIImage {
        if let image = UIImage(systemName: name) {
            return image
        }

        AppLog.ui.error("SF Symbol 名无效：\(name, privacy: .public)")
        #if DEBUG
        assertionFailure("SF Symbol 名无效：\(name)")
        #endif
        return placeholderPixel
    }
}

//
//  AppImage.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import UIKit

/// 全局图片资源定义
///
enum AppImage {

    // MARK: - Local（本地资源）

    /// 本地图片资源
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

    // MARK: - Remote（远程图片地址）

    /// 远程图片 URL
    ///
    /// - Note: 调用方配合 `UIImageView.setImage(_:)` 使用。
    ///
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
        static let chevronRight = UIImage(systemName: "chevron.right")

        /// 关闭
        static let close = UIImage(systemName: "xmark")

        /// 电话
        static let phoneFill = UIImage(systemName: "phone.fill")

        /// 邮件
        static let envelopeFill = UIImage(systemName: "envelope.fill")

        /// 眼睛 - 隐藏密码
        static let eyeSlashFill = UIImage(systemName: "eye.slash.fill")

        /// 眼睛 - 显示密码
        static let eyeFill = UIImage(systemName: "eye.fill")

        /// 协议未勾选圆圈
        static let circle = UIImage(systemName: "circle")

        /// 协议已勾选圆圈
        static let checkmarkCircleFill = UIImage(systemName: "checkmark.circle.fill")
    }

    // MARK: - Helper

    /// 1×1 透明兜底图（全局缓存，只生成一次）
    ///
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
    /// - Returns: 加载到的图片；缺失时返回 **1×1 透明图** 并输出日志
    /// 
    private static func image(named name: String) -> UIImage {
        if let image = UIImage(named: name) {
            return image
        }

        AppLog.ui.error("图片资源缺失：\(name, privacy: .public)")
        assertionFailure("图片资源缺失：\(name)（请检查 Assets.xcassets）")

        return placeholderPixel
    }
}

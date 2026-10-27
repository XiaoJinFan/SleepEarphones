//
//  APIEndpoint.swift
//  Network
//
//  Created by 肖进凡 on 2026/9/16.
//

import Foundation

/// 后端接口端点登记表
///
/// ## 调用方法
/// ```swift
/// // 1. 在 APIRequest 里引用
/// struct LoginAPI: APIRequest {
///     var path: String { APIEndpoint.login.rawValue }
///     var method: HTTPMethod { .post }
/// }
///
/// // 2. 拼接完整 URL（仅日志 / 调试用）
/// let url = APIEndpoint.login.urlString()
///
/// // 3. 通过 path 反查端点（便于排障）
/// if let endpoint = APIEndpoint(path: "5c78dbfd977cf") {
///     print(endpoint)  // login
/// }
/// ```
///
/// - Note: 继承 `Sendable`：`rawValue` 是 `String`，天然线程安全。
enum APIEndpoint: String, Sendable {

    // MARK: - 通用

    /// 文件上传
    case uploadFile = "5fc615f7da92b"

    /// 获取用户手机号
    case userPhone = "5f69ee219127f"

    /// 发送短信验证码
    case smsCode = "5b5bdc44796e8"

    /// 校验验证码
    case checkCode = "5f6db4db8abcf"

    /// 隐私政策 / 单页内容
    case privacyPolicy = "641568f1b6f87"

    // MARK: - 登录注册

    /// 获取公共 token
    case token = "toKen/permissions"

    /// 密码登录
    case login = "5c78dbfd977cf"

    /// 验证码登录
    case codeLogin = "5c78dca45ebc1"

    /// 第三方登录
    case thirdLogin = "5d7660a421e69"

    /// 第三方账号绑定
    case thirdBind = "5d7757d28d076"

    /// 手机 / 邮箱注册
    case register = "5cad9f63e4f94"

    /// 忘记密码 / 重置密码
    case forgetPassword = "5caeeba9866aa"

    // MARK: - 设备 / 故障

    /// 故障分类列表
    case faultType = "687755557b6fa"

    /// 故障提交
    case faultSubmit = "687755b1d963f"

    /// 固件版本查询
    case firmwareDetails = "6877552f153da"

    /// 设备详情
    case deviceDetails = "6874bd8bb2c1c"

    /// 查询连接过的设备（当前用于"设备列表"）
    case checkDevice = "686f7b5dd1947"

    /// 添加设备
    case addDevice = "68746e0d33992"

    /// 删除设备
    case deleteDevice = "68749f9fcb42a"

    /// 更新设备最后一次连接时间
    case updateDeviceLastConnectTime = "690aeb31702fa"

    /// 设备名称搜索 / 设备列表
    case deviceList = "693f677f5533c"

    // MARK: - 消息 / 公告

    /// 消息列表（与帮助中心共用）
    case messageList = "6424235abdc3c"

    /// 平台公告列表
    case noticeList = "6415752f56d0f"

    /// 公告详情
    case noticeDetails = "641576c24de11"

    // MARK: - 我的 / 设置

    /// 关于我们
    case aboutUs = "64cdb895b79ba"

    /// 注销账号 - 原因列表
    case logoutReason = "637c458b131e3"

    /// 注销账号 - 提交申请
    case logoutSubmit = "637c4d70d3aa8"

    /// 我的资料
    case myInformation = "5c78c4772da97"

    /// 修改个人资料
    case editInformation = "5cb54af125f1c"

    /// 取消注销申请
    case cancelLogout = "661a5adf8203b"

    /// 帮助与反馈列表
    case helpList = "6729cd8c2190d"

    /// 帮助详情
    case helpDetails = "64219c5dc8d0d"

    /// 修改密码
    case editPassword = "5da9ab4c4c7af"

    /// 修改绑定手机
    case editPhone = "5f6c915d69d1f"

    /// 修改绑定邮箱
    case editEmail = "68808e61f075d"

    // MARK: - 音乐 / 睡眠

    /// 引导添加图
    case addImage = "6877476bc56db"

    /// 音乐分类
    case musicType = "687720427240a"

    /// 首页轮播图
    case loopImage = "641e624160dd0"

    /// 音效列表
    case soundEffects = "6877455c0170a"

    /// 设置音量 / 音效 / 睡眠模式
    case musicSet = "6874b984c14ef"

    /// 闹钟列表
    case clockList = "68774ace0bdaf"

    /// 操作闹钟（增删改）
    case changeClock = "68774c7cd9c42"

    /// 获取音乐列表
    case musicList = "6874cfc814dde"

    /// 内置设备音乐 - 辅助接口
    case deviceMusicAid = "68f86d0cb439c"

    /// 内置设备音乐 - 数据接口
    case deviceMusicData = "68f8789e2b90e"

    // MARK: - 睡眠记录

    /// 添加睡眠记录
    case addSleepRecord = "68f89b4f16cf9"

    /// 查询睡眠记录
    case querySleepRecord = "68f8a357902ec"

    /// 睡眠数据统计
    case sleepData = "6878a8046e758"

    /// 查询每月睡眠记录标点
    case monthlySleepRecord = "68f8aa6b15eba"

    // MARK: - 音频

    /// 添加音频
    case addAudio = "68f8572fbbc6e"

    /// 删除内置音频
    case deleteBuiltinAudio = "68f87926e99c7"

    // MARK: - 问卷

    /// 问卷调查题目
    case questionList = "687756e4675c8"

    /// 查询是否填写过问卷
    case checkQuestion = "69a7e5601b415"

    /// 提交问卷
    case submitQuestion = "6877581303211"

    // MARK: - 其他

    /// 分享链接
    case shareLink = "691c0c1fea83e"
}

// MARK: - 便捷属性

extension APIEndpoint {

    /// 完整 URL 字符串（仅调试 / 打日志时使用）
    ///
    /// - Parameter baseURL: 基础 URL，默认 `APIConfiguration.serverPrefix`
    /// - Returns: 完整 URL 字符串；拼接失败时退回简单拼接
    /// 
    func urlString(baseURL: String = APIConfiguration.serverPrefix) -> String {
        URLBuilder.build(base: baseURL, path: rawValue)?.absoluteString
            ?? "\(baseURL)/\(rawValue)"
    }
}

// MARK: - 反查

extension APIEndpoint {

    /// 通过 `path` 反查端点
    ///
    /// - Parameter path: `APIRequest.path`（可带或不带前导 `/`）
    /// - Returns: 匹配的端点；未登记时返回 `nil`
    ///
    init?(path: String) {
        let normalized = path.hasPrefix("/") ? String(path.dropFirst()) : path
        self.init(rawValue: normalized)
    }
}

//
//  UserProfileAPI.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/30.
//

import Foundation
import Alamofire
import Network

/// 用户资料相关接口
///
/// ## 接口清单
/// | 接口 | 后端路径 | 用途 |
/// |---|---|---|
/// | `editProfile` | `user/edit_user_info`（`5cb54af125f1c`） | 修改昵称 / 头像 |
/// | `fetchUserInfo` | `user/get_user_info`（`5c78c4772da97`） | 拉取用户详细信息 |
/// | `uploadAvatar` | `upload/uploadFileOss`（`5fc615f7da92b`） | 上传头像文件，返回 URL |
///
/// ## 认证
/// 所有接口都需要 `user-token` 请求头（从 `AuthStore.shared.token` 读取）。
/// 缺失时后端会返回 401，由 `NetworkClient` 映射为 `.tokenExpired`。
///
/// ## 关于 `avatar` 参数
/// 后端 `edit_user_info` 的 `avatar` 是 **String**（URL）——
/// 因此必须先通过 `uploadAvatar` 上传文件拿到 URL，再把 URL 传给 `editProfile`。
///
/// ## 上传接口的返回结构（重点）
/// ```json
/// {
///   "code": 1,
///   "data": {
///     "data": {
///       "file": "https://xmsmej.oss-cn-hongkong.aliyuncs.com/m12323/2026-09-30/599e315bb091411ff1533e29d98f6ced.png",
///       "fileId": 12040505
///     },
///     "success": "上传成功AliOss"
///   },
///   "msg": "ok",
///   "time": 1790737309
/// }
/// ```
/// **注意是 `data.data.file` 嵌套两层**——由 `UploadResult` 统一解析。
enum UserProfileAPI: APIRequest {

    // MARK: - Cases

    /// 修改用户资料
    ///
    /// - Parameters:
    ///   - nickname: 新昵称；`nil` 或空串表示不修改
    ///   - avatarURL: 头像 URL；`nil` 或空串表示不修改
    ///
    /// - Note: 本项目只改昵称 + 头像，其余选填参数
    ///         （gender / birthday / background / autograph）不传。
    ///
    /// ## 后端请求示例
    /// ```json
    /// {
    ///   "avatar": "https://xmsmej.oss-cn-hongkong.aliyuncs.com/m12323/2026-09-30/599e315bb091411ff1533e29d98f6ced.png",
    ///   "nickname": "划水真的"
    /// }
    /// ```
    case editProfile(nickname: String?, avatarURL: String?)

    /// 拉取当前登录用户的详细信息
    ///
    /// - Note: 无参数——服务端通过 `user-token` 请求头识别当前用户。
    ///
    /// ## 使用场景
    /// - 进入「我的」Tab 时刷新用户信息
    /// - 未来"个人中心"页展示更多字段（会员等级、积分等）
    case fetchUserInfo

    /// 上传头像文件（multipart/form-data）
    ///
    /// - Parameters:
    ///   - imageData: JPEG 二进制
    ///   - fileName: 文件名（如 `"avatar.jpg"`）
    ///   - fieldName: 后端约定的表单字段名（默认 `"file"`）
    ///   - mimeType: MIME 类型（默认 `"image/jpeg"`）
    ///
    /// - Note: 后端约定表单字段名就是 `"file"`——
    ///         从接口文档"参数名字 = file"可以看出。
    case uploadAvatar(
        imageData: Data,
        fileName: String,
        fieldName: String,
        mimeType: String
    )

    // MARK: - APIRequest

    var path: String {
        switch self {
        case .editProfile:   return APIEndpoint.editInformation.rawValue   // 5cb54af125f1c
        case .fetchUserInfo: return APIEndpoint.myInformation.rawValue     // 5c78c4772da97
        case .uploadAvatar:  return APIEndpoint.uploadFile.rawValue        // 5fc615f7da92b
        }
    }

    var method: HTTPMethod { .post }

    /// `editProfile` / `fetchUserInfo` 用 JSON body；
    /// `uploadAvatar` 自行构造 multipart body（见 `asURLRequest`）
    var encoding: ParameterEncoding { JSONEncoding.default }

    var parameters: [String: Any]? {
        switch self {
        case .editProfile(let nickname, let avatarURL):
            // 只传非空字段——后端约定"选填"，缺省即不修改
            var p: [String: Any] = [:]
            if let nickname, !nickname.isEmpty {
                p["nickname"] = nickname
            }
            if let avatarURL, !avatarURL.isEmpty {
                p["avatar"] = avatarURL
            }
            return p.isEmpty ? nil : p

        case .fetchUserInfo:
            // 无参数——服务端通过 `user-token` 识别用户
            return nil

        case .uploadAvatar:
            return nil  // multipart 由 asURLRequest 构造
        }
    }

    /// 请求头：附加 `user-token`
    ///
    /// - Note:
    ///   - `AuthStore.shared.token` 内部线程安全（Keychain / UserDefaults 均线程安全），
    ///     `asURLRequest()` 在任意线程调用都安全。
    ///   - 无 token 时返回 `nil`——后端会返回 401，
    ///     由 `NetworkClient` 映射为 `.tokenExpired`。
    ///
    /// ## 与 `AccountSecurityAPI.headers` 的相似性
    /// 两处 token 读取逻辑**几乎一致**——但**当前不抽公共**：
    /// - 两处的 `path` / 日志需求不同（一个 debug 日志、一个无日志）
    /// - 抽公共会引入**跨模块**依赖——`AccountSecurityAPI` 与 `UserProfileAPI`
    ///   分属不同 feature，不应互相依赖
    /// - **若未来**出现第三个 API 也需要 `user-token`——
    ///   可考虑在 `APIRequest` 协议扩展加一个 `defaultAuthHeaders` 静态方法
    var headers: HTTPHeaders? {
        guard let token = AuthStore.shared.token, !token.isEmpty else {
            return nil
        }
        return ["user-token": token]
    }

    // MARK: - asURLRequest

    /// 覆盖默认实现，为 `uploadAvatar` 手动构造 multipart body
    ///
    /// - Note: 为什么不用 Alamofire 的 `session.upload(multipartFormData:)`？
    ///         本项目所有请求统一走 `session.request(api)`——
    ///         在 `asURLRequest()` 里手动拼 `multipart/form-data` body，
    ///         就能保持**架构一致**，无需给 `NetworkClient` 额外加 `upload` 方法。
    func asURLRequest() throws -> URLRequest {
        switch self {
        case .editProfile, .fetchUserInfo:
            return try buildStandardRequest()

        case .uploadAvatar(let imageData, let fileName, let fieldName, let mimeType):
            return try buildMultipartRequest(
                imageData: imageData,
                fileName: fileName,
                fieldName: fieldName,
                mimeType: mimeType
            )
        }
    }

    // MARK: - Private Request Builders

    /// 标准 JSON 请求（等价于 `APIRequest` 扩展的默认实现）
    ///
    /// ## ⚠️ 关于"复制默认实现"的风险说明（重要）
    /// 因为本类型**覆盖**了 `asURLRequest()`，无法直接调用协议扩展的默认实现，
    /// 所以把默认逻辑在此处**复制**了一份。
    ///
    /// **风险**：若未来 `APIRequest` 的默认实现被修改
    /// （如加入 UA 处理 / 统一 header / 超时策略），本处**不会**自动跟随——
    /// 会造成**两个接口行为不一致**的隐蔽 bug。
    ///
    /// ## 为什么当前选择"复制"而非"抽取共享工具"？
    /// - **本文件**是唯一的"覆盖 `asURLRequest`"的 API——
    ///   只有一处重复，抽取共享工具的成本 > 收益
    /// - **若未来**出现第二个需要 multipart 的 API——
    ///   **那时**再把默认实现抽到 `APIRequestBuilder` 或类似工具类——
    ///   让两处**共享**同一份逻辑
    ///
    /// ## 维护清单（修改默认实现时的检查点）
    /// 若修改 `APIRequest.asURLRequest()` 的默认实现，**必须**同步本方法——
    /// 检查以下内容是否一致：
    /// - [ ] URL 构造（`URLBuilder.build`）
    /// - [ ] HTTP 方法设置
    /// - [ ] 超时时间
    /// - [ ] Header 合并策略
    /// - [ ] 参数编码方式
    private func buildStandardRequest() throws -> URLRequest {
        guard let url = URLBuilder.build(base: baseURL, path: path) else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeoutInterval
        if let headers {
            request.headers = headers
        }
        return try encoding.encode(request, with: parameters)
    }

    /// 构造 `multipart/form-data` 请求
    ///
    private func buildMultipartRequest(
        imageData: Data,
        fileName: String,
        fieldName: String,
        mimeType: String
    ) throws -> URLRequest {
        guard let url = URLBuilder.build(base: baseURL, path: path) else {
            throw NetworkError.invalidURL
        }

        // ✅ 生成 boundary——UUID 保证唯一性，避免与 imageData 内容冲突
        let boundary = "----SleepEarphones-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeoutInterval

        // 合并自定义 header + Content-Type
        if let headers {
            request.headers = headers
        }
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        // ✅ 构造完整 body（3 段拼接）
        request.httpBody = try makeMultipartBody(
            imageData: imageData,
            fileName: fileName,
            fieldName: fieldName,
            mimeType: mimeType,
            boundary: boundary
        )

        return request
    }

    /// 构造 multipart body
    ///
    private func makeMultipartBody(
        imageData: Data,
        fileName: String,
        fieldName: String,
        mimeType: String,
        boundary: String
    ) throws -> Data {
        // 1. 转义用户可控字段（防 header injection）
        let safeFieldName = Self.escapeMultipartValue(fieldName)
        let safeFileName  = Self.escapeMultipartValue(fileName)

        // 2. 构造 header 字符串（一次编码）
        //
        // - Note: 用 `\r\n` 作为 CRLF（HTTP 规范要求）——
        //         最后**两个** `\r\n` 是 header 与 body 之间的空行分隔。
        let headerString = [
            "--\(boundary)",
            "Content-Disposition: form-data; name=\"\(safeFieldName)\"; filename=\"\(safeFileName)\"",
            "Content-Type: \(mimeType)",
            "",
            ""
        ].joined(separator: "\r\n")

        // 3. 构造 footer 字符串
        let footerString = "\r\n--\(boundary)--\r\n"

        // 4. 编码（几乎不会失败——但**不**强制解包，避免潜在崩溃）
        //
        // - Note: 若编码失败（如未来 header 含非 UTF-8 字符），
        //         抛出 `NetworkError.invalidURL`（语义：请求构造失败）。
        //         当前实际不会触发——但**防御性**保证代码健壮性。
        guard let headerData = headerString.data(using: .utf8),
              let footerData = footerString.data(using: .utf8) else {
            AppLog.profile.error("multipart header/footer UTF-8 编码失败")
            throw NetworkError.invalidURL
        }

        // 5. 拼接（3 段）
        var body = Data()
        body.reserveCapacity(headerData.count + imageData.count + footerData.count)
        body.append(headerData)
        body.append(imageData)
        body.append(footerData)
        return body
    }

    /// 转义 multipart 字段值（防 header injection）
    ///
    private static func escapeMultipartValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")   // 反斜杠转义（**先**）
            .replacingOccurrences(of: "\"", with: "\\\"")   // 引号转义
            .replacingOccurrences(of: "\r", with: "")       // 移除 CR
            .replacingOccurrences(of: "\n", with: "")       // 移除 LF
    }
}

// ============================================================
// MARK: - 用户详情
// ============================================================

/// 用户详细信息（`user/get_user_info` 接口返回的 `data` 层）
///
/// ## 返回结构（**注意与 `LoginResult` 的区别**）
/// `data` 直接就是用户对象（**没有 `userinfo` 层包装**）：
/// ```json
/// {
///   "code": 1,
///   "data": {
///     "id": 3910,
///     "account": "1786096102_38737",
///     "nickname": "sam",
///     "avatar": "https://admin.xing-man.com/static/admin/images/name.png",
///     "mobile": "183****1021",
///     "_mobile": 18384891021,
///     "gender": 0,
///     "birthday": "2026-08-07",
///     "real_name": "",
///     "email": "",
///     "userlevel_name": "普通会员",
///     "is_cancel": 0,
///     ...
///   },
///   "msg": "请求成功",
///   "time": 1790733787
/// }
/// ```
///
/// ## 关键字段说明
/// | 字段 | 说明 |
/// |---|---|
/// | `mobile` | **脱敏号**（`183****1021`），仅用于展示 |
/// | `realMobile` | **真实号**（`18384891021`，后端 `_mobile`），用于发验证码 |
/// | `email` | 真实邮箱 |
///
/// 因此**不能复用** `LoginResult`——两个接口结构不同。
///
/// ## 容错策略（重要）
/// 本类型使用**自定义容错解码**而非自动合成：
/// 1. **每字段独立 `try?`**——任一字段失败不影响其他字段
/// 2. **数值字段兼容 `Int` / `String`**——后端 PHP 可能把 `0` 序列化为 `"0"`
/// 3. **失败时输出字段名**——便于 Console 定位
struct UserDetailInfo: Decodable, Sendable {

    // MARK: - 核心字段（UI 会用到的）

    /// 用户 ID
    let id: Int?

    /// 后端生成的内部账号名（如 `"1786096102_38737"`）
    let account: String?

    /// 昵称（如 `"sam"`）
    let nickname: String?

    /// 头像 URL（**完整 URL**，无需再拼 CDN）
    let avatar: String?

    /// 手机号（带 `*` 号，如 `"183****1021"`）
    let mobile: String?

    /// 真实姓名
    let realName: String?

    /// 邮箱
    let email: String?

    /// 性别（`0` = 未知，`1` = 男，`2` = 女）
    let gender: Int?

    /// 生日（字符串 `"2026-08-07"`）
    let birthday: String?

    /// ✅ 真实手机号（**未脱敏**，如 `"18384891021"`）
    ///
    /// ## 用途
    /// "账号与安全"页发送验证码时使用——
    /// `mobile` 是脱敏号（`183****1021`），无法用于发短信。
    ///
    /// ## 后端字段
    /// `user/get_user_info` 返回的 `_mobile`（注意前缀下划线）。
    ///
    /// ## 类型兼容
    /// 后端可能返回 `Int`（如 `18384891021`）或 `String`（`"18384891021"`）——
    /// 本字段通过自定义解码统一处理。
    let realMobile: String?

    // MARK: - 扩展字段（备用）

    /// 是否已注销（`0` = 否，`1` = 是）
    let isCancel: Int?

    /// 会员等级名称（如 `"普通会员"`）
    let userLevelName: String?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case account
        case nickname
        case avatar
        case mobile
        case realName       = "real_name"
        case email
        case gender
        case birthday
        case realMobile     = "_mobile"     // ✅ 真实手机号
        case isCancel       = "is_cancel"
        case userLevelName  = "userlevel_name"
    }

    // MARK: - 自定义容错解码

    /// 每字段独立解码——任一字段失败不影响整体
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // 字符串字段：宽松解码（缺失 / null → nil）
        self.account       = Self.safeString(from: c, forKey: .account,       name: "account")
        self.nickname      = Self.safeString(from: c, forKey: .nickname,      name: "nickname")
        self.avatar        = Self.safeString(from: c, forKey: .avatar,        name: "avatar")
        self.mobile        = Self.safeString(from: c, forKey: .mobile,        name: "mobile")
        self.realName      = Self.safeString(from: c, forKey: .realName,      name: "real_name")
        self.email         = Self.safeString(from: c, forKey: .email,         name: "email")
        self.birthday      = Self.safeString(from: c, forKey: .birthday,      name: "birthday")
        self.userLevelName = Self.safeString(from: c, forKey: .userLevelName, name: "userlevel_name")

        // ✅ 真实手机号：兼容 Int / String
        //
        // - 场景 1：后端返回 String `"18384891021"`
        // - 场景 2：后端返回 Int `18384891021`
        //
        // 优先 String，再 fallback 到 Int 转 String。
        if let str = Self.safeString(from: c, forKey: .realMobile, name: "_mobile") {
            self.realMobile = str
        } else if let intVal = Self.safeInt(from: c, forKey: .realMobile, name: "_mobile") {
            self.realMobile = String(intVal)
        } else {
            self.realMobile = nil
        }

        // 数值字段：兼容 Int / String（后端 PHP 可能把 0 序列化为 "0"）
        self.id       = Self.safeInt(from: c, forKey: .id,       name: "id")
        self.gender   = Self.safeInt(from: c, forKey: .gender,   name: "gender")
        self.isCancel = Self.safeInt(from: c, forKey: .isCancel, name: "is_cancel")
    }

    // MARK: - 解码辅助

    /// 安全解码 `String`：失败 / 缺失 / 类型不符时返回 `nil` + 打日志
    private static func safeString(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys,
        name: String
    ) -> String? {
        do {
            return try container.decodeIfPresent(String.self, forKey: key)
        } catch {
            AppLog.profile.error(
                "UserDetailInfo.\(name, privacy: .public) 解码失败：\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    /// 安全解码 `Int`：兼容 `Int` / `String`（`"0"` → `0`）
    ///
    /// ## 为什么需要兼容 String？
    /// 后端 PHP 在某些版本 / 环境下会把整数序列化为字符串
    /// （例如 `"gender": "0"` 而非 `"gender": 0`）。
    /// 自动合成的 `decodeIfPresent(Int.self, ...)` 遇到字符串会抛 `typeMismatch`——
    /// 本方法先尝试 `Int`，失败再尝试 `String` 并 `Int(...)` 转换。
    private static func safeInt(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys,
        name: String
    ) -> Int? {
        // 1. Int（最常见）
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: key) {
            return intVal
        }
        // 2. String（PHP 后端可能序列化）
        if let strVal = try? container.decodeIfPresent(String.self, forKey: key) {
            if let parsed = Int(strVal) {
                return parsed
            }
            AppLog.profile.error(
                "UserDetailInfo.\(name, privacy: .public) 字符串转 Int 失败：\(strVal, privacy: .public)"
            )
            return nil
        }
        // 3. 字段缺失 / null / 其他类型 —— 静默返回 nil
        return nil
    }

    // MARK: - 展示辅助

    /// 用于展示的名称（昵称 → 真实姓名 → 脱敏手机号 → 默认）
    var displayName: String {
        if let nickname, !nickname.isEmpty { return nickname }
        if let realName, !realName.isEmpty { return realName }
        if let mobile, !mobile.isEmpty { return mobile }
        return "用户"
    }

    /// 是否有头像
    var hasAvatar: Bool {
        guard let avatar, !avatar.isEmpty else { return false }
        return true
    }
}

// ============================================================
// MARK: - 上传结果
// ============================================================

/// 上传接口的响应数据
///
/// ## 实际返回结构（后端 `upload/uploadFileOss`）
/// ```json
/// {
///   "code": 1,
///   "data": {
///     "data": {
///       "file": "https://xmsmej.oss-cn-hongkong.aliyuncs.com/m12323/2026-09-30/599e315bb091411ff1533e29d98f6ced.png",
///       "fileId": 12040505
///     },
///     "success": "上传成功AliOss"
///   },
///   "msg": "ok",
///   "time": 1790737309
/// }
/// ```
///
struct UploadResult: Decodable, Sendable {

    /// 文件 URL（完整 URL，可直接传给 `edit_user_info` 的 `avatar` 参数）
    var fileURL: String?

    /// 文件 ID（后端分配，可用于后续操作，如删除文件）
    ///
    /// - Note: 当前业务未使用，保留以备扩展。
    var fileID: Int?

    // MARK: - 主结构（标准返回）

    /// 主结构的根键
    private enum RootKeys: String, CodingKey {
        /// 内层文件对象 `{ file, fileId }`
        case data
        /// 操作结果描述（如 `"上传成功AliOss"`），暂不使用
        case success
    }

    /// 内层文件对象的键
    private enum FileKeys: String, CodingKey {
        /// 文件 URL
        case file
        /// 文件 ID
        case fileId
    }

    // MARK: - 兼容结构的键

    /// 兼容结构：`{ "url": "..." }`
    private enum CompatKeys: String, CodingKey {
        case url
    }

    // MARK: - 自定义解码

    /// 宽容解码：先尝试标准嵌套结构，再尝试兼容结构
    ///
    /// ## 解码优先级
    /// 1. **标准**：`{ data: { file, fileId }, success }` —— 当前后端实际结构
    /// 2. **String**：`data` 直接是 URL 字符串
    /// 3. **对象**：`{ url: "..." }` —— 兼容可能的结构变化
    /// 4. **兜底**：全部失败时 `fileURL = nil`
    init(from decoder: Decoder) throws {
        // 场景 1：标准嵌套结构 `{ data: { file: "...", fileId: 123 } }`
        if let root = try? decoder.container(keyedBy: RootKeys.self),
           let fileContainer = try? root.nestedContainer(keyedBy: FileKeys.self, forKey: .data) {
            self.fileURL = try? fileContainer.decodeIfPresent(String.self, forKey: .file)
            self.fileID  = try? fileContainer.decodeIfPresent(Int.self,    forKey: .fileId)

            if let fileURL, !fileURL.isEmpty {
                return
            }
        }

        // 场景 2：`data` 是 String（整个 data 层就是一个 URL）
        if let container = try? decoder.singleValueContainer(),
           let str = try? container.decode(String.self),
           !str.isEmpty {
            self.fileURL = str
            self.fileID  = nil
            return
        }

        // 场景 3：`data` 是 `{ "url": "..." }`
        if let container = try? decoder.container(keyedBy: CompatKeys.self),
           let url = try? container.decodeIfPresent(String.self, forKey: .url),
           !url.isEmpty {
            self.fileURL = url
            self.fileID  = nil
            return
        }

        // 场景 4：全部失败 —— 静默返回 nil，由上层抛 `.emptyData`
        AppLog.profile.error(
            "UploadResult 解码失败：未匹配任何已知结构（data.data.file / String / url）"
        )
        self.fileURL = nil
        self.fileID  = nil
    }
}

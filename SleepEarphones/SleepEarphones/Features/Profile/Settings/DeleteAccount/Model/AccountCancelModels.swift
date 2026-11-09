//
//  AccountCancelModels.swift
//  SleepEarphones
//

import Foundation

/// 注销账号详情模型（对应图2/图3 接口）
struct AccountCancelInfo: Decodable, Sendable {
    /// 注销记录 ID
    let aid: String?
    /// 用户昵称
    let userNickname: String?
    /// 用户头像
    let userAvatar: String?
    /// 手机号
    let userMobile: String?
    /// 注销原因选择 ID
    let cancelType: String?
    /// 创建时间
    let createTime: String?
    /// 状态：1待审核 2已注销 3被驳回
    let status: Int
    /// 注销原因（手动填写）
    let cancelReason: String?
    /// 注销原因（选择的文本）
    let cancelTypeText: String?
    
    enum CodingKeys: String, CodingKey {
        case aid
        case userNickname = "user_nickname"
        case userAvatar = "user_avatar"
        case userMobile = "user_mobile"
        case cancelType = "cancel_type"
        case createTime = "create_time"
        case status
        case cancelReason = "cancel_reason"
        case cancelTypeText = "cancel_type_text"
    }
    
    /// 自定义容错解码，兼容后端返回 Int 或 String
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        // 容错处理 aid
        if let intId = try? c.decode(Int.self, forKey: .aid) {
            self.aid = String(intId)
        } else {
            self.aid = try? c.decode(String.self, forKey: .aid)
        }
        
        self.userNickname = try? c.decode(String.self, forKey: .userNickname)
        self.userAvatar   = try? c.decode(String.self, forKey: .userAvatar)
        self.userMobile   = try? c.decode(String.self, forKey: .userMobile)
        
        // 容错处理 cancel_type
        if let intType = try? c.decode(Int.self, forKey: .cancelType) {
            self.cancelType = String(intType)
        } else {
            self.cancelType = try? c.decode(String.self, forKey: .cancelType)
        }
        
        self.createTime     = try? c.decode(String.self, forKey: .createTime)
        
        // 容错处理 status（图3中写的是 String[字符串]，但实际可能是 Int）
        if let intStatus = try? c.decode(Int.self, forKey: .status) {
            self.status = intStatus
        } else if let strStatus = try? c.decode(String.self, forKey: .status),
                  let parsed = Int(strStatus) {
            self.status = parsed
        } else {
            self.status = 0 // 默认未知状态
        }
        
        self.cancelReason   = try? c.decode(String.self, forKey: .cancelReason)
        self.cancelTypeText = try? c.decode(String.self, forKey: .cancelTypeText)
    }
    
    /// 是否在审核中
    var isReviewing: Bool { status == 1 }
    /// 是否被驳回
    var isRejected: Bool { status == 3 }
}

/// 注销原因模型（对应图1 接口）
struct CancelReason: Decodable, Sendable {
    /// 原因 ID
    let aid: String
    /// 原因名称
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case aid
        case name
    }
    
    /// 自定义容错解码
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        // ✅ 核心修复：接口返回的 aid 是 Int(1)，需要转成 String 方便后续传参
        if let intId = try? c.decode(Int.self, forKey: .aid) {
            self.aid = String(intId)
        } else if let strId = try? c.decode(String.self, forKey: .aid) {
            self.aid = strId
        } else {
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: [CodingKeys.aid], debugDescription: "aid 既不是 Int 也不是 String"))
        }
        
        self.name = try c.decode(String.self, forKey: .name)
    }
}

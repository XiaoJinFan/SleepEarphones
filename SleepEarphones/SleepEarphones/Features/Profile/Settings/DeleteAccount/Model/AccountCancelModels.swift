//
//  AccountCancelModels.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/11/5.
//

import Foundation

/// 注销账号详情模型
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
    
    /// 是否在审核中
    var isReviewing: Bool { status == 1 }
    /// 是否被驳回
    var isRejected: Bool { status == 3 }
}

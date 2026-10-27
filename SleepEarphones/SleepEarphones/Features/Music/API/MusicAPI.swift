//
//  MusicAPI.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/10.
//

import Foundation
import Alamofire

/// 音乐模块接口
///
/// ## 接口清单
/// | 接口 | 后端路径 | 用途 |
/// |---|---|---|
/// | `bannerList` | `641e624160dd0` | 顶部横幅轮播 |
/// | `categoryList` | `687720427240a` | 音乐分类列表 |
/// | `songList` | `6874cfc814dde` | 音乐列表（支持过滤条件） |
///
/// ## 调用方法
/// ```swift
/// // 普通音乐（categoryList 下钻）
/// MusicAPI.songList(freemusicsubcategory_id: "1", customWhiteNoise: nil)
///
/// // 自定义白噪音（首页卡片进入）
/// MusicAPI.songList(freemusicsubcategory_id: nil, customWhiteNoise: true)
/// ```
enum MusicAPI: APIRequest {

    // MARK: - Cases

    /// 拉取顶部横幅轮播
    case bannerList

    /// 拉取音乐分类列表（**含音乐数据**）
    case categoryList

    /// 拉取音乐列表
    ///
    /// - Parameters:
    ///   - freemusicsubcategory_id: 子分类 ID；传 `nil` 时不过滤
    ///   - customWhiteNoise: 是否只拉"自定义白噪音"
    ///                       - `true`：加 `custom_white_noise=1` 过滤
    ///                       - `nil` / `false`：不加该字段
    case songList(freemusicsubcategory_id: String?, customWhiteNoise: Bool?)

    // MARK: - APIRequest

    var path: String {
        switch self {
        case .bannerList:   return APIEndpoint.loopImage.rawValue
        case .categoryList: return APIEndpoint.musicType.rawValue
        case .songList:     return APIEndpoint.musicList.rawValue
        }
    }

    var method: HTTPMethod { .post }

    var encoding: ParameterEncoding { JSONEncoding.default }

    var parameters: [String: Any]? {
        switch self {
        case .bannerList, .categoryList:
            return nil

        case .songList(let freemusicsubcategory_id, let customWhiteNoise):
            var p: [String: Any] = [:]
            if let freemusicsubcategory_id, !freemusicsubcategory_id.isEmpty {
                p["freemusicsubcategory_id"] = freemusicsubcategory_id
            }
            if let customWhiteNoise, customWhiteNoise {
                p["custom_white_noise"] = "1"
            }
            return p.isEmpty ? nil : p
        }
    }
}

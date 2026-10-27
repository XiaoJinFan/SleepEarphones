//
//  MyDeviceViewModel.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/11.
//

import Foundation
import Combine

/// 我的设备视图模型
///
/// ## 职责
/// - 拉取设备列表（委托 `DeviceRepository`）
/// - 处理竞态（`requestToken`）
/// - 处理用户切换（登录 / 登出）
///
/// ## 竞态处理
/// 用单调递增的 `requestToken` 标识"当前有效的请求"：
/// - 每次发起新请求前 `&+= 1`
/// - 回调中比对令牌，过期回调直接丢弃
///
/// ## 用户切换处理
/// 登录 / 登出后 `AuthStore.userId` 会变化。若不清空旧数据，
/// 用户登出后可能短暂看到"上一账号的设备"。因此：
/// - `loadDevices` 里检测 `userId` 变化 → 清空 `devices` / `totalCount`
/// - `refreshIfUserChanged` 供 `viewWillAppear` 调用，处理"切回本页时用户已变"的场景
///
@MainActor
final class MyDeviceViewModel {

    // MARK: - Constants

    /// 每页条数
    private static let defaultPageSize: Int = 15

    // MARK: - Output

    /// 设备列表
    @Published private(set) var devices: [DeviceModel] = []

    /// 设备总数
    @Published private(set) var totalCount: Int = 0

    /// 是否正在加载（用于全屏菊花）
    @Published private(set) var isLoading: Bool = false

    /// 是否正在下拉刷新
    @Published private(set) var isRefreshing: Bool = false

    /// 错误信息
    @Published private(set) var errorMessage: String?

    /// 空数据状态
    var isEmpty: Bool {
        devices.isEmpty && !isLoading && !isRefreshing && errorMessage == nil
    }

    // MARK: - Private

    private let repository: DeviceRepositoryProtocol

    /// 当前进行中的请求（用于取消，避免竞态）
    ///
    /// - Note: 本 VM 只维护**一个**在飞请求，用单独属性持有即可；
    ///         无需 `Set<AnyCancellable>`。
    private var currentRequest: AnyCancellable?

    /// 请求身份令牌
    ///
    /// - Note: 使用 `&+=` 允许溢出回绕而非崩溃——
    ///         连续请求 2^64 次才回绕到 0，实际业务中不可能触发。
    private var requestToken: UInt64 = 0

    /// 上次加载时使用的 userId（用于检测用户切换）
    private var lastLoadedUserId: Int?

    // MARK: - Init

    /// 初始化
    /// - Parameter repository: 设备仓库，默认 `DeviceRepository()`
    init(repository: DeviceRepositoryProtocol = DeviceRepository()) {
        self.repository = repository
    }

    // MARK: - Input

    /// 加载设备列表
    ///
    /// ## 参数说明
    /// - `isRefresh: false`（默认）：**首次 / 主动加载**
    ///   - 若 `devices` 为空 → 显示全屏菊花（`isLoading = true`）
    ///   - 若 `devices` 非空 → 不显示任何加载指示（无感刷新）
    /// - `isRefresh: true`：**下拉刷新**
    ///   - 保留旧数据，显示下拉控件（`isRefreshing = true`）
    ///
    /// ## 竞态处理
    /// 1. 取消旧请求并递增令牌
    /// 2. 回调中比对令牌，过期回调丢弃
    ///
    /// ## 用户切换处理
    /// 若 `userId` 与上次不同（登录 / 登出后切换 Tab）：
    /// - 清空旧数据，避免"上一账号的设备"短暂显示
    ///
    /// - Parameter isRefresh: 是否为下拉刷新触发
    func loadDevices(isRefresh: Bool = false) {
        // 1. 取消旧请求并递增令牌
        currentRequest?.cancel()
        currentRequest = nil
        requestToken &+= 1
        let token = requestToken

        // 2. 清除错误信息
        errorMessage = nil

        // 3. 用户切换检测
        let currentUserId = AuthStore.shared.userId
        if hasUserChanged {
            AppLog.device.debug(
                "用户切换：\(self.lastLoadedUserId.map(String.init) ?? "nil", privacy: .public) → \(currentUserId, privacy: .public)，清空旧设备列表"
            )
            devices = []
            totalCount = 0
        }
        lastLoadedUserId = currentUserId

        // 4. 更新加载状态
        if isRefresh {
            isRefreshing = true
        } else if devices.isEmpty {
            isLoading = true
        }

        // 5. userId 转 String：> 0 才算有效用户，否则传 nil
        //    （Repository 会短路为空列表，不发起网络请求）
        let userIdString: String? = currentUserId > 0 ? "\(currentUserId)" : nil

        AppLog.device.debug(
            "发起设备列表请求：userId=\(userIdString ?? "nil", privacy: .private) token=\(token, privacy: .public)"
        )

        // 6. 发起请求
        currentRequest = repository.fetchDevices(
            userId: userIdString,
            page: 1,
            pageSize: Self.defaultPageSize
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                // 令牌校验：丢弃过期回调
                guard let self, self.requestToken == token else {
                    AppLog.device.debug("丢弃过期设备列表回调 token=\(token, privacy: .public)")
                    return
                }
                self.isLoading = false
                self.isRefreshing = false
                self.currentRequest = nil

                if case .failure(let error) = completion {
                    if case .cancelled = error { return }
                    AppLog.device.error(
                        "设备列表加载失败：\(error.logCode, privacy: .public)"
                    )
                    self.errorMessage = error.errorDescription ?? "加载失败，请稍后重试"
                }
            },
            receiveValue: { [weak self] result in
                // 令牌校验：丢弃过期回调
                guard let self, self.requestToken == token else { return }
                AppLog.device.debug(
                    "设备列表加载成功：\(result.devices.count, privacy: .public) 条，total=\(result.total, privacy: .public)"
                )
                self.devices = result.devices
                self.totalCount = result.total
            }
        )
    }

    /// 检测用户是否变化，变化了就重新加载
    ///
    /// - Note: 由 `viewWillAppear` 调用。
    ///         用于处理"登录 / 登出后切换 Tab 回来"的场景。
    ///
    /// ## 与 `loadDevices` 里的"用户切换检测"的关系
    /// - `loadDevices` 里的检查：**每次加载时都要执行**——
    ///   若用户变了则**清空数据**，防止旧账号设备闪现
    /// - `refreshIfUserChanged` 里的检查：**仅在变化时**才触发 `loadDevices`
    ///
    /// 两处判断条件相同（都通过 `hasUserChanged`），
    /// 但**触发时机与副作用不同**——因此不构成重复。
    func refreshIfUserChanged() {
        guard hasUserChanged else { return }

        AppLog.device.debug("refreshIfUserChanged 检测到用户切换，触发重新加载")
        loadDevices()
    }

    /// 清除错误
    ///
    /// - Note: `errorMessage` 是 `private(set)`，UI 层展示 Alert 后
    ///         需要调用此方法重置状态，避免重复弹窗。
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Helpers

    /// 当前用户是否与上次加载时不同
    ///
    /// ## 判断逻辑
    /// - `lastLoadedUserId == nil` → **从未加载过** → 视为"变化"（首次）
    /// - `lastLoadedUserId != AuthStore.userId` → **用户已切换** → 变化
    /// - 其他 → 未变化
    private var hasUserChanged: Bool {
        lastLoadedUserId != AuthStore.shared.userId
    }
}

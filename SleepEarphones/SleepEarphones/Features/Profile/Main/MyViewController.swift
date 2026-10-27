//
//  MyViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/5.
//

import UIKit
import Combine

/// 「我的」Tab 主页
///
/// ## 职责
/// - 展示用户头像 / 昵称（订阅 `UserProfileViewModel`）
/// - 展示设备数量（订阅 `MyDeviceViewModel`）
/// - 展示缓存大小（调 `CacheManager`）
/// - 承载各功能入口的导航（消息 / 设备 / 帮助 / 设置等）
///
/// ## 关于两个 ViewModel 的共享
/// - `deviceViewModel`：与 `MyDeviceViewController` **共享同一实例**——
///   避免"我的"页与"我的设备"页各自请求列表
/// - `viewModel`（用户资料）：与 `PersonalViewController` **共享同一实例**——
///   避免资料页保存后，返回"我的"页显示的还是旧头像 / 昵称
///
/// 共享方式：本页创建，通过 `init(viewModel:)` 注入给子页。
///
@MainActor
final class MyViewController: UIViewController {

    // MARK: - IBOutlet

    /// 个人头像
    @IBOutlet weak var personalAvatar: UIImageView!

    /// 个人昵称
    @IBOutlet weak var personalNickName: UILabel!

    /// 我的设备容器
    @IBOutlet weak var deviceContainer: UIView!

    /// 设备数量文案
    @IBOutlet weak var devicesNum: UILabel!

    /// 设备图片
    @IBOutlet weak var devicePicture: UIImageView!

    /// 当前缓存大小
    @IBOutlet weak var curCacheSize: UILabel!

    /// 帮助与反馈容器
    @IBOutlet weak var helpFeedContainer: UIView!

    /// 清除缓存容器
    @IBOutlet weak var clearCacheContainer: UIView!

    /// 系统设置容器
    @IBOutlet weak var moreSettingContainer: UIView!

    // MARK: - Properties

    /// 设备列表 ViewModel
    ///
    /// 1. **`@MainActor` 隔离**：`MyDeviceViewModel` / `UserProfileViewModel`
    ///    都是 `@MainActor` 类。属性初始化表达式（`let x = SomeMainActorClass()`）
    ///    在**非主线程**求值时会有 actor 隔离问题。
    ///    用 `lazy` 后，首次访问发生在 `viewDidLoad`（UIKit 保证主线程）——
    ///    天然满足 `@MainActor` 约束。
    ///
    /// 2. **避免 Storyboard 加载阶段的多余创建**：
    ///    `MainTabBarController` 会一次性实例化所有 Tab 的 root VC——
    ///    4 个 Tab 的 VM 若都"立即创建"，App 启动时会有不必要的初始化开销。
    ///    用 `lazy` 后，只有用户**真正进入**该 Tab 时才创建。
    ///
    /// 3. **共享性**：与 `MyDeviceViewController` 共享同一实例——
    ///    必须在本页持有，通过 `init(viewModel:)` 注入给子页。
    private lazy var deviceViewModel = MyDeviceViewModel()

    /// 用户资料 ViewModel
    ///
    /// - Note: 与 `PersonalViewController` 共享同一实例——
    ///         资料页保存后，"我的"页 `bindViewModel` 订阅的 `@Published`
    ///         会立即收到新值，自动刷新 UI。
    private lazy var viewModel = UserProfileViewModel(repository: UserProfileRepository())

    /// Combine 订阅容器
    private var cancellables = Set<AnyCancellable>()

    /// 上次布局时头像的宽度——用于避免重复设置 `cornerRadius`
    private var lastAvatarWidth: CGFloat = 0

    /// 用户资料刷新是否正在进行
    ///
    /// ## 与 `viewModel.isRefreshing` 的区别
    /// - `isRefreshing`（VM 内）：用于 UI（如未来下拉刷新指示器）
    /// - `isRefreshInFlight`（本页）：用于**防止重复触发**
    private var isRefreshInFlight = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()

        // 首屏触发一次设备列表请求
        //
        // - Note: 与 `MyDeviceViewController.viewDidLoad` 的请求**不冲突**——
        //         若用户先进入"我的"页，设备列表已加载；
        //         后续进入"我的设备"页时，`MyDeviceViewController` 会**再次**调用
        //         `loadDevices()`——这是**有意为之**：
        //         确保进入设备列表页时数据是**当下最新**的。
        //
        //         两次请求的 `requestToken` 机制会自动丢弃过期回调。
        deviceViewModel.loadDevices()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 主动恢复 tabBar（防止从 push 页 pop 回来时偶发未恢复）
        //
        // - Note: 与 Home / Music / Sleep 三页一致——
        //         本项目统一约定，不要单独删除某一处的实现。
        tabBarController?.tabBar.isHidden = false

        // 每次回到本页刷新缓存大小：
        // 用户可能在别处（如清理工具、设置页）改变了缓存占用，
        // 保持展示值与实际一致。
        refreshCacheSize()

        // 用户可能已登录 / 登出，检测是否需要刷新设备
        // （内部有 guard，userId 未变化时不会触发请求）
        deviceViewModel.refreshIfUserChanged()

        // 刷新用户资料（头像 / 昵称 / 真实账号信息）
        refreshUserProfile()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // 头像正圆：圆角 = 宽度的一半
        //
        // - Note: `viewDidLayoutSubviews` 会被多次调用（键盘弹出、旋转、
        //         cell 复用等），加缓存避免重复写入 `cornerRadius`——
        //         虽然写入本身开销很小，但赋值会触发 layer 属性变更与
        //         可能的离屏渲染判定，能省则省。
        let width = personalAvatar.bounds.width
        guard width != lastAvatarWidth else { return }
        lastAvatarWidth = width
        personalAvatar.layer.cornerRadius = width / 2
    }

    // MARK: - Setup

    /// 圆角、边框等外观设置
    ///
    /// - Note: 头像的圆角**不在**此处设置（需等布局完成），
    ///         见 `viewDidLayoutSubviews`。
    private func setupUI() {
        personalAvatar.clipsToBounds = true
        personalAvatar.contentMode = .scaleAspectFill

        // 容器圆角
        deviceContainer.layer.cornerRadius = AppSpacing.Corner.card
        moreSettingContainer.layer.cornerRadius = AppSpacing.Corner.card

        // 帮助与反馈 + 清除缓存合并为一个分组：上下分别圆角
        //
        // - Note: 视觉上这两个 container 拼成一张"卡片"，
        //         因此只给上/下圆角，中间保持直角。
        helpFeedContainer.layer.cornerRadius = AppSpacing.Corner.card
        helpFeedContainer.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        clearCacheContainer.layer.cornerRadius = AppSpacing.Corner.card
        clearCacheContainer.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    }

    // MARK: - Binding

    /// 订阅 ViewModel 的数据变化，自动刷新 UI
    ///
    /// ## 关于"与 `PersonalViewController` 的订阅重复"
    /// 两个 VC 都订阅了 `$avatarImage` / `$nickname`，
    /// 但**面向不同的 UI 目标**：
    ///
    /// | VC | 目标控件 | 尺寸 |
    /// |---|---|---|
    /// | `MyViewController` | `personalAvatar` | 60pt（导航栏附近） |
    /// | `PersonalViewController` | `avatarImageView` | 100pt（资料页） |
    ///
    /// 因此**不应合并**——订阅的内容虽相同，但绑定到不同视图。
    /// 强行抽象会引入"UI 绑定器"类，增加复杂度而收益不明显。
    ///
    /// 若未来出现**第三个**订阅方，再考虑抽公共方法。
    private func bindViewModel() {
        // 头像
        viewModel.$avatarImage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                self?.personalAvatar.image = image ?? AppImage.Local.avatarPlaceholder
            }
            .store(in: &cancellables)

        // 昵称
        viewModel.$nickname
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                self?.personalNickName.text = name
            }
            .store(in: &cancellables)

        // 设备数量
        deviceViewModel.$totalCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.devicesNum.text = "\(count)"
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    /// 点击消息按钮
    @IBAction func clickNewsBtnEvent(_ sender: Any) {
        let vc = MessageListViewController()
        navigationController?.pushViewController(vc, animated: true)
        AppLog.profile.debug("跳转消息中心")
    }

    /// 点击个人信息
    @IBAction func clickPersonalInfoBtnEvent(_ sender: Any) {
        // 共享 viewModel——资料页保存后本页订阅会立即刷新
        let personVC = PersonalViewController(viewModel: viewModel)
        personVC.title = "我的资料"
        navigationController?.pushViewController(personVC, animated: true)

        AppLog.profile.debug("跳转我的资料页")
    }

    /// 点击我的设备
    @IBAction func clickMyDeviceBtnEvent(_ sender: Any) {
        // 共享 deviceViewModel，避免重复请求
        let vc = MyDeviceViewController(viewModel: deviceViewModel)
        vc.title = "我的设备"
        navigationController?.pushViewController(vc, animated: true)

        AppLog.profile.debug("跳转我的设备页")
    }

    /// 点击帮助与反馈
    @IBAction func clickHelpFeedBackBtnEvent(_ sender: Any) {
        navigationController?.pushViewController(HelpFeedbackViewController(), animated: true)

        AppLog.profile.debug("跳转帮助与反馈页")
    }

    /// 点击联系我们
    @IBAction func clickContactUsBtnEvent(_ sender: Any) {
        navigationController?.pushViewController(ContactUsViewController(), animated: true)

        AppLog.profile.debug("跳转联系我们页")
    }

    /// 点击关于我们
    @IBAction func clickAboutUsBtnEvent(_ sender: Any) {
        ImagePrefetch.start([AppImage.Remote.companyLogo])

        navigationController?.pushViewController(AboutUsViewController(), animated: true)

        AppLog.profile.debug("跳转关于我们页")
    }

    // MARK: - Cache

    /// 刷新"当前缓存大小"文案
    ///
    /// - Note:
    ///   - `CacheManager.calculateCacheSize()` 内部在后台队列执行，
    ///     主线程 `await` 不会阻塞 UI。
    ///   - `Task {}` 会继承 `MyViewController` 的 `@MainActor` 隔离，
    ///     因此闭包内可直接写 `curCacheSize.text`，**无需**再标注 `@MainActor`。
    private func refreshCacheSize() {
        Task { [weak self] in
            let bytes = await CacheManager.calculateCacheSize()
            self?.curCacheSize.text = CacheManager.formattedSize(bytes)
        }
    }

    /// 点击清除缓存
    @IBAction func clickClearCacheBtnEvent(_ sender: Any) {
        // 清缓存是"半危险"操作：内容不可恢复但影响不大。
        // 使用红色按钮让用户稍加注意，但避免过度的破坏感。
        showConfirm(
            title: "清除缓存",
            message: "确定要清除全部缓存吗？",
            destructive: true
        ) { [weak self] in
            self?.performClearCache()
        }
    }

    /// 执行清除并更新 UI
    ///
    /// - Note: `CacheManager.clearCache()` 返回时磁盘操作**已完成**，
    ///         因此 `refreshCacheSize()` 不会读到旧值，
    ///         无需 sleep 或二次刷新。
    private func performClearCache() {
        Task { [weak self] in
            await CacheManager.clearCache()
            self?.refreshCacheSize()
            self?.showToast("清除成功")
        }
    }

    /// 点击系统设置
    @IBAction func clickSystemSettingBtnEvent(_ sender: Any) {
        let vc = SystemSettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
        AppLog.profile.debug("跳转系统设置页")
    }

    // MARK: - User Profile Refresh

    /// 刷新用户资料（带**防重入**保护）
    private func refreshUserProfile() {
        guard !isRefreshInFlight else {
            AppLog.profile.debug("用户资料刷新已在进行中，跳过本次触发")
            return
        }
        isRefreshInFlight = true

        Task { [weak self] in
            // 无论成功失败都清标志——避免"失败后永久阻塞"
            defer { self?.isRefreshInFlight = false }
            await self?.viewModel.refresh()
        }
    }
}

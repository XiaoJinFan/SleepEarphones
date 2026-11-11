//
//  MyViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/5.
//

import UIKit
import Combine

@MainActor
final class MyViewController: UIViewController {

    // MARK: - IBOutlet

    /// 个人头像
    @IBOutlet weak var personalAvatar: UIImageView!

    /// 个人昵称
    @IBOutlet weak var personalNickName: UILabel!

    /// 我的设备容器
    @IBOutlet weak var deviceContainer: UIView!
    
    /// 我的设备容器--标题
    @IBOutlet weak var deviceLab: UILabel!

    /// 设备数量文案（**纯数字，不参与国际化**）
    @IBOutlet weak var devicesNum: UILabel!

    /// 设备图片
    @IBOutlet weak var devicePicture: UIImageView!

    /// 当前缓存大小（**内容已本地化**——由 `CacheManager.formattedSize` 生成）
    @IBOutlet weak var curCacheSize: UILabel!

    /// 帮助与反馈容器
    @IBOutlet weak var helpFeedContainer: UIView!
    
    /// 帮助与反馈容器--标题
    @IBOutlet weak var helpFeedLab: UILabel!
    
    /// 联系我们容器--标题
    @IBOutlet weak var connectUSLab: UILabel!
    
    /// 关于我们容器--标题
    @IBOutlet weak var aboutUSLab: UILabel!
    
    /// 清除缓存容器
    @IBOutlet weak var clearCacheContainer: UIView!
    
    /// 清除缓存容器--标题
    @IBOutlet weak var clearCacheLab: UILabel!
    
    /// 系统设置容器
    @IBOutlet weak var moreSettingContainer: UIView!

    /// 系统设置容器--标题
    @IBOutlet weak var moreSettingLab: UILabel!
    
    // MARK: - Properties

    /// 设备列表 ViewModel
    private lazy var deviceViewModel = MyDeviceViewModel()

    /// 用户资料 ViewModel
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 主动恢复 tabBar（防止从 push 页 pop 回来时偶发未恢复）
        tabBarController?.tabBar.isHidden = false

        // 每次回到本页刷新缓存大小：
        // 用户可能在别处（如清理工具、设置页）改变了缓存占用，
        // 保持展示值与实际一致。
        refreshCacheSize()

        // 刷新用户资料（头像 / 昵称 / 真实账号信息）
        refreshUserProfile()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // 头像正圆：圆角 = 宽度的一半
        let width = personalAvatar.bounds.width
        guard width != lastAvatarWidth else { return }
        lastAvatarWidth = width
        personalAvatar.layer.cornerRadius = width / 2
    }

    // MARK: - Setup

    /// 圆角、边框等外观设置
    private func setupUI() {
        
        deviceLab.text = L("我的设备")
        helpFeedLab.text = L("帮助与反馈")
        connectUSLab.text = L("联系我们")
        aboutUSLab.text = L("关于我们")
        clearCacheLab.text = L("清除缓存")
        moreSettingLab.text = L("系统设置")
        
        personalAvatar.clipsToBounds = true
        personalAvatar.contentMode = .scaleAspectFill

        // 容器圆角
        deviceContainer.layer.cornerRadius = AppSpacing.Corner.card
        moreSettingContainer.layer.cornerRadius = AppSpacing.Corner.card

        // 帮助与反馈 + 清除缓存合并为一个分组：上下分别圆角
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

        // 昵称（**内容来自用户输入 / 后端，不参与国际化**）
        viewModel.$nickname
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                self?.personalNickName.text = name
            }
            .store(in: &cancellables)

        // 设备数量（**纯数字，不参与国际化**）
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
        personVC.title = L("我的资料")
        navigationController?.pushViewController(personVC, animated: true)

        AppLog.profile.debug("跳转我的资料页")
    }

    /// 点击我的设备
    @IBAction func clickMyDeviceBtnEvent(_ sender: Any) {
        // 共享 deviceViewModel，避免重复请求
        let vc = MyDeviceViewController(viewModel: deviceViewModel)
        vc.title = L("我的设备")
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
        //
        // **弹窗标题 / 正文已本地化**
        showConfirm(
            title: L("清除缓存"),
            message: L("确定要清除全部缓存吗？"),
            destructive: true
        ) { [weak self] in
            self?.performClearCache()
        }
    }

    /// 执行清除并更新 UI
    private func performClearCache() {
        Task { [weak self] in
            await CacheManager.clearCache()
            self?.refreshCacheSize()
            // **Toast 已本地化**
            self?.showToast(L("清除成功"))
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

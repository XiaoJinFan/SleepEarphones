//
//  MusicViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/5.
//

import UIKit
import SnapKit
import Combine


@MainActor
final class MusicViewController: UIViewController {

    // MARK: - IBOutlet

    /// 页面大标题"音乐"
    @IBOutlet weak var musicPageTitle: UILabel!

    /// 内容容器高度约束（**动态更新**）
    @IBOutlet weak var viewConstraintsHeight: NSLayoutConstraint!

    /// 顶部 Banner 容器
    @IBOutlet weak var bannerBgView: UIView!

    /// 顶部 Banner 图片
    @IBOutlet weak var bannerImageView: UIImageView!

    /// 自定义白噪音卡片
    @IBOutlet weak var customWhiteNoiseView: UIView!

    /// 自定义白噪音背景图
    @IBOutlet weak var customWhiteNoiseBgImageView: UIImageView!

    /// 自定义白噪音图标
    @IBOutlet weak var customWhiteNoiseIcon: UIImageView!

    /// 自定义白噪音标题
    @IBOutlet weak var customWhiteNoiseTitle: UILabel!

    /// 内置音频卡片
    @IBOutlet weak var builtInAudioView: UIView!

    /// 内置音频背景图
    @IBOutlet weak var builtInAudioBgImageView: UIImageView!

    /// 内置音频图标
    @IBOutlet weak var builtInAudioIcon: UIImageView!

    /// 内置音频标题
    @IBOutlet weak var builtInAudioTitle: UILabel!

    /// 音乐分类容器（内含分类标题 + CollectionView）
    @IBOutlet weak var musicCategoryView: UIView!

    /// 音乐分类标题（"默认"——将被隐藏，改用 section header）
    @IBOutlet weak var musicCategoryTitle: UILabel!

    /// 音乐列表
    @IBOutlet weak var musicCollectionView: UICollectionView!

    // MARK: - Constants

    /// CollectionView 布局参数
    ///
    /// - Important: 这些参数与 `MusicCardCell` 的**内部约束严格对应**——
    ///              改动任何一项都需要同步修改另一侧（见 `MusicCardCell` 注释）。
    private enum CardLayout {
        /// 卡片固定宽度
        static let cardWidth: CGFloat = 150
        /// 卡片之间的水平间距
        static let interitemSpacing: CGFloat = 14
        /// 封面与标题的间距
        static let titleSpacing: CGFloat = 8

        /// 标题高度 —— 基于字体行高动态计算（支持 Dynamic Type）
        static var titleHeight: CGFloat {
            ceil(AppFont.Body.secondary.lineHeight)
        }

        /// Section header 高度
        static let headerHeight: CGFloat = 50
        /// Section 之间的间距
        static let sectionSpacing: CGFloat = 30
    }

    // MARK: - 顶部固定部分高度拆解

    /// Banner 高度（storyboard: `L3j-eY-pBW.height = 180`）
    private static let bannerHeight: CGFloat = 180

    /// 入口卡片高度（storyboard: `pFn-aH-2ki.height = 95`）
    private static let entryCardHeight: CGFloat = 95

    /// 顶部各段之间的间距（storyboard 中两处 `constant = 30`）
    private static let topSectionSpacing: CGFloat = 30

    /// 顶部固定部分总高度 = banner + 间距 + 入口 + 间距 = 180 + 30 + 95 + 30 = **335**
    private static var topFixedHeight: CGFloat {
        bannerHeight + topSectionSpacing + entryCardHeight + topSectionSpacing
    }

    /// 底部间距
    private static let bottomSpacing: CGFloat = 30

    /// `musicCategoryTitle` 底部到 CollectionView 的间距
    private static let titleToCollectionSpacing: CGFloat = 5

    // MARK: - Properties

    private let viewModel = MusicViewModel()
    private var cancellables = Set<AnyCancellable>()

    /// `musicCategoryView` 的高度约束
    private var categoryHeightConstraint: NSLayoutConstraint?

    /// 上次计算的 CollectionView 内容高度
    private var lastCalculatedHeight: CGFloat = 0

    /// 是否已完成首次数据加载
    private var hasLoadedData = false

    /// 主滚动容器（用于设置 contentInset 避免迷你条遮挡）
    private weak var mainScrollView: UIScrollView?

    // MARK: - UI

    /// 迷你播放条（初始隐藏，播放中且返回本页时显示）
    private lazy var miniPlayerView: MiniPlayerView = {
        let v = MiniPlayerView()
        v.isHidden = true
        v.alpha = 0
        v.onTap = { [weak self] in
            self?.openPlayerFromMiniBar()
        }
        v.onPlayPause = {
            MusicPlayerManager.shared.toggle()
        }
        return v
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // storyboard 根 view 的直接子视图只有一个 UIScrollView——安全
        mainScrollView = view.subviews.compactMap { $0 as? UIScrollView }.first

        setupUI()
        setupCollectionView()
        setupEntryCards()
        setupMiniPlayer()
        bindViewModel()
        bindPlayerState()
        viewModel.loadData()

        AppLog.app.debug("MusicViewController 已加载")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 主动恢复 tabBar
        tabBarController?.tabBar.isHidden = false

        // 每次进入本页刷新迷你条（返回时可能状态有变化）
        refreshMiniPlayer()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // 数据加载后，每次 layout 变化都重新计算高度
        if hasLoadedData {
            recalculateContentHeight()
        }

        // 更新入口卡片渐变层 frame
        updateGradientFrames()
    }

    // MARK: - Setup

    private func setupUI() {
        // 1. 隐藏"默认"标签——分类名改由 section header 显示
        musicCategoryTitle.isHidden = true
        for constraint in musicCategoryTitle.constraints
            where constraint.firstAttribute == .height {
            constraint.constant = 0
        }

        // 2. 找到 musicCategoryView 的高度约束
        categoryHeightConstraint = musicCategoryView.constraints.first {
            $0.firstAttribute == .height
                && ($0.firstItem as? UIView) === musicCategoryView
        }

        if categoryHeightConstraint == nil {
            AppLog.ui.error("musicCategoryView 的 height 约束未找到，动态高度将失效")
        }
    }

    /// 配置迷你播放条
    private func setupMiniPlayer() {
        view.addSubview(miniPlayerView)
        miniPlayerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(MiniPlayerView.height)
        }

        // 预留 scrollView 底部 inset，避免内容被迷你条遮挡
        let inset = MiniPlayerView.height
        mainScrollView?.contentInset.bottom = inset
        mainScrollView?.verticalScrollIndicatorInsets.bottom = inset
    }

    /// 配置 CollectionView（替换为 CompositionalLayout）
    private func setupCollectionView() {
        musicCollectionView.backgroundColor = .clear
        musicCollectionView.showsVerticalScrollIndicator = false
        musicCollectionView.alwaysBounceVertical = false
        // 代码替换 storyboard 里的 FlowLayout → 支持多 section 横滑
        musicCollectionView.collectionViewLayout = makeCompositionalLayout()
        musicCollectionView.dataSource = self
        musicCollectionView.delegate = self

        // 注册 Cells
        musicCollectionView.register(
            MusicCardCell.self,
            forCellWithReuseIdentifier: MusicCardCell.reuseID
        )
        musicCollectionView.register(
            MusicSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: MusicSectionHeaderView.reuseID
        )
    }

    /// 配置入口卡片（标题 / 图标 / 渐变背景）
    private func setupEntryCards() {
        configureEntryCard(
            view: customWhiteNoiseView,
            bgImageView: customWhiteNoiseBgImageView,
            icon: customWhiteNoiseIcon,
            title: customWhiteNoiseTitle,
            entry: .customWhiteNoise
        )
        configureEntryCard(
            view: builtInAudioView,
            bgImageView: builtInAudioBgImageView,
            icon: builtInAudioIcon,
            title: builtInAudioTitle,
            entry: .builtInAudio
        )
    }

    /// 配置单个入口卡片
    ///
    /// - Parameters:
    ///   - view: 卡片容器视图
    ///   - bgImageView: storyboard 里的背景图（会被隐藏，改用渐变层）
    ///   - icon: 图标
    ///   - title: 标题
    ///   - entry: 入口枚举
    private func configureEntryCard(view: UIView, bgImageView: UIImageView, icon: UIImageView, title: UILabel, entry: MusicEntry) {
        // 隐藏 storyboard 里的背景图
        bgImageView.isHidden = true

        // 卡片圆角 + 裁剪
        view.layer.cornerRadius = AppSpacing.Corner.card
        view.layer.masksToBounds = true

        // 渐变背景
        let gradient = CAGradientLayer()
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.colors = [
            UIColor(hex: entry.gradientStartColorHex).cgColor,
            UIColor(hex: entry.gradientEndColorHex).cgColor
        ]
        gradient.name = "entryGradient"
        view.layer.insertSublayer(gradient, at: 0)

        // 图标（白色圆角底 + SF Symbol）
        icon.backgroundColor = .white
        icon.layer.cornerRadius = 8
        icon.clipsToBounds = true
        icon.contentMode = .center
        icon.image = UIImage(
            systemName: entry.iconName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        )
        icon.tintColor = UIColor(hex: entry.gradientStartColorHex)

        // 标题
        title.text = entry.title
        title.textColor = .white
        title.font = AppFont.Body.emphasized
    }

    /// 更新入口卡片渐变层的 frame
    private func updateGradientFrames() {
        [customWhiteNoiseView, builtInAudioView]
            .compactMap { $0 }
            .forEach { card in
                card.layer.sublayers?
                    .compactMap { $0 as? CAGradientLayer }
                    .filter { $0.name == "entryGradient" }
                    .forEach { $0.frame = card.bounds }
            }
    }

    // MARK: - CompositionalLayout

    /// 构造 CompositionalLayout（多分类横滑）
    private func makeCompositionalLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, _ in
            // 卡片尺寸
            let itemWidth = CardLayout.cardWidth
            let itemHeight = itemWidth + CardLayout.titleSpacing + CardLayout.titleHeight

            // Item
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(itemWidth),
                heightDimension: .absolute(itemHeight)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(
                top: 0, leading: 0, bottom: 0, trailing: CardLayout.interitemSpacing
            )

            // Group
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .absolute(itemWidth),
                heightDimension: .absolute(itemHeight)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                subitems: [item]
            )

            // Section
            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .continuous
            section.contentInsets = NSDirectionalEdgeInsets(
                top: 0,
                leading: 0,
                bottom: CardLayout.sectionSpacing,
                trailing: AppSpacing.horizontal - CardLayout.interitemSpacing
            )

            section.supplementariesFollowContentInsets = true

            // Section header
            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(CardLayout.headerHeight)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            header.contentInsets = .zero
            section.boundarySupplementaryItems = [header]

            return section
        }
    }

    // MARK: - Binding

    private func bindViewModel() {
        // Banner 更新
        viewModel.$banners
            .receive(on: DispatchQueue.main)
            .sink { [weak self] banners in
                self?.updateBanner(banners)
            }
            .store(in: &cancellables)

        // 分类列表更新 → 刷新 CollectionView + 重算高度
        viewModel.$sections
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.hasLoadedData = true
                self.musicCollectionView.reloadData()
                // 等 reloadData 完成后再算高度——否则 collectionView 内容尺寸未就绪
                DispatchQueue.main.async {
                    self.recalculateContentHeight()
                }
            }
            .store(in: &cancellables)

        // 错误提示
        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] msg in
                self?.presentError(msg)
            }
            .store(in: &cancellables)
    }

    /// 订阅播放器状态（刷新迷你条）
    private func bindPlayerState() {
        // 当前播放音乐变化
        MusicPlayerManager.shared.$currentSong
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMiniPlayer()
            }
            .store(in: &cancellables)

        // 播放 / 暂停状态变化
        MusicPlayerManager.shared.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMiniPlayer()
            }
            .store(in: &cancellables)
    }

    /// 更新 Banner 显示（**只显示第一张**）
    ///
    /// - Parameter banners: Banner 数组
    private func updateBanner(_ banners: [MusicBanner]) {
        guard let first = banners.first else {
            bannerImageView.image = AppImage.Local.emptyData
            return
        }
        bannerImageView.setImage(
            first.imageURL,
            placeholder: AppImage.Local.emptyData
        )
    }

    // MARK: - MiniPlayer

    /// 刷新迷你播放条（根据 Manager 状态决定显示 / 隐藏）
    private func refreshMiniPlayer() {
        let manager = MusicPlayerManager.shared

        guard let song = manager.currentSong else {
            hideMiniPlayer()
            return
        }

        miniPlayerView.configure(with: song, isPlaying: manager.isPlaying)
        showMiniPlayer()
    }

    /// 显示迷你条（带淡入动画）
    private func showMiniPlayer() {
        guard miniPlayerView.isHidden else { return }
        miniPlayerView.isHidden = false
        UIView.animate(withDuration: AppSpacing.Animation.standard) {
            self.miniPlayerView.alpha = 1
        }
    }

    /// 隐藏迷你条（带淡出动画）
    private func hideMiniPlayer() {
        guard !miniPlayerView.isHidden else { return }
        UIView.animate(withDuration: AppSpacing.Animation.standard) {
            self.miniPlayerView.alpha = 0
        } completion: { _ in
            self.miniPlayerView.isHidden = true
        }
    }

    /// 点击迷你条 → 重新进入播放页
    private func openPlayerFromMiniBar() {
        guard let song = MusicPlayerManager.shared.currentSong else { return }
        let playerVC = MusicPlayerViewController(song: song)
        navigationController?.pushViewController(playerVC, animated: true)
    }

    // MARK: - Dynamic Height

    /// 重算并更新 `viewConstraintsHeight` 与 `categoryHeightConstraint`
    ///
    /// - Note: `CardLayout.titleHeight` 是计算属性——每次调用都按当前
    ///         `AppFont.Body.secondary.lineHeight` 求值，Dynamic Type 天然跟随。
    private func recalculateContentHeight() {
        let collectionHeight = calculateCollectionHeight()

        guard abs(collectionHeight - lastCalculatedHeight) > 0.5 else { return }
        lastCalculatedHeight = collectionHeight

        let categoryViewHeight = collectionHeight + Self.titleToCollectionSpacing
        categoryHeightConstraint?.constant = categoryViewHeight

        let total = Self.topFixedHeight + categoryViewHeight + Self.bottomSpacing
        viewConstraintsHeight.constant = total

        AppLog.app.debug(
            "音乐页高度更新：sections=\(self.viewModel.sections.count, privacy: .public) collection=\(collectionHeight, privacy: .public) category=\(categoryViewHeight, privacy: .public) total=\(total, privacy: .public)"
        )
    }

    /// 计算 CollectionView 需要的总高度
    ///
    /// - Returns: 内容高度（含所有 section 的 header + items + 间距）
    ///
    /// - Note: `CardLayout.titleHeight` 为计算属性——
    ///         本方法每次调用都拿到**当前**字体行高对应的值，
    ///         保证与 `MusicCardCell` 内部布局对齐。
    private func calculateCollectionHeight() -> CGFloat {
        guard !viewModel.sections.isEmpty else { return 0 }

        let itemHeight = CardLayout.cardWidth
            + CardLayout.titleSpacing
            + CardLayout.titleHeight

        let sectionHeight = CardLayout.headerHeight
            + itemHeight
            + CardLayout.sectionSpacing

        return CGFloat(viewModel.sections.count) * sectionHeight
    }

    // MARK: - Error

    /// 弹出错误提示，关闭后清除错误
    ///
    /// - Parameter message: 错误信息
    private func presentError(_ message: String) {
        showAlert(
            message,
            title: "提示",
            onConfirm: { [weak self] in
                self?.viewModel.clearError()
            }
        )
    }

    // MARK: - IBActions

    /// 跳转自定义白噪音页面
    ///
    /// - Parameter sender: 触发事件的按钮
    @IBAction func jumpCustomWhiteNoiseVC(_ sender: Any) {
        AppLog.app.debug("跳转自定义白噪音页面")
        let vc = CustomNoiseViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    /// 跳转内置音频页面
    ///
    /// - Parameter sender: 触发事件的按钮
    @IBAction func jumpBuiltInAudioVC(_ sender: Any) {
        AppLog.app.debug("跳转内置音频页面")
        // TODO: push 内置音频页
    }
}

// MARK: - UICollectionViewDataSource

extension MusicViewController: UICollectionViewDataSource {

    /// Section 数量 = 分类数量
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        viewModel.sections.count
    }

    /// 每个 Section 的 item 数量
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.sections[section].items.count
    }

    /// Cell 配置
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: MusicCardCell.reuseID,
            for: indexPath
        ) as? MusicCardCell else {
            AppLog.ui.error("MusicCardCell 出队失败")
            return UICollectionViewCell()
        }
        let item = viewModel.sections[indexPath.section].items[indexPath.item]
        cell.configure(with: item)
        return cell
    }

    /// Section header 配置
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: MusicSectionHeaderView.reuseID,
                for: indexPath
              ) as? MusicSectionHeaderView else {
            return UICollectionReusableView()
        }
        header.configure(title: viewModel.sections[indexPath.section].title)
        return header
    }
}

// MARK: - UICollectionViewDelegate

extension MusicViewController: UICollectionViewDelegate {

    /// 点击卡片 → 拉取音频数据 → 进入播放页
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = viewModel.sections[indexPath.section].items[indexPath.item]
        AppLog.app.debug("点击音乐卡片：\(item.title, privacy: .public) id=\(item.id, privacy: .public)")
        fetchAndPlaySong(from: item)
    }

    /// 拉取目标子分类的音乐并进入播放页
    ///
    /// - Parameter item: 列表卡片数据
    private func fetchAndPlaySong(from item: MusicCardItem) {
        viewModel.fetchMatchedSong(subCategoryId: item.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard case .failure(let error) = completion else { return }
                    if case .cancelled = error { return }

                    AppLog.app.error("拉取音乐失败：\(error.logCode, privacy: .public)")

                    // .emptyData = 列表为空（无匹配也无兜底）→ 提示用户
                    if case .emptyData = error {
                        self?.showToast("该音乐暂时无法播放")
                    }
                },
                receiveValue: { [weak self] song in
                    guard let self else { return }
                    AppLog.app.debug(
                        "匹配成功：song.aid=\(song.id, privacy: .public)"
                    )

                    let playerVC = MusicPlayerViewController(song: song)
                    self.navigationController?.pushViewController(playerVC, animated: true)
                }
            )
            .store(in: &cancellables)
    }
}

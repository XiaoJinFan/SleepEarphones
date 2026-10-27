//
//  CustomNoiseViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/13.
//

import UIKit
import SnapKit
import Combine


@MainActor
final class CustomNoiseViewController: UIViewController {

    // MARK: - Layout Constants

    private enum Layout {

        // MARK: 网格
        /// 网格每行列数
        static let columns: Int = 4
        /// 网格水平 inset
        static let gridHorizontalInset: CGFloat = 20
        /// 网格项之间的间距
        static let gridSpacing: CGFloat = 20
        /// 网格项高度（图标 56 + 间距 8 + 名字 18 = 82）
        static let gridItemHeight: CGFloat = 82

        // MARK: 底部工具栏
        /// 底部工具栏高度（参考 xib：50pt）
        static let bottomBarHeight: CGFloat = 50
        /// 底部元素尺寸（设置 / 播放 / slot 均为 50×50）
        static let bottomItemSize: CGFloat = 50
        /// 底部工具栏左右 inset
        static let bottomBarHorizontalInset: CGFloat = 20
        /// 底部工具栏距 safeArea 底部
        static let bottomBarBottomInset: CGFloat = 20
        /// 3 个 slot 之间的间距
        static let slotSpacing: CGFloat = 20

        // MARK: Chip 列表
        /// Chip 列表高度（参考 xib：45pt）
        static let chipBarHeight: CGFloat = 45
        /// Chip 列表左右 inset
        static let chipBarHorizontalInset: CGFloat = 20
        /// Chip 之间的间距
        static let chipSpacing: CGFloat = 12
        /// Chip 列表与网格的间距
        static let chipToGridSpacing: CGFloat = 10
    }

    /// 背景色（统一深蓝）
    ///
    /// - Note: rgb(6, 13, 51) → hex `#060D33`
    private enum Background {
        static let hex = "#060D33"
    }

    // MARK: - Properties

    /// 音乐仓库（复用 shared）
    private let repository = MusicRepository.shared

    /// Combine 订阅容器
    private var cancellables = Set<AnyCancellable>()

    /// 全部歌曲（未过滤）
    private var allSongs: [MusicSong] = []

    /// 当前展示的歌曲（按 chip 过滤后）
    private var currentSongs: [MusicSong] = []

    /// 分类名列表（"全部" + 从数据里提取的 `subCategoryName`）
    ///
    /// - Note: 首项固定为"全部"，其余按**本地化字符串顺序**（拼音）排序——
    ///         与原代码 `Set<String>.sorted()`（Unicode 字典序）的区别：
    ///         Unicode 顺序与中文拼音无关，用户会看到"海浪铃声"排在"篝火夜宴"前面。
    private var categories: [String] = ["全部"]

    /// 当前选中的分类索引
    private var currentCategoryIndex: Int = 0

    /// 用户选中的歌曲（最多 3 个）
    private var selectedSongs: [MusicSong] = []

    /// 是否正在加载
    private var isLoading = false

    // MARK: - UI

    /// 分类 chip 列表（横向滑动）
    private lazy var categoryCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = Layout.chipSpacing
        layout.minimumLineSpacing = Layout.chipSpacing
        layout.sectionInset = UIEdgeInsets(
            top: 0,
            left: Layout.chipBarHorizontalInset,
            bottom: 0,
            right: Layout.chipBarHorizontalInset
        )

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.alwaysBounceHorizontal = true
        cv.dataSource = self
        cv.delegate = self
        cv.register(
            CustomNoiseCategoryCell.self,
            forCellWithReuseIdentifier: CustomNoiseCategoryCell.reuseID
        )
        return cv
    }()

    /// 网格列表
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = Layout.gridSpacing
        layout.minimumLineSpacing = Layout.gridSpacing
        layout.sectionInset = UIEdgeInsets(
            top: AppSpacing.sm,
            left: Layout.gridHorizontalInset,
            bottom: AppSpacing.sm,
            right: Layout.gridHorizontalInset
        )

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsVerticalScrollIndicator = false
        cv.dataSource = self
        cv.delegate = self
        cv.register(CustomNoiseCell.self, forCellWithReuseIdentifier: CustomNoiseCell.reuseID)
        return cv
    }()

    /// 加载菊花
    private lazy var loadingView: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(style: .medium)
        v.hidesWhenStopped = true
        v.color = .white
        return v
    }()

    // MARK: 底部工具栏

    /// 底部工具栏容器（**透明背景**——3 个元素独立绘制，参考 xib）
    private lazy var bottomBar: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }()

    /// 设置按钮（底部左侧）
    ///
    /// - Note: 50×50 深色圆形，与 xib 一致
    private lazy var settingsButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(
            UIImage(systemName: "slider.horizontal.3",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)),
            for: .normal
        )
        b.tintColor = .white
        b.backgroundColor = UIColor(hex: "#262C4D")
        b.layer.cornerRadius = Layout.bottomItemSize / 2
        b.clipsToBounds = true
        b.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        return b
    }()

    /// 3 个槽位容器（居中，均匀分布）
    ///
    /// - Note: 用 `UIStackView` 而非逐个约束——
    ///         居中逻辑由 StackView 天然处理，避免手算偏移。
    private lazy var slotStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = Layout.slotSpacing
        s.alignment = .center
        s.distribution = .fillEqually
        return s
    }()

    /// 3 个槽位视图
    private var slotViews: [CustomNoiseSlotView] = []

    /// 播放 / 暂停按钮（底部右侧）
    ///
    /// - Note: 50×50 深色圆形，与 xib 一致
    private lazy var playPauseButton: UIButton = {
        let b = UIButton(type: .system)
        b.tintColor = .white
        b.backgroundColor = UIColor(hex: "#262C4D")
        b.layer.cornerRadius = Layout.bottomItemSize / 2
        b.clipsToBounds = true
        b.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        return b
    }()

    // MARK: - Init

    init() {
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        bindPlayerState()
        loadCustomNoises()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 刷新播放按钮（此时 `MusicPlayerManager.isPlaying` 可能已变化）
        refreshPlayPauseButton()

        // 刷新槽位（幂等）——从其他页面返回时确保底部 3 个槽位与 `selectedSongs` 一致
        //
        // - Note: 从 `InsertMusicViewController` 返回时，`onSave` 回调已经
        //         调过 `refreshSlots`；此处多调一次成本极低（3 个 slot 的
        //         视图配置），但保证从任意入口返回的视觉一致性。
        refreshSlots()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor(hex: Background.hex)

        let titleLabel = UILabel()
        titleLabel.text = "自定义白噪音"
        titleLabel.font = AppFont.Title.card
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.sizeToFit()
        navigationItem.titleView = titleLabel

        navigationController?.navigationBar.tintColor = .white

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance

        // 右上角"添加音乐"按钮
        let addButton = UIButton(type: .system)
        addButton.setImage(
            UIImage(
                systemName: "music.note.list",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            ),
            for: .normal
        )
        addButton.tintColor = .white
        addButton.addTarget(self, action: #selector(addMusicTapped), for: .touchUpInside)
        addButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: addButton)

        // 页面内容
        view.addSubview(categoryCollectionView)
        view.addSubview(collectionView)
        view.addSubview(loadingView)
        view.addSubview(bottomBar)

        // 底部工具栏子视图
        bottomBar.addSubview(settingsButton)
        bottomBar.addSubview(slotStack)
        bottomBar.addSubview(playPauseButton)

        // 3 个槽位
        for _ in 0..<3 {
            let slot = CustomNoiseSlotView()
            slot.onTap = { [weak self] in
                self?.playSelected()
            }
            slotStack.addArrangedSubview(slot)
            slotViews.append(slot)
        }
    }

    private func setupConstraints() {
        // MARK: Chip 列表（顶部，高 45，左右 inset 20）
        categoryCollectionView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Layout.chipBarHeight)
        }

        // MARK: 底部工具栏（高 50，左右 inset 20，距 safeArea.bottom 20）
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
                .inset(Layout.bottomBarHorizontalInset)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
                .offset(-Layout.bottomBarBottomInset)
            make.height.equalTo(Layout.bottomBarHeight)
        }

        // MARK: 设置按钮（左，50×50）
        settingsButton.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.bottomItemSize)
        }

        // MARK: 播放按钮（右，50×50）
        playPauseButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.bottomItemSize)
        }

        // MARK: 3 个槽位（居中）
        slotStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(settingsButton.snp.trailing).offset(30)
            make.trailing.lessThanOrEqualTo(playPauseButton.snp.leading).offset(-30)
            make.height.equalTo(Layout.bottomItemSize)
        }

        // 每个 slot 固定尺寸
        slotViews.forEach { slot in
            slot.snp.makeConstraints { make in
                make.width.height.equalTo(Layout.bottomItemSize)
            }
        }

        // MARK: 网格列表（chip 下方 10pt，底部贴 bottomBar.top - 8）
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(categoryCollectionView.snp.bottom)
                .offset(Layout.chipToGridSpacing)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top).offset(-AppSpacing.xs)
        }

        // MARK: 加载菊花
        loadingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    // MARK: - Load

    /// 拉取自"自定义白噪音"接口
    private func loadCustomNoises() {
        guard !isLoading else { return }
        isLoading = true
        loadingView.startAnimating()

        repository.fetchCustomNoises()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.isLoading = false
                    self.loadingView.stopAnimating()

                    if case .failure(let error) = completion {
                        if case .cancelled = error { return }
                        AppLog.app.error("拉取自定义白噪音失败：\(error.logCode, privacy: .public)")
                        self.showToast("加载失败，请稍后重试")
                    }
                },
                receiveValue: { [weak self] songs in
                    guard let self else { return }
                    AppLog.app.debug("自定义白噪音加载成功：\(songs.count, privacy: .public) 条")

                    self.allSongs = songs
                    self.buildCategories()
                    self.applyFilter()
                    self.collectionView.reloadData()
                    self.categoryCollectionView.reloadData()
                }
            )
            .store(in: &cancellables)
    }

    /// 从数据中提取子分类名（如"林间漫步" / "篝火夜宴" / "海浪铃声"）
    ///
    /// - Note: 用 `subCategoryName`（`freemusicsubcategory_classification_name`），
    ///         不是 `categoryName`（`freemusicclassification_musictypename`）。
    ///
    /// ## 排序规则
    /// 使用 `localizedStandardCompare` 按**当前语言环境**排序——
    /// 中文按拼音顺序、英文按字母顺序、数字按大小顺序。
    ///
    /// 原代码 `Set<String>.sorted()` 按 **Unicode 字典序**——
    /// 中文汉字之间顺序与拼音完全无关，用户会看到"海浪铃声"排在
    /// "篝火夜宴"前面（"海" U+6D77 < "篝" U+7BE1）。
    private func buildCategories() {
        // 用 Set 去重（`nilIfEmpty` 过滤 nil / 空串）
        let nameSet = Set(
            allSongs.compactMap { $0.subCategoryName?.nilIfEmpty }
        )
        let sortedNames = nameSet.sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }

        categories = ["全部"] + sortedNames

        AppLog.app.debug(
            "自定义白噪音分类：\(self.categories.dropFirst().joined(separator: " / "), privacy: .public)"
        )
    }

    /// 按当前选中的子分类过滤
    private func applyFilter() {
        if currentCategoryIndex == 0 {
            currentSongs = allSongs
        } else {
            let name = categories[currentCategoryIndex]
            currentSongs = allSongs.filter { $0.subCategoryName == name }
        }
    }

    // MARK: - Actions

    /// Chip 切换
    ///
    /// - Parameter index: 目标分类索引
    private func selectCategory(at index: Int) {
        guard index != currentCategoryIndex else { return }
        guard index >= 0, index < categories.count else { return }

        currentCategoryIndex = index

        categoryCollectionView.reloadData()
        categoryCollectionView.scrollToItem(
            at: IndexPath(item: index, section: 0),
            at: .centeredHorizontally,
            animated: true
        )

        applyFilter()
        collectionView.reloadData()
        collectionView.setContentOffset(.zero, animated: false)
    }

    /// 右上角"添加音乐" → 进入获取音乐页
    @objc private func addMusicTapped() {
        AppLog.app.debug("点击添加音乐")

        let insertVC = InsertMusicViewController(
            allSongs: allSongs,
            preselected: selectedSongs
        )
        insertVC.onSave = { [weak self] selected in
            guard let self else { return }
            self.selectedSongs = Array(selected.prefix(3))
            self.refreshSlots()
            self.collectionView.reloadData()
        }
        navigationController?.pushViewController(insertVC, animated: true)
    }

    /// 底部设置按钮
    @objc private func settingsTapped() {
        AppLog.app.debug("点击自定义白噪音设置")
        showToast("设置功能开发中")
    }

    /// 播放 / 暂停
    @objc private func playPauseTapped() {
        MusicPlayerManager.shared.toggle()
        refreshPlayPauseButton()
    }

    /// 点击网格项：切换选中
    private func toggleSelection(_ song: MusicSong) {
        if let index = selectedSongs.firstIndex(where: { $0.id == song.id }) {
            // 已选中 → 取消
            selectedSongs.remove(at: index)
        } else {
            // 未选中 → 加入（最多 3 个）
            guard selectedSongs.count < 3 else {
                showToast("最多选择 3 个自定义白噪音")
                return
            }
            selectedSongs.append(song)
        }

        refreshSlots()
        collectionView.reloadData()
    }

    /// 刷新底部 3 个槽位
    private func refreshSlots() {
        for (index, slot) in slotViews.enumerated() {
            if index < selectedSongs.count {
                slot.configure(with: selectedSongs[index], order: index + 1)
            } else {
                slot.configureEmpty()
            }
        }
    }

    /// 播放已选中的第一个
    private func playSelected() {
        guard let first = selectedSongs.first else {
            showToast("请先选择自定义白噪音")
            return
        }
        MusicPlayerManager.shared.play(song: first)
        refreshPlayPauseButton()
    }

    // MARK: - Binding

    private func bindPlayerState() {
        MusicPlayerManager.shared.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshPlayPauseButton()
            }
            .store(in: &cancellables)
    }

    /// 刷新播放 / 暂停按钮图标
    private func refreshPlayPauseButton() {
        let iconName = MusicPlayerManager.shared.isPlaying ? "pause.fill" : "play.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        playPauseButton.setImage(
            UIImage(systemName: iconName, withConfiguration: config),
            for: .normal
        )
    }
}

// MARK: - UICollectionViewDataSource

extension CustomNoiseViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView === categoryCollectionView {
            return categories.count
        }
        return currentSongs.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        // MARK: Chip 列表
        if collectionView === categoryCollectionView {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CustomNoiseCategoryCell.reuseID,
                for: indexPath
            ) as? CustomNoiseCategoryCell else {
                return UICollectionViewCell()
            }
            cell.configure(
                title: categories[indexPath.item],
                isSelected: indexPath.item == currentCategoryIndex
            )
            return cell
        }

        // MARK: 网格列表
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CustomNoiseCell.reuseID,
            for: indexPath
        ) as? CustomNoiseCell else {
            return UICollectionViewCell()
        }

        let song = currentSongs[indexPath.item]
        let order = selectedSongs.firstIndex(where: { $0.id == song.id }).map { $0 + 1 }
        cell.configure(with: song, isSelected: order != nil, order: order)
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension CustomNoiseViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

        // MARK: Chip 列表（自适应宽度）
        if collectionView === categoryCollectionView {
            return CustomNoiseCategoryCell.size(for: categories[indexPath.item])
        }

        // MARK: 网格列表（4 列等分）
        //
        // - Note: 用 `max(0, ...)` 防御——首帧 layout 前
        //         `collectionView.bounds.width` 可能为 0，
        //         此时 `itemWidth` 会是负数（`0 - inset - spacing`），
        //         返回负尺寸会触发 UIKit 的内部异常。
        let totalWidth = collectionView.bounds.width
            - Layout.gridHorizontalInset * 2
            - Layout.gridSpacing * CGFloat(Layout.columns - 1)
        let itemWidth = max(0, totalWidth / CGFloat(Layout.columns))
        return CGSize(width: itemWidth, height: Layout.gridItemHeight)
    }
}

// MARK: - UICollectionViewDelegate

extension CustomNoiseViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        // MARK: Chip 点击 → 切换分类
        if collectionView === categoryCollectionView {
            selectCategory(at: indexPath.item)
            return
        }

        // MARK: 网格点击 → 切换选中
        let song = currentSongs[indexPath.item]
        toggleSelection(song)
    }
}

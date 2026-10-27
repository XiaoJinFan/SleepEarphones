//
//  MusicListViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/12.
//

import UIKit
import SnapKit
import Combine


@MainActor
final class MusicListViewController: UIViewController {

    // MARK: - Input

    /// 当前播放的歌曲（用于定位 segment + 高亮）
    private let currentSong: MusicSong?

    // MARK: - Properties

    /// 音乐仓库（复用单例）
    private let repository = MusicRepository.shared

    /// Combine 订阅容器
    private var cancellables = Set<AnyCancellable>()

    /// 分类列表（异步加载）
    private var sections: [MusicSection] = []

    /// 当前选中的 segment 索引
    private var currentSectionIndex: Int = 0

    /// 首次数据加载后，标记已定位过初始 segment
    private var didLocateInitialSegment = false

    // MARK: - UI

    /// 顶部主分类 segment（数据加载后填充 items）
    private lazy var segmentControl: UISegmentedControl = {
        let sc = UISegmentedControl()
        sc.selectedSegmentTintColor = AppColor.Brand.primary
        sc.setTitleTextAttributes([
            .foregroundColor: AppColor.Text.primary,
            .font: AppFont.Body.secondary
        ], for: .normal)
        sc.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: AppFont.Body.secondary
        ], for: .selected)
        sc.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        return sc
    }()

    /// 子分类列表
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.showsVerticalScrollIndicator = false
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 84
        tv.dataSource = self
        tv.delegate = self
        tv.register(
            MusicListItemCell.self,
            forCellReuseIdentifier: MusicListItemCell.reuseID
        )
        return tv
    }()

    /// 加载菊花
    private lazy var loadingView: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(style: .medium)
        v.hidesWhenStopped = true
        v.color = AppColor.Text.tertiary
        return v
    }()

    /// 空数据占位
    private lazy var emptyView: EmptyStateView = {
        let v = EmptyStateView(style: .music)
        v.isHidden = true
        return v
    }()

    /// 迷你播放条
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

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter currentSong: 当前播放的歌曲（可选）
    init(currentSong: MusicSong?) {
        self.currentSong = currentSong
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
        loadCategories()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 显示导航栏（返回时由 PlayerVC 恢复）
        navigationController?.setNavigationBarHidden(false, animated: animated)
        // 刷新迷你条
        refreshMiniPlayer()
        // 刷新列表（高亮可能有变化）
        tableView.reloadData()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "列表"
        view.backgroundColor = AppColor.Background.secondary
        navigationItem.backButtonDisplayMode = .minimal

        view.addSubview(segmentControl)
        view.addSubview(tableView)
        view.addSubview(loadingView)
        view.addSubview(emptyView)
        view.addSubview(miniPlayerView)
    }

    private func setupConstraints() {
        // Segment
        segmentControl.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(AppSpacing.sm)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.md)
            make.height.equalTo(36)
        }

        // 迷你条：底部贴 safeArea
        miniPlayerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(MiniPlayerView.height)
        }

        // 列表
        tableView.snp.makeConstraints { make in
            make.top.equalTo(segmentControl.snp.bottom).offset(AppSpacing.sm)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(miniPlayerView.snp.top)
        }

        // 预留迷你条空间
        tableView.contentInset.bottom = MiniPlayerView.height
        tableView.verticalScrollIndicatorInsets.bottom = MiniPlayerView.height

        // 加载菊花
        loadingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        // 空态
        emptyView.snp.makeConstraints { make in
            make.top.equalTo(segmentControl.snp.bottom).offset(AppSpacing.xl)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.md)
            make.bottom.equalTo(miniPlayerView.snp.top)
        }
    }

    // MARK: - Load

    /// 拉取分类列表（含音乐数据）
    private func loadCategories() {
        loadingView.startAnimating()

        repository.fetchCategories()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.loadingView.stopAnimating()

                    if case .failure(let error) = completion {
                        if case .cancelled = error { return }
                        AppLog.app.error(
                            "拉取分类失败：\(error.logCode, privacy: .public)"
                        )
                    }
                    // 无论成功失败都更新空态——失败时 sections 为空 → 显示空视图
                    self.updateEmptyState()
                },
                receiveValue: { [weak self] categories in
                    guard let self else { return }

                    // 转 sections（过滤空分组）
                    self.sections = categories
                        .map { MusicSection(id: $0.id, title: $0.name, items: $0.items) }
                        .filter { !$0.items.isEmpty }

                    AppLog.app.debug(
                        "列表页拉取分类成功：\(self.sections.count, privacy: .public) 个分组"
                    )

                    self.buildSegmentItems()
                    self.locateInitialSegment()
                    self.tableView.reloadData()
                    self.updateEmptyState()
                }
            )
            .store(in: &cancellables)
    }

    /// 用 sections 填充 segment items
    private func buildSegmentItems() {
        segmentControl.removeAllSegments()
        for (index, section) in sections.enumerated() {
            segmentControl.insertSegment(withTitle: section.title, at: index, animated: false)
        }
    }

    /// 根据 `currentSong` 定位初始 segment
    private func locateInitialSegment() {
        guard !didLocateInitialSegment else { return }
        didLocateInitialSegment = true

        guard let song = currentSong,
              let categoryId = song.categoryId,
              let index = sections.firstIndex(where: { $0.id == categoryId }) else {
            currentSectionIndex = 0
            segmentControl.selectedSegmentIndex = 0
            return
        }

        currentSectionIndex = index
        segmentControl.selectedSegmentIndex = index

        AppLog.app.debug(
            "列表页定位到 segment：index=\(index, privacy: .public) title=\(self.sections[index].title, privacy: .public)"
        )
    }

    // MARK: - Binding

    /// 订阅播放器状态
    ///
    /// ## 两个订阅的分工（性能优化）
    /// - `$currentSong`：曲目切换会影响**整表**的"正在播放行"高亮 → `reloadData()`
    /// - `$isPlaying`：播放/暂停只影响**当前行**的图标 → 只刷新可见行
    ///
    private func bindPlayerState() {
        MusicPlayerManager.shared.$currentSong
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMiniPlayer()
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        MusicPlayerManager.shared.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMiniPlayer()
                self?.refreshVisibleCells()
            }
            .store(in: &cancellables)
    }

    /// 只刷新可见 cell（用于播放 / 暂停状态变化）
    ///
    /// - Note: 不可见行的图标会在 `cellForRowAt` 时重新配置——无需提前刷新。
    private func refreshVisibleCells() {
        for indexPath in tableView.indexPathsForVisibleRows ?? [] {
            guard indexPath.row < currentItems.count else { continue }
            let item = currentItems[indexPath.row]
            let isPlaying = isCurrentPlaying(item)
            let isPaused = isPlaying && !MusicPlayerManager.shared.isPlaying

            (tableView.cellForRow(at: indexPath) as? MusicListItemCell)?.configure(
                with: item,
                isPlaying: isPlaying,
                isPaused: isPaused
            )
        }
    }

    // MARK: - Actions

    /// Segment 切换 → 刷新列表
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        currentSectionIndex = sender.selectedSegmentIndex
        tableView.reloadData()
        tableView.setContentOffset(.zero, animated: false)
    }

    // MARK: - Play Logic

    /// 播放指定子分类的音乐
    ///
    /// - Parameter item: 列表项（子分类）
    ///
    /// ## 行为
    /// - **若正在播放该子分类**：切换播放 / 暂停
    /// - **否则**：拉取音频 URL 并播放
    ///
    private func playSong(for item: MusicCardItem) {
        let manager = MusicPlayerManager.shared

        // 已在播放该子分类：切换播放 / 暂停
        if manager.currentSong?.subCategoryId == Int(item.id) {
            AppLog.app.debug("切换播放 / 暂停：\(item.title, privacy: .public)")
            manager.toggle()
            return
        }

        // 播放新的子分类：拉取音频 URL
        AppLog.app.debug(
            "播放子分类：\(item.title, privacy: .public) id=\(item.id, privacy: .public)"
        )

        repository.fetchMatchedSong(
            subCategoryId: item.id,
            customWhiteNoise: false
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                guard case .failure(let error) = completion else { return }
                if case .cancelled = error { return }

                AppLog.app.error("拉取音乐失败：\(error.logCode, privacy: .public)")

                // .emptyData = 拉取成功但列表为空 → 提示用户
                if case .emptyData = error {
                    self?.showToast("该音乐暂时无法播放")
                }
            },
            receiveValue: { [weak self] song in
                guard let self else { return }

                // 交给 Manager 播放
                MusicPlayerManager.shared.play(song: song)
                self.refreshMiniPlayer()
                self.tableView.reloadData()
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - MiniPlayer

    /// 刷新迷你播放条
    private func refreshMiniPlayer() {
        let manager = MusicPlayerManager.shared

        guard let song = manager.currentSong else {
            hideMiniPlayer()
            return
        }

        miniPlayerView.configure(with: song, isPlaying: manager.isPlaying)
        showMiniPlayer()
    }

    /// 显示迷你条
    private func showMiniPlayer() {
        guard miniPlayerView.isHidden else { return }
        miniPlayerView.isHidden = false
        UIView.animate(withDuration: AppSpacing.Animation.standard) {
            self.miniPlayerView.alpha = 1
        }
    }

    /// 隐藏迷你条
    private func hideMiniPlayer() {
        guard !miniPlayerView.isHidden else { return }
        UIView.animate(withDuration: AppSpacing.Animation.standard) {
            self.miniPlayerView.alpha = 0
        } completion: { _ in
            self.miniPlayerView.isHidden = true
        }
    }

    /// 点击迷你条 → 进入播放页
    private func openPlayerFromMiniBar() {
        guard let song = MusicPlayerManager.shared.currentSong else { return }
        let playerVC = MusicPlayerViewController(song: song)
        navigationController?.pushViewController(playerVC, animated: true)
    }

    // MARK: - Helpers

    /// 当前展示的子分类列表
    private var currentItems: [MusicCardItem] {
        guard currentSectionIndex < sections.count else { return [] }
        return sections[currentSectionIndex].items
    }

    /// 判断某行是否为"正在播放"
    ///
    /// - Parameter item: 列表项
    /// - Returns: 是否正在播放（用 `subCategoryId` 匹配）
    private func isCurrentPlaying(_ item: MusicCardItem) -> Bool {
        guard let song = MusicPlayerManager.shared.currentSong else { return false }
        return song.subCategoryId == Int(item.id)
    }

    /// 更新空态
    ///
    /// - 有数据（sections 非空）→ 隐藏空态
    /// - 无数据（sections 为空）→ 显示空态
    ///
    private func updateEmptyState() {
        emptyView.isHidden = !sections.isEmpty
    }
}

// MARK: - UITableViewDataSource

extension MusicListViewController: UITableViewDataSource {

    /// 行数
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        currentItems.count
    }

    /// Cell 配置
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: MusicListItemCell.reuseID,
            for: indexPath
        ) as? MusicListItemCell else {
            AppLog.ui.error("MusicListItemCell 出队失败")
            return UITableViewCell()
        }

        let item = currentItems[indexPath.row]
        let isPlaying = isCurrentPlaying(item)
        let isPaused = isPlaying && !MusicPlayerManager.shared.isPlaying

        cell.configure(
            with: item,
            isPlaying: isPlaying,
            isPaused: isPaused
        )
        return cell
    }
}

// MARK: - UITableViewDelegate

extension MusicListViewController: UITableViewDelegate {

    /// 点击行 → 播放对应音乐
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = currentItems[indexPath.row]
        playSong(for: item)
    }
}

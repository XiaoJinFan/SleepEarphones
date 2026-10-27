//
//  InsertMusicViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/13.
//

import UIKit
import SnapKit


@MainActor
final class InsertMusicViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        /// 底部按钮高度
        static let saveButtonHeight: CGFloat = 48
        /// 底部按钮水平 inset
        static let saveButtonHorizontalInset: CGFloat = AppSpacing.md
        /// 底部按钮距安全区底部
        static let saveButtonBottomInset: CGFloat = AppSpacing.md
    }

    // MARK: - Input

    /// 全部候选音乐
    private let allSongs: [MusicSong]

    /// 当前选中的（从上一页带入）
    private var selectedSongs: [MusicSong]

    /// 最多可选数量
    private let maxSelection: Int = 3

    // MARK: - Callback

    /// 保存回调（返回选中的音乐）
    var onSave: (([MusicSong]) -> Void)?

    // MARK: - UI

    /// 白色卡片容器
    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = AppColor.Background.card
        v.layer.cornerRadius = AppSpacing.Corner.card
        v.clipsToBounds = true
        return v
    }()

    /// 列表
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.showsVerticalScrollIndicator = false
        tv.rowHeight = 56
        tv.dataSource = self
        tv.delegate = self
        tv.register(InsertMusicCell.self, forCellReuseIdentifier: InsertMusicCell.reuseID)
        return tv
    }()

    /// 底部"保存"按钮
    private lazy var saveButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("保存", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = AppFont.Button.primary
        b.backgroundColor = UIColor(hex: "#2FA9E0")
        b.layer.cornerRadius = Layout.saveButtonHeight / 2
        b.clipsToBounds = true
        b.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        return b
    }()

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameters:
    ///   - allSongs: 全部候选音乐
    ///   - preselected: 已选中的音乐
    init(allSongs: [MusicSong], preselected: [MusicSong]) {
        self.allSongs = allSongs
        self.selectedSongs = preselected
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = AppColor.Text.primary
    }

    // MARK: - Setup

    private func setupUI() {
        title = "获取音乐"
        view.backgroundColor = AppColor.Background.secondary
        navigationItem.backButtonDisplayMode = .minimal

        view.addSubview(cardView)
        cardView.addSubview(tableView)
        view.addSubview(saveButton)
    }

    private func setupConstraints() {
        // 保存按钮
        saveButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Layout.saveButtonHorizontalInset)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-Layout.saveButtonBottomInset)
            make.height.equalTo(Layout.saveButtonHeight)
        }

        // 卡片
        cardView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(AppSpacing.sm)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.md)
            make.bottom.equalTo(saveButton.snp.top).offset(-AppSpacing.md)
        }

        // 列表
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - Actions

    /// 保存 → 回传选中的音乐
    @objc private func saveTapped() {
        AppLog.app.debug("保存自定义白噪音选择：\(self.selectedSongs.count, privacy: .public) 个")
        onSave?(selectedSongs)
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Helpers

    /// 判断某首歌是否已选中
    private func isSelected(_ song: MusicSong) -> Bool {
        selectedSongs.contains(where: { $0.id == song.id })
    }

    /// 切换选中状态
    private func toggleSelection(_ song: MusicSong) {
        if let index = selectedSongs.firstIndex(where: { $0.id == song.id }) {
            selectedSongs.remove(at: index)
        } else {
            guard selectedSongs.count < maxSelection else {
                showToast("最多选择 \(maxSelection) 个")
                return
            }
            selectedSongs.append(song)
        }
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension InsertMusicViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        allSongs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: InsertMusicCell.reuseID,
            for: indexPath
        ) as? InsertMusicCell else {
            return UITableViewCell()
        }

        let song = allSongs[indexPath.row]
        cell.configure(with: song, isSelected: isSelected(song))
        return cell
    }
}

// MARK: - UITableViewDelegate

extension InsertMusicViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let song = allSongs[indexPath.row]
        toggleSelection(song)
    }
}

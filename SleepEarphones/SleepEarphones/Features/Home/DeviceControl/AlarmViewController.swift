//
//  AlarmViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/30.
//

import UIKit
import SnapKit
import Combine

// MARK: - Model

/// 闹钟数据模型
struct AlarmModel: Identifiable, Equatable {

    /// 本地唯一标识
    ///
    /// - Note: 当前用 `UUID` 生成。接入后端后应改为后端返回的 `alarmId: Int`。
    let id: UUID

    /// 时间字符串（如 `"23:59"`）
    var time: String

    /// 是否启用
    var isEnabled: Bool

    init(id: UUID = UUID(), time: String, isEnabled: Bool = true) {
        self.id = id
        self.time = time
        self.isEnabled = isEnabled
    }
}

// MARK: - View Controller

/// 闹钟模式页
@MainActor
final class AlarmViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let rowHeight: CGFloat = 88
        static let bottomButtonHeight: CGFloat = 50
        static let bottomButtonBottomInset: CGFloat = 20
        static let tableViewTopInset: CGFloat = 10
        static let tableViewBottomSpacing: CGFloat = 10
    }

    // MARK: - Properties

    /// 闹钟数据源（Combine）
    @Published private var alarms: [AlarmModel] = []

    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.showsVerticalScrollIndicator = false
        tv.rowHeight = Layout.rowHeight
        tv.dataSource = self
        tv.delegate = self
        tv.register(AlarmCell.self, forCellReuseIdentifier: AlarmCell.reuseID)
        return tv
    }()

    private lazy var bottomButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(L("设置"), for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = AppFont.Button.primary
        btn.backgroundColor = AppColor.Brand.primary
        btn.layer.cornerRadius = AppSpacing.Corner.button
        btn.addTarget(self, action: #selector(bottomButtonTapped), for: .touchUpInside)
        return btn
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupUI()
        setupConstraints()
        setupBindings()
        loadMockData()
    }

    // MARK: - NavigationBar

    private func setupNavigationBar() {
        // 设置标题（**已本地化**）
        self.title = L("我的闹钟")

        // 配置透明导航栏
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: AppColor.Text.primary]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance

        // 返回按钮颜色
        navigationController?.navigationBar.tintColor = AppColor.Text.primary
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = AppColor.Background.secondary

        view.addSubview(tableView)
        view.addSubview(bottomButton)
    }

    private func setupConstraints() {
        // 底部按钮：保留左右 20pt 间距，距离底部安全区 20pt
        bottomButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
            make.height.equalTo(Layout.bottomButtonHeight)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
                .offset(-Layout.bottomButtonBottomInset)
        }

        // 列表：顶部留出 10pt
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
                .offset(Layout.tableViewTopInset)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomButton.snp.top)
                .offset(-Layout.tableViewBottomSpacing)
        }
    }

    // MARK: - Bindings

    private func setupBindings() {
        // 监听数据源变化，刷新列表
        $alarms
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func bottomButtonTapped() {
        AppLog.device.debug("点击闹钟设置按钮")
        // TODO: 跳转 `AlarmEditViewController`（添加 / 编辑闹钟页）
        //       当前仅为占位提示，等待后端 `changeClock` 接口就绪
        showToast(L("跳转添加/设置闹钟页面"))
    }

    // MARK: - Data

    /// 加载模拟数据
    private func loadMockData() {
        // 还原设计图中的三个 23:59
        self.alarms = [
            AlarmModel(time: "23:59", isEnabled: true),
            AlarmModel(time: "23:59", isEnabled: true),
            AlarmModel(time: "23:59", isEnabled: true)
        ]
    }
}

// MARK: - UITableViewDataSource

extension AlarmViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return alarms.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: AlarmCell.reuseID,
            for: indexPath
        ) as? AlarmCell else {
            AppLog.ui.error("AlarmCell 出队失败，检查 reuseID 注册")
            return UITableViewCell()
        }

        let alarm = alarms[indexPath.row]
        cell.configure(with: alarm)

        // 监听 Cell 内部开关的切换事件
        cell.onSwitchChanged = { [weak self] isOn in
            guard let self = self else { return }
            // 更新数据源（触发 @Published 的 didSet，从而驱动 Combine 刷新）
            if let index = self.alarms.firstIndex(where: { $0.id == alarm.id }) {
                self.alarms[index].isEnabled = isOn
                AppLog.device.debug("闹钟 \(alarm.time) 状态切换为: \(isOn)")
            }
        }

        return cell
    }
}

// MARK: - UITableViewDelegate

extension AlarmViewController: UITableViewDelegate {

    /// 侧滑删除
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // 1. 创建删除操作（标题已本地化）
        let deleteAction = UIContextualAction(
            style: .destructive,
            title: L("删除")
        ) { [weak self] _, _, completionHandler in
            guard let self = self else { return }

            // 2. 从数据源中移除（这会自动触发 $alarms 的 Combine 回调，刷新整个列表）
            self.alarms.remove(at: indexPath.row)

            // 3. 完成系统 UI 动画
            completionHandler(true)

            AppLog.device.debug("已删除闹钟，剩余数量: \(self.alarms.count)")
        }

        // 4. 设置图标
        deleteAction.image = UIImage(systemName: "trash")

        // 5. 允许执行删除的配置
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = true // 支持全滑删除
        return configuration
    }
}

// MARK: - AlarmCell

/// 闹钟列表单元格
@MainActor
final class AlarmCell: UITableViewCell {

    // MARK: - Constants

    static let reuseID = "AlarmCell"

    private enum Layout {
        static let cardMargin: CGFloat = 20
        static let cardPadding: CGFloat = 16
        static let iconSize: CGFloat = 56
        static let iconCornerRadius: CGFloat = AppSpacing.Corner.card
        static let cardCornerRadius: CGFloat = AppSpacing.Corner.card
        static let cardVerticalMargin: CGFloat = 6
        static let iconSymbolSize: CGFloat = 28
        static let timeToIconSpacing: CGFloat = 16
    }

    // MARK: - Callback

    /// 开关状态改变回调
    var onSwitchChanged: ((Bool) -> Void)?

    // MARK: - UI

    /// 白色卡片容器
    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = AppColor.Background.card
        v.layer.cornerRadius = Layout.cardCornerRadius
        v.clipsToBounds = true
        return v
    }()

    /// 蓝色图标背景
    private let iconContainerView: UIView = {
        let v = UIView()
        v.backgroundColor = AppColor.Brand.primary
        v.layer.cornerRadius = Layout.iconCornerRadius
        v.clipsToBounds = true
        return v
    }()

    /// 闹钟图标
    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .white
        iv.image = UIImage(
            systemName: "alarm",
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: Layout.iconSymbolSize,
                weight: .medium
            )
        )
        return iv
    }()

    /// 时间文本
    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Title.page
        l.textColor = AppColor.Text.primary
        return l
    }()

    /// 开关
    private let toggleSwitch: UISwitch = {
        let sw = UISwitch()
        sw.onTintColor = AppColor.Brand.primary
        return sw
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addSubview(iconContainerView)
        iconContainerView.addSubview(iconImageView)
        containerView.addSubview(timeLabel)
        containerView.addSubview(toggleSwitch)

        // 监听开关事件
        toggleSwitch.addTarget(self, action: #selector(switchToggled(_:)), for: .valueChanged)
    }

    private func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(Layout.cardVerticalMargin)
            make.leading.trailing.equalToSuperview().inset(Layout.cardMargin)
        }

        iconContainerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.cardPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.iconSize)
        }

        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Layout.iconSymbolSize + 2)
        }

        timeLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconContainerView.snp.trailing).offset(Layout.timeToIconSpacing)
            make.centerY.equalToSuperview()
        }

        toggleSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Layout.cardPadding)
            make.centerY.equalToSuperview()
        }
    }

    // MARK: - Configure

    func configure(with alarm: AlarmModel) {
        timeLabel.text = alarm.time
        toggleSwitch.isOn = alarm.isEnabled
    }

    // MARK: - Actions

    @objc private func switchToggled(_ sender: UISwitch) {
        onSwitchChanged?(sender.isOn)
    }
}

//
//  ToneSettingsViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/30.
//

import UIKit
import SnapKit
import Combine

/// 提示音设置页面
@MainActor
final class ToneSettingsViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        static let horizontalInset: CGFloat = AppSpacing.md
        static let cardCornerRadius: CGFloat = AppSpacing.Corner.card
        static let sectionSpacing: CGFloat = AppSpacing.md
        static let rowPadding: CGFloat = AppSpacing.md
        static let contentTopInset: CGFloat = AppSpacing.md
        static let contentBottomInset: CGFloat = 30
        static let rowVerticalPadding: CGFloat = AppSpacing.md
        static let textStackSpacing: CGFloat = 6
        static let titleToToggleSpacing: CGFloat = AppSpacing.md
        static let separatorHeight: CGFloat = AppSpacing.Border.hairline
    }

    // MARK: - Properties

    /// 各个开关的状态绑定（默认开启）
    @Published private var lowBatteryEnabled: Bool = true
    @Published private var powerOffEnabled: Bool = true
    @Published private var touchToneEnabled: Bool = true
    @Published private var modeSwitchEnabled: Bool = true

    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        return sv
    }()

    private lazy var contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Layout.sectionSpacing
        return stack
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupUI()
        setupConstraints()
        buildContent()
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        // 设置标题（**已本地化**）
        self.title = L("提示音")

        // 配置透明导航栏
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: AppColor.Text.primary]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = AppColor.Text.primary
    }

    private func setupUI() {
        view.backgroundColor = AppColor.Background.secondary

        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
    }

    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentStackView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
                .inset(UIEdgeInsets(
                    top: Layout.contentTopInset,
                    left: Layout.horizontalInset,
                    bottom: Layout.contentBottomInset,
                    right: Layout.horizontalInset
                ))
            make.width.equalTo(scrollView.frameLayoutGuide)
                .offset(-Layout.horizontalInset * 2)
        }
    }

    // MARK: - Build Content

    private func buildContent() {
        // 卡片 1：电量与关机
        let card1 = makeSectionCard(rows: [
            makeRow(
                title: L("低电量提示音"),
                subtitle: L("当电池电量低于 20%时，将听到提示音。"),
                switchPublisher: $lowBatteryEnabled,
                action: { [weak self] isOn in
                    guard self != nil else { return }
                    AppLog.device.debug("低电量提示音切换为: \(isOn)")
                    // TODO: 下发 BLE 指令 `deviceControl.setToneVolume` 或专用提示音开关
                }
            ),
            makeRow(
                title: L("关机提示音"),
                subtitle: L("当耳机自动关机时将听到提示音"),
                switchPublisher: $powerOffEnabled,
                action: { [weak self] isOn in
                    guard self != nil else { return }
                    AppLog.device.debug("关机提示音切换为: \(isOn)")
                    // TODO: 下发 BLE 指令
                }
            )
        ])

        // 卡片 2：敲击与模式切换
        let card2 = makeSectionCard(rows: [
            makeRow(
                title: L("敲击提示音"),
                subtitle: L("控制耳机时将听到提示音"),
                switchPublisher: $touchToneEnabled,
                action: { [weak self] isOn in
                    guard self != nil else { return }
                    AppLog.device.debug("敲击提示音切换为: \(isOn)")
                    // TODO: 下发 BLE 指令 `deviceControl.controllTouchFeedback(isOpen:)`
                }
            ),
            makeRow(
                title: L("模式切换提示音"),
                subtitle: L("当您主动在蓝牙模式与睡眠模式间切换时，将听到语音提示。"),
                switchPublisher: $modeSwitchEnabled,
                action: { [weak self] isOn in
                    guard self != nil else { return }
                    AppLog.device.debug("模式切换提示音切换为: \(isOn)")
                    // TODO: 下发 BLE 指令
                }
            )
        ])

        contentStackView.addArrangedSubview(card1)
        contentStackView.addArrangedSubview(card2)
    }
}

// MARK: - UI Factory Methods

extension ToneSettingsViewController {

    /// 生成单行视图（包含标题、副标题、Switch）
    ///
    /// - Parameters:
    ///   - title: 标题（**调用方需传入已本地化字符串**）
    ///   - subtitle: 副标题（**调用方需传入已本地化字符串**）
    ///   - switchPublisher: 绑定的状态 Publisher
    ///   - action: 开关切换回调（`nil` 时不响应）
    ///
    /// - Returns: 单行视图
    private func makeRow(title: String, subtitle: String, switchPublisher: Published<Bool>.Publisher, action: ((Bool) -> Void)?) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        // 左侧文本容器
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = Layout.textStackSpacing
        textStack.alignment = .fill

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppFont.Body.regular
        titleLabel.textColor = AppColor.Text.primary
        titleLabel.numberOfLines = 1

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = AppFont.Caption.regular
        subtitleLabel.textColor = AppColor.Text.secondary
        subtitleLabel.numberOfLines = 0

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        container.addSubview(textStack)

        // 右侧开关
        let toggle = UISwitch()
        toggle.onTintColor = AppColor.Brand.primary
        container.addSubview(toggle)

        // 绑定初始状态 + 后续变化
        switchPublisher
            .receive(on: DispatchQueue.main)
            .sink { isOn in
                toggle.setOn(isOn, animated: false)
            }
            .store(in: &cancellables)

        // 监听用户切换
        toggle.publisher(for: \.isOn)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { isOn in
                action?(isOn)
            }
            .store(in: &cancellables)

        // 布局约束
        textStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.rowPadding)
            make.top.equalToSuperview().offset(Layout.rowVerticalPadding)
            make.bottom.equalToSuperview().offset(-Layout.rowVerticalPadding)
            make.trailing.lessThanOrEqualTo(toggle.snp.leading)
                .offset(-Layout.titleToToggleSpacing)
        }

        toggle.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Layout.rowPadding)
            make.centerY.equalToSuperview()
        }

        return container
    }

    /// 生成白色圆角卡片
    ///
    /// - Parameter rows: 行视图数组
    /// - Returns: 圆角卡片（行之间用 hairline 分隔线）
    private func makeSectionCard(rows: [UIView]) -> UIView {
        let card = UIView()
        card.backgroundColor = AppColor.Background.card
        card.layer.cornerRadius = Layout.cardCornerRadius
        card.clipsToBounds = true

        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.spacing = 0
        stack.distribution = .fill
        card.addSubview(stack)

        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 为除第一行外的所有行添加顶部分割线
        for (index, row) in rows.enumerated() where index > 0 {
            let line = UIView()
            line.backgroundColor = AppColor.separator
            card.addSubview(line)

            line.snp.makeConstraints { make in
                make.top.equalTo(row.snp.top)
                make.leading.equalToSuperview().offset(Layout.rowPadding)
                make.trailing.equalToSuperview().offset(-Layout.rowPadding)
                make.height.equalTo(Layout.separatorHeight)
            }
        }

        return card
    }
}

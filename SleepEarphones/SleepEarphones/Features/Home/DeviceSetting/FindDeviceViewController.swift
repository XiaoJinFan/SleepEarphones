//
//  FindDeviceViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/30.
//

import UIKit
import SnapKit

/// 查找设备页面
@MainActor
final class FindDeviceViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        static let horizontalInset: CGFloat = AppSpacing.xl
        static let iconSize: CGFloat = 120
        static let playButtonSize: CGFloat = 56
        static let earsStackSpacing: CGFloat = AppSpacing.lg
        static let warningTopInset: CGFloat = AppSpacing.lg
        static let stackTopSpacing: CGFloat = 40
        static let playButtonTopSpacing: CGFloat = AppSpacing.lg
        static let earLabelTopSpacing: CGFloat = AppSpacing.md
        static let earLabelBottomInset: CGFloat = AppSpacing.sm
        static let playIconSize: CGFloat = 24
    }

    // MARK: - Properties

    /// 当前操作的耳朵枚举
    private enum EarType {
        case left
        case right

        /// 国际通用标识（**不参与国际化**）
        var title: String {
            switch self {
            case .left: return "L"
            case .right: return "R"
            }
        }

        /// 耳朵背景资源名（中文原值，**不参与国际化**）
        var imageName: String {
            switch self {
            case .left: return "左耳背景"
            case .right: return "右耳背景"
            }
        }
    }

    // MARK: - UI

    private lazy var warningLabel: UILabel = {
        let label = UILabel()
        label.text = L("请注意：不要佩戴耳机，以免影响您的听力")
        label.font = AppFont.Body.regular
        label.textColor = AppColor.Text.primary
        label.numberOfLines = 0
        return label
    }()

    /// 左右耳容器
    private lazy var earsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .top
        stack.spacing = Layout.earsStackSpacing
        return stack
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupUI()
        setupConstraints()
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        self.title = L("查找设备")

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: AppColor.Text.primary]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = AppColor.Text.primary
    }

    private func setupUI() {
        view.backgroundColor = AppColor.Background.secondary

        view.addSubview(warningLabel)
        view.addSubview(earsStackView)

        // 组装左耳 UI
        let leftEarView = createEarColumn(ear: .left)
        // 组装右耳 UI
        let rightEarView = createEarColumn(ear: .right)

        earsStackView.addArrangedSubview(leftEarView)
        earsStackView.addArrangedSubview(rightEarView)
    }

    private func setupConstraints() {
        warningLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(Layout.warningTopInset)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }

        earsStackView.snp.makeConstraints { make in
            make.top.equalTo(warningLabel.snp.bottom).offset(Layout.stackTopSpacing)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }
    }

    // MARK: - Factory Methods

    /// 创建单侧（左/右）的视图列
    ///
    /// - Parameter ear: 左耳 / 右耳
    /// - Returns: 包含耳机图、播放按钮、L/R 标识的视图
    private func createEarColumn(ear: EarType) -> UIView {
        let container = UIView()

        // 耳机图片
        let imageView = UIImageView()
        imageView.image = UIImage(named: ear.imageName)
        // 资源缺失时的兜底 tintColor——有 tintColor 时 image 若为 nil
        // 会显示为透明，避免"完全空白"
        imageView.tintColor = AppColor.Text.tertiary
        imageView.contentMode = .scaleAspectFit
        container.addSubview(imageView)

        // 播放按钮
        let playButton = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = AppColor.Brand.primary
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.image = UIImage(
            systemName: "play.fill",
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: Layout.playIconSize,
                weight: .bold
            )
        )
        playButton.configuration = config
        // 给按钮添加事件（用 UIAction 方便捕获 ear 参数）
        playButton.addAction(UIAction { [weak self] _ in
            self?.handlePlayTap(ear: ear)
        }, for: .touchUpInside)
        container.addSubview(playButton)

        // L/R 文本（国际通用标识，**不参与国际化**）
        let label = UILabel()
        label.text = ear.title
        label.font = AppFont.Title.section
        label.textColor = AppColor.Text.primary
        label.textAlignment = .center
        container.addSubview(label)

        // 布局约束
        imageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.height.equalTo(Layout.iconSize)
        }

        playButton.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(Layout.playButtonTopSpacing)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(Layout.playButtonSize)
            make.bottom.equalToSuperview().offset(-Layout.earLabelBottomInset)
        }

        label.snp.makeConstraints { make in
            make.top.equalTo(playButton.snp.bottom).offset(Layout.earLabelTopSpacing)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        return container
    }

    // MARK: - Actions

    /// 点击播放按钮，弹出音量提醒
    ///
    /// - Parameter ear: 目标耳朵
    private func handlePlayTap(ear: EarType) {
        AppLog.device.debug("点击查找设备，耳朵：\(ear.title)")

        let alertView = CustomAlertView(
            title: L("音量提醒"),
            message: L("即将播放高分贝音频。为了您的安全和舒适，请确保已取下耳机"),
            confirmTitle: L("继续"),
            cancelTitle: L("取消")
        )

        // 点击取消（或遮罩）
        alertView.onCancel = {
            AppLog.device.debug("取消播放查找声音")
        }

        // 点击继续
        alertView.onConfirm = { [weak self] in
            self?.startFindingSound(ear: ear)
        }

        alertView.show()
    }

    /// 开始播放查找声音
    ///
    /// - Parameter ear: 目标耳朵
    ///
    /// ## TODO: BLE 指令
    /// 实际下发指令应调用：
    /// ```swift
    /// LCBleDeviceManager.sharedInstance.deviceControl.startOrStopFindEarbuds(isFind: 1)
    /// ```
    private func startFindingSound(ear: EarType) {
        AppLog.device.debug("开始播放 \(ear.title) 查找声音")

        // TODO: 下发 BLE 指令，播放对应耳朵的声音
        showToast(L("开始播放%@查找声音", ear.title))
    }
}

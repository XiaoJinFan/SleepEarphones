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
        static let horizontalInset: CGFloat = 24
        static let iconSize: CGFloat = 120
        static let playButtonSize: CGFloat = 56
    }

    // MARK: - Properties

    /// 当前操作的耳朵枚举
    private enum EarType {
        case left
        case right
        
        var title: String {
            switch self {
            case .left: return "L"
            case .right: return "R"
            }
        }
    }

    // MARK: - UI

    private lazy var warningLabel: UILabel = {
        let label = UILabel()
        label.text = "请注意：不要佩戴耳机，以免影响您的听力"
        label.font = .systemFont(ofSize: 16, weight: .regular)
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
        stack.spacing = 20
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
        self.title = "查找设备"
        
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
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(20)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }
        
        earsStackView.snp.makeConstraints { make in
            make.top.equalTo(warningLabel.snp.bottom).offset(40)
            make.leading.trailing.equalToSuperview().inset(Layout.horizontalInset)
        }
    }

    // MARK: - Factory Methods

    /// 创建单侧（左/右）的视图列
    private func createEarColumn(ear: EarType) -> UIView {
        let container = UIView()
        
        // 耳机图片
        let imageView = UIImageView()
        imageView.image = ear == .left ? UIImage(named: "左耳背景") : UIImage(named: "右耳背景")
        imageView.tintColor = .lightGray
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
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        )
        playButton.configuration = config
        // 给按钮添加事件 (使用 UIAction 方便捕获 ear 参数)
        playButton.addAction(UIAction { [weak self] _ in
            self?.handlePlayTap(ear: ear)
        }, for: .touchUpInside)
        container.addSubview(playButton)
        
        // L/R 文本
        let label = UILabel()
        label.text = ear.title
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = AppColor.Text.primary
        label.textAlignment = .center
        container.addSubview(label)
        
        // 布局约束
        imageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.height.equalTo(Layout.iconSize)
        }
        
        playButton.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(Layout.playButtonSize)
            make.bottom.equalToSuperview().offset(-10)
        }
        
        label.snp.makeConstraints { make in
            make.top.equalTo(playButton.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        return container
    }

    // MARK: - Actions

    /// 点击播放按钮，弹出音量提醒
    private func handlePlayTap(ear: EarType) {
        AppLog.device.debug("点击查找设备，耳朵：\(ear.title)")
        
        let alertView = CustomAlertView(
            title: "音量提醒",
            message: "即将播放高分贝音频。为了您的安全和舒适，请确保已取下耳机",
            confirmTitle: "继续",
            cancelTitle: "取消"
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
    private func startFindingSound(ear: EarType) {
        AppLog.device.debug("开始播放 \(ear.title) 查找声音")
        
        // TODO: 下发 BLE 指令，播放对应耳朵的声音
        // 例如：LCBleDeviceManager.sharedInstance.deviceControl.startOrStopFindEarbuds(isFind: 1)
        
        // UI 反馈：可以将播放按钮图标改为暂停，代表正在播放
        // 此处简单起见，先弹个 Toast 提示
        showToast("开始播放\(ear.title)查找声音")
    }
}

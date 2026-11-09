//
//  FirmwareUpgradeViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/11/7.
//

import UIKit
import SnapKit
import Combine

@MainActor
final class FirmwareUpgradeViewController: UIViewController {

    // MARK: - Properties
    
    /// 外部传入的真实设备数据
    private let device: DeviceModel
    private let viewModel = FirmwareUpgradeViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    private var isUpgrading: Bool {
        if case .downloading = viewModel.state { return true }
        if case .upgrading = viewModel.state { return true }
        return false
    }

    // MARK: - UI

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        return sv
    }()
    
    private lazy var contentView = UIView()
    
    /// ✅ 动态：设备名称
    private lazy var deviceNameLabel: UILabel = {
        let l = UILabel()
        l.text = device.name // 使用真实设备名
        l.font = .systemFont(ofSize: 22, weight: .bold)
        l.textColor = .black
        l.textAlignment = .center
        return l
    }()
    
    /// ✅ 动态：状态提示（设备未连接 / 当前电量）
    private lazy var statusLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Caption.regular
        l.textAlignment = .center
        return l
    }()
    
    private lazy var currentVersionLabel: UILabel = {
        let l = UILabel()
        l.text = "当前版本：\(viewModel.currentVersion)"
        l.font = AppFont.Caption.regular
        l.textColor = AppColor.Text.tertiary
        l.textAlignment = .center
        return l
    }()
    
    /// ✅ 动态：设备图片
    private lazy var deviceImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        // 使用 Kingfisher 加载真实图片
        iv.setImage(device.imageURL, placeholder: AppImage.Device.defaultDeviceLarge)
        return iv
    }()
    
    private lazy var newVersionStack: UIStackView = {
        let dot = UIView()
        dot.backgroundColor = .systemRed
        dot.layer.cornerRadius = 5
        dot.snp.makeConstraints { make in
            make.width.height.equalTo(10)
        }
        
        let label = UILabel()
        label.text = "检测到新版本：\(viewModel.newVersion)"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .black
        
        let stack = UIStackView(arrangedSubviews: [dot, label])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()
    
    // MARK: - 底部组件
    private lazy var bottomContainer: UIView = {
        let v = UIView()
        v.backgroundColor = AppColor.Brand.primary
        v.layer.cornerRadius = 25
        v.clipsToBounds = true
        return v
    }()
    
    private lazy var upgradeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("下载并升级 (\(viewModel.packageSize))", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = AppFont.Button.primary
        btn.addTarget(self, action: #selector(upgradeTapped), for: .touchUpInside)
        return btn
    }()
    
    private lazy var progressBackground: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: "#D8D8D8")
        v.isHidden = true
        return v
    }()
    
    private lazy var progressForeground: UIView = {
        let v = UIView()
        v.backgroundColor = AppColor.Brand.primary
        return v
    }()
    
    private lazy var progressLabel: UILabel = {
        let l = UILabel()
        l.text = "升级中 0%"
        l.textColor = .white
        l.font = AppFont.Button.primary
        l.textAlignment = .center
        l.isHidden = true
        return l
    }()
    
    private var progressWidthConstraint: Constraint?

    // MARK: - Init & Lifecycle
    
    /// 初始化时需要传入设备
    init(device: DeviceModel) {
        self.device = device
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupUI()
        setupConstraints()
        bindViewModel()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent && isUpgrading {
            viewModel.cancelUpgrade()
        }
    }

    // MARK: - Setup
    
    private func setupNavigationBar() {
        title = L("固件升级")
        navigationController?.navigationBar.tintColor = .black
        
        let backItem = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(backTapped))
        navigationItem.leftBarButtonItem = backItem
    }

    private func setupUI() {
        view.backgroundColor = .white
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(deviceNameLabel)
        contentView.addSubview(statusLabel)
        contentView.addSubview(currentVersionLabel)
        contentView.addSubview(deviceImageView)
        contentView.addSubview(newVersionStack)
        
        view.addSubview(bottomContainer)
        bottomContainer.addSubview(upgradeButton)
        bottomContainer.addSubview(progressBackground)
        progressBackground.addSubview(progressForeground)
        bottomContainer.addSubview(progressLabel)
    }

    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
            make.bottom.equalTo(newVersionStack.snp.bottom).offset(40)
        }
        
        deviceNameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(40)
            make.centerX.equalToSuperview()
        }
        
        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(deviceNameLabel.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
        }
        
        currentVersionLabel.snp.makeConstraints { make in
            make.top.equalTo(statusLabel.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
        }
        
        deviceImageView.snp.makeConstraints { make in
            make.top.equalTo(currentVersionLabel.snp.bottom).offset(30)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(200)
        }
        
        newVersionStack.snp.makeConstraints { make in
            make.top.equalTo(deviceImageView.snp.bottom).offset(40)
            make.centerX.equalToSuperview()
        }
        
        bottomContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.height.equalTo(50)
        }
        
        upgradeButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        progressBackground.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        progressForeground.snp.makeConstraints { make in
            make.top.bottom.leading.equalToSuperview()
            progressWidthConstraint = make.width.equalTo(0).constraint
        }
        
        progressLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    // MARK: - Bindings
    
    private func bindViewModel() {
        // 监听升级状态
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.renderState(state)
            }
            .store(in: &cancellables)
            
        // 监听连接状态与电量变化
        Publishers.CombineLatest(viewModel.$isDeviceConnected, viewModel.$batteryLevel)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected, battery in
                guard let self = self else { return }
                if !isConnected {
                    // 截图中未连接时显示红字
                    self.statusLabel.text = "设备未连接"
                    self.statusLabel.textColor = .systemRed
                } else {
                    // 已连接时显示电量（低于30%标红）
                    self.statusLabel.text = "当前电量：\(battery)%"
                    self.statusLabel.textColor = battery < 30 ? .systemRed : AppColor.Text.secondary
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Render State
    
    private func renderState(_ state: FirmwareUpgradeState) {
        switch state {
        case .idle:
            bottomContainer.backgroundColor = AppColor.Brand.primary
            upgradeButton.isHidden = false
            upgradeButton.isEnabled = true
            progressBackground.isHidden = true
            progressLabel.isHidden = true
            progressWidthConstraint?.update(offset: 0)
            upgradeButton.setTitle("下载并升级 (\(viewModel.packageSize))", for: .normal)
            
        case .downloading(let progress):
            bottomContainer.backgroundColor = AppColor.Brand.primary
            upgradeButton.isHidden = true
            progressBackground.isHidden = true
            progressLabel.isHidden = false
            progressLabel.text = "下载固件中 \(Int(progress * 100))%"
            
        case .upgrading(let progress):
            bottomContainer.backgroundColor = UIColor(hex: "#D8D8D8")
            upgradeButton.isHidden = true
            progressBackground.isHidden = false
            progressLabel.isHidden = false
            progressLabel.text = "升级中 \(Int(progress * 100))%"
            
            let maxWidth = UIScreen.main.bounds.width - 40
            UIView.animate(withDuration: 0.1) {
                self.progressWidthConstraint?.update(offset: maxWidth * CGFloat(progress))
                self.view.layoutIfNeeded()
            }
            
        case .completed:
            bottomContainer.backgroundColor = AppColor.Brand.primary
            upgradeButton.isHidden = false
            upgradeButton.isEnabled = false
            progressBackground.isHidden = true
            progressLabel.isHidden = true
            upgradeButton.setTitle("升级完成", for: .normal)
            
            showAlert("固件升级成功！", title: "提示") { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
            
        case .failed(let errorMsg):
            bottomContainer.backgroundColor = AppColor.Brand.primary
            upgradeButton.isHidden = false
            upgradeButton.isEnabled = true
            progressBackground.isHidden = true
            progressLabel.isHidden = true
            upgradeButton.setTitle("重新升级", for: .normal)
            showAlert(errorMsg, title: "无法升级")
        }
    }

    // MARK: - Actions
    
    @objc private func upgradeTapped() {
        viewModel.startUpgrade()
    }
    
    @objc private func backTapped() {
        if isUpgrading {
            showConfirm(
                title: L("取消升级"),
                message: L("固件正在升级中，退出可能导致设备无法正常使用，确定要退出吗？"),
                destructive: true
            ) { [weak self] in
                self?.viewModel.cancelUpgrade()
                self?.navigationController?.popViewController(animated: true)
            }
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
}

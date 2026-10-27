//
//  AboutUsViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/16.
//

import UIKit
import SnapKit

/// 关于我们页
@MainActor
final class AboutUsViewController: UIViewController {

    // MARK: - Layout 常量

    private enum Layout {
        /// Logo 尺寸（根据设计稿）
        static let logoWidth: CGFloat = 258
        static let logoHeight: CGFloat = 54

        /// Logo 垂直居中偏移（向上偏 130pt）
        static let logoCenterYOffset: CGFloat = -130
    }

    // MARK: - UI

    /// 公司 logo
    private let logoImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = AppImage.Local.logoPlaceholder
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    /// 版本号（可点击进入证照信息）
    private let versionLabel: UILabel = {
        let l = UILabel()
        // 版本号在 viewDidLoad 中动态设置
        l.font = AppFont.Body.secondary
        l.textColor = AppColor.Text.primary
        l.textAlignment = .center
        l.isUserInteractionEnabled = true   // 允许点击手势
        return l
    }()

    /// 版权信息
    ///
    /// - Note: 年份动态取当前日历年，避免跨年后过期。
    private let copyrightLabel: UILabel = {
        let l = UILabel()
        let year = Calendar.current.component(.year, from: Date())
        l.text = "copyright©\(year) 睡眠耳机"
        l.font = AppFont.Caption.regular
        l.textColor = AppColor.Text.secondary
        l.textAlignment = .center
        return l
    }()

    // MARK: - Init

    /// 初始化
    ///
    /// - Note: push 时自动隐藏 tabBar，pop 时自动恢复。
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
        setupActions()
        loadRemoteLogo()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "关于我们"
        view.backgroundColor = AppColor.Background.primary
        navigationItem.backButtonDisplayMode = .minimal

        // 动态设置版本号（不硬编码）
        versionLabel.text = "当前版本 \(DeviceInfo.appVersion)"

        view.addSubview(logoImageView)
        view.addSubview(versionLabel)
        view.addSubview(copyrightLabel)
    }

    private func setupConstraints() {
        logoImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(Layout.logoCenterYOffset)
            make.width.equalTo(Layout.logoWidth)
            make.height.equalTo(Layout.logoHeight)
        }

        versionLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(logoImageView.snp.bottom).offset(AppSpacing.xl)
        }

        copyrightLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-AppSpacing.lg)
        }
    }

    private func setupActions() {
        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(versionLabelTapped)
        )
        versionLabel.addGestureRecognizer(tapGesture)
    }

    // MARK: - Remote Logo

    /// 加载远程 logo
    private func loadRemoteLogo() {
        logoImageView.setImage(
            AppImage.Remote.companyLogo,
            placeholder: AppImage.Local.logoPlaceholder
        )
    }

    // MARK: - Actions

    /// 点击版本号 → 进入证照信息页
    @objc private func versionLabelTapped() {
        // 预加载证照图后再 push，让目标页几乎瞬显
        ImagePrefetch.start([AppImage.Remote.licenseCertificate])

        let vc = LicenseInfoViewController()
        navigationController?.pushViewController(vc, animated: true)

        AppLog.profile.debug("跳转证照信息页")
    }
}

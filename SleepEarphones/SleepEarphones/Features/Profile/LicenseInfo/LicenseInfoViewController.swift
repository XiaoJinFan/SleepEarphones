//
//  LicenseInfoViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/16.
//

import UIKit
import SnapKit

/// 证照信息页
@MainActor
final class LicenseInfoViewController: UIViewController {

    // MARK: - 文案常量

    /// 证照信息文案
    ///
    /// - Note: 抽成常量便于集中修改；
    ///         若未来从后端返回，替换 `Info.xxx` 的赋值来源即可。
    private enum Info {
        /// 备案服务号
        static let recordNumber  = "备案服务号：沪ICP备15226020号-8"
        /// 电信业务经营许可证号
        static let licenseNumber = "电信业务经营许可证：沪A2-20240226"
    }

    // MARK: - Layout 常量

    private enum Layout {
        /// 证照图宽高比（接近 A4 竖版比例）
        ///
        /// - Note: 与设计稿一致。若未来证照图换成不同比例，只需改此常量。
        static let certificateAspectRatio: CGFloat = 0.62
    }

    // MARK: - UI

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.backgroundColor = AppColor.Background.primary
        return sv
    }()

    private let contentView = UIView()

    /// 备案服务号
    private let recordNumberLabel: UILabel = {
        let l = UILabel()
        l.text = Info.recordNumber
        l.font = AppFont.Body.emphasized
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 0
        return l
    }()

    /// 电信业务经营许可证号
    private let licenseNumberLabel: UILabel = {
        let l = UILabel()
        l.text = Info.licenseNumber
        l.font = AppFont.Body.emphasized
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 0
        return l
    }()

    /// 证照图片
    ///
    /// - Note:
    ///   - `contentMode = .scaleAspectFit` 保证整张证照完整可见，
    ///     不裁切边缘信息（证照可能有边框、印章贴边）。
    ///   - 占位图用 `emptyData`——证照图不是 logo，用 logo 占位不贴切。
    private let certificateImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = AppImage.Local.emptyData
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.layer.cornerRadius = AppSpacing.Corner.medium
        return iv
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
        loadCertificateImage()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "证照信息"
        view.backgroundColor = AppColor.Background.primary
        navigationItem.backButtonDisplayMode = .minimal

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(recordNumberLabel)
        contentView.addSubview(licenseNumberLabel)
        contentView.addSubview(certificateImageView)
    }

    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // UIScrollView 内容布局标准模式：
        // - `contentLayoutGuide`：内容高度由子视图撑开
        // - `frameLayoutGuide`：内容宽度等于可视宽度（防横向滚动）
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        recordNumberLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(AppSpacing.lg)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
        }

        licenseNumberLabel.snp.makeConstraints { make in
            make.top.equalTo(recordNumberLabel.snp.bottom).offset(AppSpacing.md)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
        }

        // 证照图：宽高比由 `Layout.certificateAspectRatio` 控制
        certificateImageView.snp.makeConstraints { make in
            make.top.equalTo(licenseNumberLabel.snp.bottom).offset(AppSpacing.md)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
            make.height.equalTo(certificateImageView.snp.width)
                .multipliedBy(Layout.certificateAspectRatio)
            // 撑开 contentView 底部
            make.bottom.equalToSuperview().offset(-AppSpacing.lg)
        }
    }

    // MARK: - 加载证照图

    /// 加载证照图片
    ///
    /// - Note: 由 `AboutUsViewController` 在 push 前预取，
    ///         通常直接命中缓存；若网络失败，仅保留占位图，不弹错。
    ///         证照图不是关键信息，失败时用户可退出重进本页重试。
    private func loadCertificateImage() {
        certificateImageView.setImage(AppImage.Remote.licenseCertificate, placeholder: AppImage.Local.emptyData) { result in
            // 加载失败时保留占位图，不弹错（避免干扰用户浏览文字信息）
            if case .failure(let error) = result {
                AppLog.profile.error(
                    "证照图加载失败：\(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}

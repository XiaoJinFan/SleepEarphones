//
//  LicenseInfoViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/16.
//

import UIKit
import SnapKit

@MainActor
final class LicenseInfoViewController: UIViewController {

    // MARK: - 文案常量

    /// 证照信息文案
    private enum Info {
        /// 备案服务号（**法定编号，不翻译**）
        static let recordNumber  = "沪ICP备15226020号-8"

        /// 电信业务经营许可证号（**法定编号，不翻译**）
        static let licenseNumber = "沪A2-20240226"
    }

    // MARK: - Layout 常量

    private enum Layout {
        /// 证照图宽高比（接近 A4 竖版比例）
        static let certificateAspectRatio: CGFloat = 0.62

        /// 顶部间距
        static let topInset: CGFloat = AppSpacing.lg

        /// 两个编号之间的间距
        static let labelSpacing: CGFloat = AppSpacing.md

        /// 证照图与编号的间距
        static let imageTopSpacing: CGFloat = AppSpacing.md

        /// 水平 inset
        static let horizontalInset: CGFloat = AppSpacing.lg

        /// 底部间距
        static let bottomInset: CGFloat = AppSpacing.lg
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
        // 文案在 `configureLabels()` 中动态设置（**通过 L(...) 本地化**）
        l.font = AppFont.Body.emphasized
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 0
        return l
    }()

    /// 电信业务经营许可证号
    private let licenseNumberLabel: UILabel = {
        let l = UILabel()
        // 文案在 `configureLabels()` 中动态设置（**通过 L(...) 本地化**）
        l.font = AppFont.Body.emphasized
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 0
        return l
    }()

    /// 证照图片
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
        configureLabels()
        loadCertificateImage()
    }

    // MARK: - Setup

    private func setupUI() {
        // **导航标题已本地化**
        title = L("证照信息")
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
            make.top.equalToSuperview().offset(Layout.topInset)
            make.leading.trailing.equalToSuperview()
                .inset(Layout.horizontalInset)
        }

        licenseNumberLabel.snp.makeConstraints { make in
            make.top.equalTo(recordNumberLabel.snp.bottom)
                .offset(Layout.labelSpacing)
            make.leading.trailing.equalToSuperview()
                .inset(Layout.horizontalInset)
        }

        // 证照图：宽高比由 `Layout.certificateAspectRatio` 控制
        certificateImageView.snp.makeConstraints { make in
            make.top.equalTo(licenseNumberLabel.snp.bottom)
                .offset(Layout.imageTopSpacing)
            make.leading.trailing.equalToSuperview()
                .inset(Layout.horizontalInset)
            make.height.equalTo(certificateImageView.snp.width)
                .multipliedBy(Layout.certificateAspectRatio)
            // 撑开 contentView 底部
            make.bottom.equalToSuperview().offset(-Layout.bottomInset)
        }
    }

    /// 配置编号 Label 文案（**已本地化**）
    ///
    /// ## 文案结构
    /// ```
    /// "备案服务号：沪ICP备15226020号-8"
    ///  ↑ 前缀（翻译）   ↑ 编号（原样）
    /// ```
    private func configureLabels() {
        recordNumberLabel.text = L("备案服务号：%@", Info.recordNumber)
        licenseNumberLabel.text = L("电信业务经营许可证：%@", Info.licenseNumber)
    }

    // MARK: - 加载证照图

    /// 加载证照图片
    private func loadCertificateImage() {
        certificateImageView.setImage(
            AppImage.Remote.licenseCertificate,
            placeholder: AppImage.Local.emptyData
        ) { result in
            // 加载失败时保留占位图，不弹错（避免干扰用户浏览文字信息）
            if case .failure(let error) = result {
                AppLog.profile.error(
                    "证照图加载失败：\(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}

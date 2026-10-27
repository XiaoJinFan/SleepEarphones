//
//  ContactUsViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/16.
//

import UIKit
import SnapKit

/// 联系我们页
@MainActor
final class ContactUsViewController: UIViewController {

    // MARK: - 文案常量

    /// 联系信息文案
    ///
    /// - Warning: 以下为占位文案，**上线前必须补全真实信息**。
    ///            补全后删除本 Warning 与 `Info.validate()` 调用。
    private enum Info {
        /// 公司名称
        static let companyName  = "睡眠耳机有限公司"
        /// 官网（TODO: 补全真实官网 URL）
        static let website      = "平台官网：https://www.example.com"
        /// 电话（TODO: 补全真实电话）
        static let phoneNumber  = "+86 12345678"
        /// 邮箱（TODO: 补全真实邮箱）
        static let emailAddress = "info@example.com"

        /// Debug 校验：占位文案未替换时暴露问题
        static func validate() {
            #if DEBUG
            if website.contains("example.com")
                || phoneNumber.contains("12345678")
                || emailAddress.contains("example.com") {
                AppLog.profile.warning(
                    "⚠️ ContactUsViewController.Info 仍是占位文案，上线前必须补全"
                )
            }
            #endif
        }
    }

    // MARK: - Layout 常量

    private enum Layout {
        /// 顶部装饰图高度
        static let imageHeight: CGFloat = 200

        /// 卡片上浮覆盖图片的距离（负偏移）
        static let cardOverlapOffset: CGFloat = -20

        /// 公司信息卡片**最小**高度（内容多时可撑开）
        static let companyCardMinHeight: CGFloat = 100
        /// 电话 / 邮箱卡片高度（布局稳定，可固定）
        static let contactCardHeight: CGFloat = 88

        /// 卡片间距
        static let cardSpacing: CGFloat = AppSpacing.md

        /// 图标尺寸
        static let iconSize: CGFloat = 44

        /// 图标内部图标尺寸
        static let iconSymbolSize: CGFloat = 20
    }

    // MARK: - UI

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.backgroundColor = AppColor.Background.secondary
        return sv
    }()

    private let contentView = UIView()

    /// 顶部装饰图
    private let headerImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = AppImage.Local.contactUsHeader
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()

    // MARK: 公司信息卡片

    private let companyCard: UIView = {
        let v = UIView()
        v.backgroundColor = AppColor.Background.card
        v.layer.cornerRadius = AppSpacing.Corner.card
        v.clipsToBounds = true
        return v
    }()

    private let companyNameLabel: UILabel = {
        let l = UILabel()
        l.text = Info.companyName
        l.font = AppFont.Title.section
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 0
        return l
    }()

    private let websiteLabel: UILabel = {
        let l = UILabel()
        l.text = Info.website
        l.font = AppFont.Body.secondary
        l.textColor = AppColor.Text.secondary
        l.numberOfLines = 0
        return l
    }()

    // MARK: 联系电话卡片

    private let phoneCard: UIView = {
        let v = UIView()
        v.backgroundColor = AppColor.Background.card
        v.layer.cornerRadius = AppSpacing.Corner.card
        v.clipsToBounds = true
        return v
    }()

    private let phoneIconView: UIImageView = {
        let iv = UIImageView()
        iv.image = AppImage.System.phoneFill?
            .withConfiguration(UIImage.SymbolConfiguration(
                pointSize: Layout.iconSymbolSize,
                weight: .medium
            ))
        iv.tintColor = .white
        iv.backgroundColor = AppColor.Semantic.success
        iv.layer.cornerRadius = Layout.iconSize / 2
        iv.clipsToBounds = true
        iv.contentMode = .center
        return iv
    }()

    private let phoneTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "联系电话"
        l.font = AppFont.Body.secondary
        l.textColor = AppColor.Text.primary
        return l
    }()

    private let phoneNumberLabel: UILabel = {
        let l = UILabel()
        l.text = Info.phoneNumber
        l.font = AppFont.Body.emphasized
        l.textColor = AppColor.Text.primary
        return l
    }()

    // MARK: 公司邮箱卡片

    private let emailCard: UIView = {
        let v = UIView()
        v.backgroundColor = AppColor.Background.card
        v.layer.cornerRadius = AppSpacing.Corner.card
        v.clipsToBounds = true
        return v
    }()

    private let emailIconView: UIImageView = {
        let iv = UIImageView()
        iv.image = AppImage.System.envelopeFill?
            .withConfiguration(UIImage.SymbolConfiguration(
                pointSize: Layout.iconSymbolSize,
                weight: .medium
            ))
        iv.tintColor = .white
        iv.backgroundColor = AppColor.Semantic.warning
        iv.layer.cornerRadius = Layout.iconSize / 2
        iv.clipsToBounds = true
        iv.contentMode = .center
        return iv
    }()

    private let emailTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "公司邮箱"
        l.font = AppFont.Body.secondary
        l.textColor = AppColor.Text.primary
        return l
    }()

    private let emailAddressLabel: UILabel = {
        let l = UILabel()
        l.text = Info.emailAddress
        l.font = AppFont.Body.emphasized
        l.textColor = AppColor.Text.primary
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
        // Debug 下检查占位文案是否已替换
        Info.validate()

        setupUI()
        setupConstraints()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "联系我们"
        view.backgroundColor = AppColor.Background.secondary
        navigationItem.backButtonDisplayMode = .minimal

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(headerImageView)
        contentView.addSubview(companyCard)
        contentView.addSubview(phoneCard)
        contentView.addSubview(emailCard)

        // 公司卡片子视图
        companyCard.addSubview(companyNameLabel)
        companyCard.addSubview(websiteLabel)

        // 电话卡片子视图
        phoneCard.addSubview(phoneIconView)
        phoneCard.addSubview(phoneTitleLabel)
        phoneCard.addSubview(phoneNumberLabel)

        // 邮箱卡片子视图
        emailCard.addSubview(emailIconView)
        emailCard.addSubview(emailTitleLabel)
        emailCard.addSubview(emailAddressLabel)
    }

    private func setupConstraints() {
        // MARK: ScrollView + ContentView
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        // MARK: 顶部装饰图
        headerImageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Layout.imageHeight)
        }

        // MARK: 公司信息卡片
        companyCard.snp.makeConstraints { make in
            // 上浮覆盖图片
            make.top.equalTo(headerImageView.snp.bottom).offset(Layout.cardOverlapOffset)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.md)
            make.height.greaterThanOrEqualTo(Layout.companyCardMinHeight)
        }

        companyNameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(AppSpacing.lg)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.md)
        }

        websiteLabel.snp.makeConstraints { make in
            make.top.equalTo(companyNameLabel.snp.bottom).offset(AppSpacing.sm)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.md)
            // 撑开 companyCard 底部
            make.bottom.equalToSuperview().offset(-AppSpacing.lg)
        }

        // MARK: 联系电话卡片
        phoneCard.snp.makeConstraints { make in
            make.top.equalTo(companyCard.snp.bottom).offset(Layout.cardSpacing)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.md)
            make.height.equalTo(Layout.contactCardHeight)
        }

        phoneIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(AppSpacing.md)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.iconSize)
        }

        phoneTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(phoneIconView.snp.trailing).offset(AppSpacing.md)
            make.top.equalToSuperview().offset(AppSpacing.lg)
        }

        phoneNumberLabel.snp.makeConstraints { make in
            make.leading.equalTo(phoneTitleLabel)
            make.top.equalTo(phoneTitleLabel.snp.bottom).offset(6)
            make.trailing.lessThanOrEqualToSuperview().inset(AppSpacing.md)
        }

        // MARK: 公司邮箱卡片
        emailCard.snp.makeConstraints { make in
            make.top.equalTo(phoneCard.snp.bottom).offset(Layout.cardSpacing)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.md)
            make.height.equalTo(Layout.contactCardHeight)
            // 撑开 contentView 底部
            make.bottom.equalToSuperview().offset(-AppSpacing.lg)
        }

        emailIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(AppSpacing.md)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.iconSize)
        }

        emailTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(emailIconView.snp.trailing).offset(AppSpacing.md)
            make.top.equalToSuperview().offset(AppSpacing.lg)
        }

        emailAddressLabel.snp.makeConstraints { make in
            make.leading.equalTo(emailTitleLabel)
            make.top.equalTo(emailTitleLabel.snp.bottom).offset(6)
            make.trailing.lessThanOrEqualToSuperview().inset(AppSpacing.md)
        }
    }
}

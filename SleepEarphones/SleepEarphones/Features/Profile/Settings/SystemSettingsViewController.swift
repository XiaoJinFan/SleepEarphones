//
//  SystemSettingsViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/24.
//

import UIKit
import SnapKit

/// 系统设置页
///
/// ## 职责
/// - 展示三个分组：账号与安全 / 协议语言版本 / 注销账号
/// - 承载各设置项的导航入口
///
/// ## 调用方法
/// ```swift
/// // 由 MyViewController 的「系统设置」入口 push
/// let vc = SystemSettingsViewController()
/// navigationController?.pushViewController(vc, animated: true)
/// ```
@MainActor
final class SystemSettingsViewController: UIViewController {

    // MARK: - Constants

    private enum Layout {
        /// 卡片之间 / 卡片与屏幕边缘的间距
        static let cardSpacing: CGFloat = AppSpacing.sm
        /// 卡片水平边距
        static let horizontalInset: CGFloat = AppSpacing.md
        /// ScrollView 顶部边距
        static let scrollTopInset: CGFloat = AppSpacing.sm
        /// ScrollView 底部边距
        static let scrollBottomInset: CGFloat = AppSpacing.xl
    }

    /// 尚未实现的入口提示文案
    ///
    /// - Note: 抽为常量便于后续统一替换 / 清理。
    private static let todoToast = "功能开发中"

    // MARK: - UI

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.backgroundColor = .clear
        return sv
    }()

    private lazy var contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = Layout.cardSpacing
        s.alignment = .fill
        return s
    }()

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameters:
    ///   - nibNameOrNil: Nib 文件名（默认 nil）
    ///   - nibBundleOrNil: Nib Bundle（默认 nil）
    ///
    /// - Note: 用 `init(nibName:bundle:)` 的 override 来设置
    ///         `hidesBottomBarWhenPushed`，确保从任何入口 Push 都生效。
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        // ✅ 关键：Push 时自动隐藏 tabBar，Pop 时自动恢复
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.hidesBottomBarWhenPushed = true
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        buildSections()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "系统设置"
        view.backgroundColor = AppColor.Background.secondary
        navigationItem.backButtonDisplayMode = .minimal

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
    }

    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentStack.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
                .inset(UIEdgeInsets(
                    top: Layout.scrollTopInset,
                    left: Layout.horizontalInset,
                    bottom: Layout.scrollBottomInset,
                    right: Layout.horizontalInset
                ))
            make.width.equalTo(scrollView.frameLayoutGuide)
                .offset(-Layout.horizontalInset * 2)
        }
    }

    // MARK: - Sections

    /// 构建所有分组
    ///
    /// - Note: 每个分组一个工厂方法，结构清晰、便于增删。
    private func buildSections() {
        contentStack.addArrangedSubview(makeAccountCard())
        contentStack.addArrangedSubview(makeInfoCard())
        contentStack.addArrangedSubview(makeLogoutCard())
    }

    /// 分组 1：账号与安全
    ///
    /// - Returns: 账号与安全分组卡片
    private func makeAccountCard() -> SettingsCardView {
        SettingsCardView(items: [
            SettingsItem(title: "账号与安全") { [weak self] in
                self?.openAccountSecurity()
            }
        ])
    }

    /// 分组 2：协议 / 语言 / 版本
    ///
    /// - Returns: 协议 / 语言 / 版本分组卡片
    private func makeInfoCard() -> SettingsCardView {
        SettingsCardView(items: [
            SettingsItem(title: "用户协议") { [weak self] in
                self?.openUserAgreement()
            },
            SettingsItem(title: "语言设置") { [weak self] in
                self?.openLanguageSettings()
            },
            SettingsItem(title: "隐私政策") { [weak self] in
                self?.openPrivacyPolicy()
            },
            SettingsItem(
                title: "当前版本",
                value: "V\(DeviceInfo.appVersion)",
                showsArrow: false,
                action: nil    // ⬅️ 无点击
            )
        ])
    }

    /// 分组 3：注销账号
    ///
    /// - Returns: 注销账号分组卡片
    private func makeLogoutCard() -> SettingsCardView {
        SettingsCardView(items: [
            SettingsItem(title: "注销账号") { [weak self] in
                self?.openAccountDeletion()
            }
        ])
    }

    // MARK: - Actions

    /// 打开账号与安全页
    private func openAccountSecurity() {
        AppLog.profile.debug("点击账号与安全")
        let vc = AccountSecurityViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    /// 打开用户协议
    ///
    /// - Note: 复用 `AgreementNavigation`（与登录页同一入口）。
    private func openUserAgreement() {
        AppLog.profile.debug("点击用户协议")
        AgreementNavigation.open(from: self, urlString: AgreementLinks.userAgreement)
    }

    /// 打开语言设置页
    private func openLanguageSettings() {
        AppLog.profile.debug("点击语言设置")
        let vc = LanguageSettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    /// 打开隐私政策
    ///
    /// - Note: 复用 `AgreementNavigation`（与登录页同一入口）。
    private func openPrivacyPolicy() {
        AppLog.profile.debug("点击隐私政策")
        AgreementNavigation.open(from: self, urlString: AgreementLinks.privacyPolicy)
    }

    /// 打开注销账号页（危险操作：二次确认后再跳转）
    private func openAccountDeletion() {
        AppLog.profile.debug("点击注销账号")
        showConfirm(
            title: "注销账号",
            message: "注销后账号数据将被永久删除，确定要继续吗？",
            confirmTitle: "继续注销",
            destructive: true
        ) { [weak self] in
            // TODO: 跳转"注销账号"页
            self?.showToast(Self.todoToast)
        }
    }
}

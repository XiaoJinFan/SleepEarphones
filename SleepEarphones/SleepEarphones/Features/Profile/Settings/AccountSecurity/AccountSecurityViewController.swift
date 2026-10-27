//
//  AccountSecurityViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/30.
//

import UIKit
import SnapKit

/// 账号与安全页
///
/// ## 展示规则（依登录方式）
/// | 登录方式 | 菜单项 |
/// |---|---|
/// | 手机号登录 | 修改密码 / **修改绑定手机号** / **绑定邮箱** |
/// | 邮箱登录   | 修改密码 / **修改绑定邮箱** / **绑定手机号** |
///
@MainActor
final class AccountSecurityViewController: UIViewController {

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

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        buildSections()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "账号与安全"
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

    /// 根据登录方式构建菜单
    ///
    /// ## 判断逻辑
    /// 从 `AuthStore.shared.cachedLoginType` 读取——
    /// 该字段在**登录成功时**由 `LoginViewModel` 写入，
    /// 是登录方式的权威来源。
    ///
    /// - Note: 若未来服务端能返回"注册方式"字段，替换成更精确的判断即可。
    private func buildSections() {
        let isPhoneLogin = (AuthStore.shared.cachedLoginType == .phone)

        var items: [SettingsItem] = []

        // 1. 修改密码（所有用户都有）
        items.append(SettingsItem(title: "修改密码") { [weak self] in
            self?.openChangePassword()
        })

        // 2. 根据登录方式决定顺序
        if isPhoneLogin {
            // 手机号登录：先手机（修改），后邮箱（绑定）
            items.append(SettingsItem(title: "修改绑定手机号") { [weak self] in
                self?.openChangePhone()
            })
            items.append(SettingsItem(title: "绑定邮箱") { [weak self] in
                self?.openBindEmail()
            })
        } else {
            // 邮箱登录：先邮箱（修改），后手机（绑定）
            items.append(SettingsItem(title: "修改绑定邮箱") { [weak self] in
                self?.openChangeEmail()
            })
            items.append(SettingsItem(title: "绑定手机号") { [weak self] in
                self?.openBindPhone()
            })
        }

        // 3. 构建卡片并加入
        let card = SettingsCardView(items: items)
        contentStack.addArrangedSubview(card)
    }

    // MARK: - Actions

    /// 打开修改密码页
    private func openChangePassword() {
        AppLog.profile.debug("点击修改密码")
        let vc = ChangePasswordViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    /// 打开修改绑定手机号页
    private func openChangePhone() {
        AppLog.profile.debug("点击修改绑定手机号")
        let vc = ChangeAccountViewController(mode: .changePhone)
        navigationController?.pushViewController(vc, animated: true)
    }

    /// 打开绑定邮箱页
    private func openBindEmail() {
        AppLog.profile.debug("点击绑定邮箱")
        let vc = ChangeAccountViewController(mode: .bindEmail)
        navigationController?.pushViewController(vc, animated: true)
    }

    /// 打开修改绑定邮箱页
    private func openChangeEmail() {
        AppLog.profile.debug("点击修改绑定邮箱")
        let vc = ChangeAccountViewController(mode: .changeEmail)
        navigationController?.pushViewController(vc, animated: true)
    }

    /// 打开绑定手机号页
    private func openBindPhone() {
        AppLog.profile.debug("点击绑定手机号")
        let vc = ChangeAccountViewController(mode: .bindPhone)
        navigationController?.pushViewController(vc, animated: true)
    }
}

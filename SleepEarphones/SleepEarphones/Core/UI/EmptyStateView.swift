//
//  EmptyStateView.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/22.
//

import UIKit
import SnapKit

/// 通用空状态视图
///
/// ## 调用方法
/// ```swift
/// // 1. 预设样式
/// let emptyView = EmptyStateView(style: .device)
///
/// // 2. 自定义（图文）
/// let emptyView = EmptyStateView()
/// emptyView.configure(image: AppImage.Local.emptyData, text: "暂无消息")
///
/// // 3. 仅文案（无图）
/// emptyView.configure(image: nil, text: "暂无数据")
/// ```
@MainActor
final class EmptyStateView: UIView {

    // MARK: - Style

    /// 预设样式
    enum Style {
        case device, message, music, sleep

        /// 占位图
        var image: UIImage {
            AppImage.Local.emptyData
        }

        /// 提示文案
        var text: String {
            switch self {
            case .device:  return "暂无设备"
            case .message: return "暂无消息"
            case .music:   return "暂无音乐"
            case .sleep:   return "暂无记录"
            }
        }
    }

    // MARK: - Layout

    private enum Layout {
        /// 卡片圆角
        static let cardCornerRadius: CGFloat = AppSpacing.Corner.card
        /// 图片上边距
        static let imageTopInset: CGFloat = 80
        /// 图片尺寸
        static let imageSize = CGSize(width: 180, height: 140)
        /// 文案与图片的间距（有图时）
        static let titleTopInset: CGFloat = AppSpacing.md
        /// 卡片底部留白
        static let titleBottomInset: CGFloat = 80
    }

    // MARK: - UI

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = AppColor.Background.card
        v.layer.cornerRadius = Layout.cardCornerRadius
        v.layer.masksToBounds = true
        return v
    }()

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = AppImage.Local.emptyData
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "暂无数据"
        l.font = AppFont.Body.secondary
        l.textColor = AppColor.Text.secondary
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    // MARK: - Constraints（需动态切换的两套约束）

    /// 有图时的文案顶部约束：绑在 imageView 底部
    private var titleBelowImageConstraint: Constraint?

    /// 无图时的文案顶部约束：绑在 cardView 顶部 + imageTopInset
    private var titleDirectlyConstraint: Constraint?

    /// 卡片最小高度（有图时）
    private var cardMinHeightWithImageConstraint: Constraint?

    /// 卡片最小高度（无图时）
    private var cardMinHeightNoImageConstraint: Constraint?

    // MARK: - Init

    /// 初始化
    /// - Parameter frame: 视图 frame
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    /// 用预设样式初始化
    ///
    /// - Parameter style: 预设样式
    convenience init(style: Style) {
        self.init(frame: .zero)
        configure(style: style)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Configure

    /// 用预设样式配置
    ///
    /// - Parameter style: 预设样式
    func configure(style: Style) {
        configure(image: style.image, text: style.text)
    }

    /// 自定义配置
    ///
    /// - Parameters:
    ///   - image: 占位图；传 nil 时隐藏图片且文案上移
    ///   - text: 提示文案；传 nil / 空字符串时隐藏文案
    ///
    /// - Note: 切换约束组而非仅隐藏视图——
    ///         仅 `isHidden = true` 会导致文案上方仍留 140pt 空白。
    func configure(image: UIImage?, text: String?) {
        let hasImage = (image != nil)

        // 1. 图片
        imageView.image = image
        imageView.isHidden = !hasImage

        // 2. 文案
        let hasText = !(text?.isEmpty ?? true)
        titleLabel.text = text
        titleLabel.isHidden = !hasText

        // 3. 切换约束组
        if hasImage {
            // → 有图：取消"无图"约束，启用"有图"约束
            titleDirectlyConstraint?.deactivate()
            cardMinHeightNoImageConstraint?.deactivate()
            titleBelowImageConstraint?.activate()
            cardMinHeightWithImageConstraint?.activate()
        } else {
            // → 无图：取消"有图"约束，启用"无图"约束
            titleBelowImageConstraint?.deactivate()
            cardMinHeightWithImageConstraint?.deactivate()
            titleDirectlyConstraint?.activate()
            cardMinHeightNoImageConstraint?.activate()
        }
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear

        addSubview(cardView)
        cardView.addSubview(imageView)
        cardView.addSubview(titleLabel)

        // 1. 卡片铺满自身
        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 2. 图片：横向居中，尺寸固定
        imageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.imageTopInset)
            make.centerX.equalToSuperview()
            make.width.equalTo(Layout.imageSize.width)
            make.height.equalTo(Layout.imageSize.height)
        }

        // 3. 文案：横向居中 + 左右边距（这两组约束永远生效）
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(AppSpacing.md)
            make.trailing.lessThanOrEqualToSuperview().offset(-AppSpacing.md)
        }

        // 4. 文案的两套 top 约束
        //
        // - Note: 用 `prepareConstraints` —— 只创建约束引用，**不立即激活**。
        //         后续由 `configure(image:text:)` 按需 activate / deactivate。
        titleLabel.snp.prepareConstraints { make in
            self.titleBelowImageConstraint = make.top
                .equalTo(imageView.snp.bottom)
                .offset(Layout.titleTopInset)
                .constraint
        }
        titleLabel.snp.prepareConstraints { make in
            self.titleDirectlyConstraint = make.top
                .equalToSuperview()
                .offset(Layout.imageTopInset)
                .constraint
        }

        // 5. 卡片的两套最小高度约束
        cardView.snp.prepareConstraints { make in
            self.cardMinHeightWithImageConstraint = make.height
                .greaterThanOrEqualTo(
                    Layout.imageTopInset
                        + Layout.imageSize.height
                        + Layout.titleTopInset
                        + Layout.titleBottomInset
                )
                .constraint
        }
        cardView.snp.prepareConstraints { make in
            self.cardMinHeightNoImageConstraint = make.height
                .greaterThanOrEqualTo(
                    Layout.imageTopInset
                        + Layout.titleTopInset
                        + Layout.titleBottomInset
                )
                .constraint
        }

        // 6. 初始状态：默认"有图"（与 `configure(image:text:)` 的默认分支一致）
        titleBelowImageConstraint?.activate()
        cardMinHeightWithImageConstraint?.activate()
    }
}

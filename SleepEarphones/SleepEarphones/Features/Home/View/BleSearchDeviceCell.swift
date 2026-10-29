//
//  BleSearchDeviceCell.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/22.
//

import UIKit
import SnapKit

@MainActor
final class BleSearchDeviceCell: UITableViewCell {

    // MARK: - Constants

    static let reuseID = "BleSearchDeviceCell"

    // MARK: - Layout

    private enum Layout {
        /// 卡片垂直外边距（上下各 8，加上内容 72，正好等于 rowHeight 88）
        static let cardVerticalMargin: CGFloat = AppSpacing.xs
        /// 卡片水平外边距
        static let cardHorizontalMargin: CGFloat = AppSpacing.md
        /// 卡片内部 padding
        static let cardPadding: CGFloat = AppSpacing.md
        /// 设备图尺寸
        static let imageSize: CGFloat = 56
        /// 设备图圆角
        static let imageCornerRadius: CGFloat = 12
        /// "连接"按钮尺寸
        static let connectButtonSize = CGSize(width: 72, height: 36)
    }

    // MARK: - Callback

    /// 点击"连接"回调
    var onConnect: (() -> Void)?

    // MARK: - UI

    /// 白色卡片容器
    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = AppColor.Background.card
        v.layer.cornerRadius = AppSpacing.Corner.card
        v.clipsToBounds = true
        return v
    }()

    /// 设备图
    private let deviceImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = AppColor.Background.secondary
        iv.layer.cornerRadius = Layout.imageCornerRadius
        iv.clipsToBounds = true
        iv.image = UIImage(
            systemName: "airpodspro",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        )
        iv.tintColor = AppColor.Text.secondary
        return iv
    }()

    /// 设备名称
    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Body.emphasized
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    /// "连接"按钮
    private let connectButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = AppColor.Text.primary
        config.baseForegroundColor = AppColor.Background.card
        config.background.cornerRadius = Layout.connectButtonSize.height / 2
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: AppSpacing.md,
            bottom: 0,
            trailing: AppSpacing.md
        )

        var titleAttr = AttributedString("连接")
        titleAttr.font = AppFont.Body.secondary
        config.attributedTitle = titleAttr

        return UIButton(configuration: config)
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        deviceImageView.cancelRemoteImageLoad()
        deviceImageView.image = UIImage(
            systemName: "airpodspro",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        )
        nameLabel.text = nil
        updateConnectButtonState(isConnecting: false)
        onConnect = nil
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addSubview(deviceImageView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(connectButton)

        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
    }

    private func setupConstraints() {
        // 卡片容器（上下各留 8pt）
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.cardVerticalMargin)
            make.bottom.equalToSuperview().offset(-Layout.cardVerticalMargin)
            make.leading.equalToSuperview().offset(Layout.cardHorizontalMargin)
            make.trailing.equalToSuperview().offset(-Layout.cardHorizontalMargin)
        }

        // 设备图：核心修复，删除引起冲突的 top/bottom 约束，居中即可
        deviceImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Layout.cardPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.imageSize)
        }

        // "连接"按钮：靠右，居中
        connectButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Layout.cardPadding)
            make.centerY.equalToSuperview()
            make.size.equalTo(Layout.connectButtonSize)
        }

        // 设备名称：在图片和按钮之间，居中
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(deviceImageView.snp.trailing).offset(Layout.cardPadding)
            make.trailing.equalTo(connectButton.snp.leading).offset(-AppSpacing.sm)
            make.centerY.equalToSuperview()
        }
    }

    // MARK: - Configure

    /// 配置单元格
    func configure(name: String, imageURL: String?, isConnecting: Bool) {
        nameLabel.text = name

        if let imageURL, !imageURL.isEmpty {
            deviceImageView.setImage(imageURL)
        } else {
            deviceImageView.image = UIImage(
                systemName: "airpodspro",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
            )
        }

        updateConnectButtonState(isConnecting: isConnecting)
    }

    // MARK: - Private

    /// 更新"连接"按钮的状态
    private func updateConnectButtonState(isConnecting: Bool) {
        connectButton.isEnabled = !isConnecting
        connectButton.alpha = isConnecting ? 0.6 : 1.0

        guard var config = connectButton.configuration else { return }
        var titleAttr = AttributedString(isConnecting ? "连接中…" : "连接")
        titleAttr.font = AppFont.Body.secondary
        config.attributedTitle = titleAttr
        connectButton.configuration = config
    }

    // MARK: - Actions

    @objc private func connectTapped() {
        onConnect?()
    }
}

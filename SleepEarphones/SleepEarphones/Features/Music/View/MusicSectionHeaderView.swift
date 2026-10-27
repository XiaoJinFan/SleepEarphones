//
//  MusicSectionHeaderView.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/10.
//

import UIKit
import SnapKit


@MainActor
final class MusicSectionHeaderView: UICollectionReusableView {

    // MARK: - Constants

    static let reuseID = "MusicSectionHeaderView"

    // MARK: - UI

    /// 分组标题
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 20, weight: .bold)
        l.textColor = AppColor.Text.primary
        return l
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(titleLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configure

    /// 配置分组标题
    ///
    /// - Parameter title: 分组标题（如"推荐白噪音" / "自然"）
    func configure(title: String) {
        titleLabel.text = title
    }
}

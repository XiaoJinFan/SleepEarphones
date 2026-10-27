//
//  InsertMusicCell.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/10/13.
//

import UIKit
import SnapKit

/// 获取音乐页的单元格（圆圈 + 名字）
///
/// ## 视觉
/// ```
/// ○ 刮风
/// ● 刮风下雨   ← 选中：实心蓝圈 + 勾
/// ```
@MainActor
final class InsertMusicCell: UITableViewCell {

    // MARK: - Constants

    static let reuseID = "InsertMusicCell"

    // MARK: - UI

    /// 单选圆圈
    private let radioView: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.layer.borderWidth = 1.5
        v.layer.borderColor = AppColor.separator.cgColor
        v.layer.cornerRadius = 11
        v.clipsToBounds = true
        return v
    }()

    /// 选中态的勾
    private let checkImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(
            systemName: "checkmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        )
        iv.tintColor = .white
        iv.contentMode = .center
        iv.isHidden = true
        return iv
    }()

    /// 名字
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFont.Body.regular
        l.textColor = AppColor.Text.primary
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(radioView)
        radioView.addSubview(checkImageView)
        contentView.addSubview(titleLabel)

        radioView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(AppSpacing.md)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(22)
        }

        checkImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(radioView.snp.trailing).offset(AppSpacing.md)
            make.trailing.equalToSuperview().offset(-AppSpacing.md)
            make.centerY.equalToSuperview()
        }
    }

    // MARK: - Configure

    func configure(with song: MusicSong, isSelected: Bool) {
        titleLabel.text = song.title

        if isSelected {
            radioView.backgroundColor = UIColor(hex: "#2FA9E0")
            radioView.layer.borderColor = UIColor(hex: "#2FA9E0").cgColor
            checkImageView.isHidden = false
        } else {
            radioView.backgroundColor = .clear
            radioView.layer.borderColor = AppColor.separator.cgColor
            checkImageView.isHidden = true
        }
    }
}

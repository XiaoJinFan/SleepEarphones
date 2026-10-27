//
//  SleepViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/5.
//

import UIKit

@MainActor
final class SleepViewController: UIViewController {

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        AppLog.app.debug("SleepViewController 已加载")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = false
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = AppColor.Background.primary
    }
}

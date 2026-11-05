//
//  PersonalViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/9/5.
//

import UIKit
import SnapKit
import PhotosUI
import Combine


@MainActor
final class PersonalViewController: UIViewController {

    // MARK: - Constants

    /// 昵称最大长度
    private static let maxNicknameLength = 20

    /// 保存成功后的延时 pop（秒）
    private static let successPopDelay: UInt64 = 600_000_000   // 0.6s

    // MARK: - Layout 常量

    private enum Layout {
        static let avatarContainerHeight: CGFloat = 80
        static let avatarImageSize: CGFloat = 60
        static let nicknameContainerHeight: CGFloat = 60
        static let containerSpacing: CGFloat = AppSpacing.xxl
        static let labelInset: CGFloat = AppSpacing.sm
        static let saveButtonHeight: CGFloat = 46
        static let saveButtonBottomInset: CGFloat = AppSpacing.xxl
        static let nicknameInputMaxLength: Int = 20
    }

    // MARK: - UI 组件

    // MARK: 头像容器

    private let avatarContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = AppColor.Background.card
        view.layer.cornerRadius = AppSpacing.Corner.button
        view.clipsToBounds = true
        return view
    }()

    private let avatarLabel: UILabel = {
        let label = UILabel()
        // **标签已本地化**
        label.text = L("头像")
        label.font = AppFont.Body.regular
        label.textColor = AppColor.Text.primary
        return label
    }()

    /// 头像图片
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = AppImage.Local.avatarPlaceholder
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private let avatarButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        return button
    }()

    // MARK: 昵称容器

    private let nicknameContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = AppColor.Background.card
        view.layer.cornerRadius = AppSpacing.Corner.button
        view.clipsToBounds = true
        return view
    }()

    private let nicknameLabel: UILabel = {
        let label = UILabel()
        // **标签已本地化**
        label.text = L("昵称")
        label.font = AppFont.Body.regular
        label.textColor = AppColor.Text.primary
        return label
    }()

    private let nicknameValueLabel: UILabel = {
        let label = UILabel()
        label.font = AppFont.Body.regular
        label.textColor = AppColor.Text.primary
        label.textAlignment = .right
        return label
    }()

    private let nicknameButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        return button
    }()

    // MARK: 保存按钮

    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        // **按钮标题已本地化**
        button.setTitle(L("保存"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = AppFont.Button.primary
        button.backgroundColor = AppColor.Brand.primary
        button.layer.cornerRadius = AppSpacing.Corner.button
        button.clipsToBounds = true
        return button
    }()

    // MARK: - ViewModel

    private let viewModel: UserProfileViewModel
    private var cancellables = Set<AnyCancellable>()

    /// 本次会话用户新选择的头像
    private var selectedAvatarImage: UIImage?

    // MARK: - Init

    /// 初始化
    ///
    /// - Parameter viewModel: 由外部（`MyViewController`）注入，
    ///                        保证与本页共享同一实例
    init(viewModel: UserProfileViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        // push 时自动隐藏 tabBar，pop 时自动恢复
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
        setupActions()
        bindViewModel()
    }

    /// 等 Auto Layout 完成后计算头像圆角
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 头像正圆：圆角 = 宽度的一半
        avatarImageView.layer.cornerRadius = avatarImageView.bounds.width / 2
    }

    // MARK: - UI 设置

    private func setupUI() {
        view.backgroundColor = AppColor.Background.secondary
        // **导航标题已本地化**
        title = L("我的资料")

        view.addSubview(avatarContainerView)
        avatarContainerView.addSubview(avatarLabel)
        avatarContainerView.addSubview(avatarImageView)
        avatarContainerView.addSubview(avatarButton)

        view.addSubview(nicknameContainerView)
        nicknameContainerView.addSubview(nicknameLabel)
        nicknameContainerView.addSubview(nicknameValueLabel)
        nicknameContainerView.addSubview(nicknameButton)

        view.addSubview(saveButton)
    }

    private func setupConstraints() {
        // 头像容器
        avatarContainerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
                .inset(AppSpacing.horizontal)
            make.height.equalTo(Layout.avatarContainerHeight)
        }

        avatarLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Layout.labelInset)
            make.centerY.equalToSuperview()
        }

        avatarImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Layout.labelInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Layout.avatarImageSize)
        }

        avatarButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 昵称容器
        nicknameContainerView.snp.makeConstraints { make in
            make.top.equalTo(avatarContainerView.snp.bottom)
                .offset(Layout.containerSpacing)
            make.leading.trailing.equalTo(avatarContainerView)
            make.height.equalTo(Layout.nicknameContainerHeight)
        }

        nicknameLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Layout.labelInset)
            make.centerY.equalToSuperview()
        }

        nicknameValueLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Layout.labelInset)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(nicknameLabel.snp.trailing)
                .offset(AppSpacing.lg)
        }

        nicknameButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 保存按钮
        saveButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
                .inset(AppSpacing.horizontal)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
                .inset(Layout.saveButtonBottomInset)
            make.height.equalTo(Layout.saveButtonHeight)
        }
    }

    private func setupActions() {
        avatarButton.addTarget(self, action: #selector(avatarButtonTapped), for: .touchUpInside)
        nicknameButton.addTarget(self, action: #selector(nicknameButtonTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
    }

    // MARK: - Binding

    private func bindViewModel() {
        // 头像
        viewModel.$avatarImage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                guard let self else { return }

                // 若用户已选新头像，**忽略** VM 的更新——
                // 避免用户刚选的预览图被 VM 的异步刷新覆盖。
                if self.selectedAvatarImage != nil {
                    AppLog.profile.debug("VM avatarImage 更新被忽略（用户已选新头像）")
                    return
                }

                self.avatarImageView.image = image ?? AppImage.Local.avatarPlaceholder
            }
            .store(in: &cancellables)

        // 昵称
        viewModel.$nickname
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                self?.nicknameValueLabel.text = name
            }
            .store(in: &cancellables)

        // 保存中 → 禁用按钮 + 换文案
        viewModel.$isSaving
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSaving in
                guard let self else { return }
                self.saveButton.isEnabled = !isSaving
                self.saveButton.alpha = isSaving ? 0.6 : 1.0
                // **按钮文案已本地化**
                self.saveButton.setTitle(
                    isSaving ? L("保存中…") : L("保存"),
                    for: .normal
                )
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    /// 点击头像 → 打开相册选择器
    @objc private func avatarButtonTapped() {
        presentPhotoPicker()
    }

    /// 打开 PHPickerViewController
    private func presentPhotoPicker() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        // 使用当前版本（不解码 + 保留原始数据），性能更好
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    /// 点击昵称 → 弹出编辑框
    @objc private func nicknameButtonTapped() {
        let alert = UIAlertController(
            // **标题 / 副标题 / 按钮均通过 `L(...)` 本地化**
            title: L("修改昵称"),
            message: L("最多 %lld 个字符", Self.maxNicknameLength),
            preferredStyle: .alert
        )
        alert.addTextField { [weak self] textField in
            textField.text = self?.nicknameValueLabel.text
            textField.placeholder = L("请输入新昵称")
            textField.clearButtonMode = .whileEditing
            // 限制输入长度——用 `.editingChanged` 动态截断
            textField.addTarget(
                self,
                action: #selector(Self.nicknameFieldDidChange(_:)),
                for: .editingChanged
            )
        }
        alert.addAction(UIAlertAction(title: L("取消"), style: .cancel))
        alert.addAction(UIAlertAction(title: L("确认"), style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let textField = alert?.textFields?.first else {
                return
            }

            let newName = textField.text?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            // 空昵称：轻震动 + 保持弹窗（不关闭）
            guard !newName.isEmpty else {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
                textField.becomeFirstResponder()
                textField.selectAll(nil)
                // 重新弹出弹窗——因为上面的 dismiss 是 UIKit 自动执行的
                // 这里通过再次 present 让用户可继续输入
                DispatchQueue.main.async { [weak self] in
                    self?.present(alert!, animated: true)
                }
                return
            }

            // 更新 UI（等待点"保存"才写入 VM + 持久化）
            self.nicknameValueLabel.text = newName
        })
        present(alert, animated: true)
    }

    /// 昵称输入框长度限制（`editingChanged` 事件处理）
    ///
    /// - Parameter textField: 触发事件的输入框
    @objc private func nicknameFieldDidChange(_ textField: UITextField) {
        guard let text = textField.text else { return }
        guard text.count > Self.maxNicknameLength else { return }
        // 截断到最大长度
        textField.text = String(text.prefix(Self.maxNicknameLength))
    }

    /// 点击保存
    @objc private func saveButtonTapped() {
        view.endEditing(true)

        // 昵称二次校验（防御性——理论上 UI 已限制长度）
        let nickname = (nicknameValueLabel.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nickname.isEmpty else {
            showToast(L("请输入昵称"))
            return
        }
        guard nickname.count <= Self.maxNicknameLength else {
            showToast(L("昵称最长 %lld 个字符", Self.maxNicknameLength))
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.viewModel.save(
                    avatar: self.selectedAvatarImage,   // nil = 不改头像
                    nickname: nickname
                )

                // 保存成功后**清空** `selectedAvatarImage`——
                // 避免未来"保存后不 pop"的场景下**重复上传同一张头像**。
                self.selectedAvatarImage = nil

                // 成功：Toast + 延时 pop
                self.showToast(L("保存成功"))
                AppLog.profile.debug("保存用户资料成功")
                try? await Task.sleep(nanoseconds: Self.successPopDelay)

                //   pop 前做**栈顶检查**——
                guard self.navigationController?.viewControllers.last === self else {
                    AppLog.profile.debug("保存成功延时 pop 时 VC 已不在栈顶，跳过")
                    return
                }
                self.navigationController?.popViewController(animated: true)

            } catch {
                // 失败：提示用户（本地已保存，仅云端同步失败）
                AppLog.profile.error(
                    "保存失败：\(error.localizedDescription, privacy: .public)"
                )
                self.showAlert(
                    error.localizedDescription,
                    // **Alert 标题已本地化**
                    title: L("云端同步失败")
                )
            }
        }
    }
}

// MARK: - PHPickerViewControllerDelegate

extension PersonalViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }

        // 异步加载图片（可能来自 iCloud / 大图）
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            if let error {
                AppLog.profile.error(
                    "加载相册图片失败：\(error.localizedDescription, privacy: .public)"
                )
                return
            }

            guard let image = object as? UIImage else { return }

            Task { @MainActor [weak self] in
                // 记录用户选择的新头像（保存时使用）
                self?.selectedAvatarImage = image
                self?.avatarImageView.image = image
            }
        }
    }
}

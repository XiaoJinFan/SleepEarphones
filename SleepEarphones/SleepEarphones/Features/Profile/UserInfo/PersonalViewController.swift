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

/// 我的资料页
///
/// ## 交互
/// - 点头像 → 弹出相册选择器
/// - 点昵称 → 弹出 Alert 输入新昵称
/// - 点保存 → 把当前 UI 上的头像 / 昵称写入 ViewModel + 持久化
///
/// ## 保存逻辑（**重点，易误读**）
/// `selectedAvatarImage` 跟踪"本次会话是否选了新头像"：
/// - **选了新头像** → `save(avatar: 新图, ...)` → 上传 + 更新远程
/// - **没选** → `save(avatar: nil, ...)` → **不改头像**（保持服务端原值）
///
/// ## tabBar 处理
/// `hidesBottomBarWhenPushed = true`——push 时自动隐藏，pop 时自动恢复。
@MainActor
final class PersonalViewController: UIViewController {

    // MARK: - Constants

    /// 昵称最大长度
    private static let maxNicknameLength = 20

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
        label.text = "头像"
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
        label.text = "昵称"
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
        button.setTitle("保存", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = AppFont.Button.primary
        button.backgroundColor = AppColor.Brand.primary
        button.layer.cornerRadius = AppSpacing.Corner.button
        button.clipsToBounds = true
        return button
    }()

    // MARK: - Layout 常量

    private enum Layout {
        static let avatarContainerHeight: CGFloat = 80
        static let avatarImageSize: CGFloat = 60
        static let nicknameContainerHeight: CGFloat = 60
        static let containerSpacing: CGFloat = AppSpacing.xxl
        static let labelInset: CGFloat = AppSpacing.sm
        static let saveButtonHeight: CGFloat = 46
        static let saveButtonBottomInset: CGFloat = AppSpacing.xxl
    }

    // MARK: - ViewModel

    private let viewModel: UserProfileViewModel
    private var cancellables = Set<AnyCancellable>()

    /// 本次会话用户新选择的头像
    ///
    /// ## 语义
    /// - `nil`：**未选择**新头像——保存时保持 VM 里的原头像
    /// - 非 nil：用户从相册选了新头像——保存时用新图
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
        title = "我的资料"

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
            make.leading.trailing.equalToSuperview().inset(AppSpacing.horizontal)
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
            make.top.equalTo(avatarContainerView.snp.bottom).offset(Layout.containerSpacing)
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
            make.leading.greaterThanOrEqualTo(nicknameLabel.snp.trailing).offset(AppSpacing.lg)
        }

        nicknameButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 保存按钮
        saveButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(AppSpacing.horizontal)
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
                self.saveButton.setTitle(isSaving ? "保存中…" : "保存", for: .normal)
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
    ///
    /// ## 行为
    /// 1. 弹出 Alert，预填当前昵称
    /// 2. 用户输入 → 点"确认" → **同步更新 UI**（保存到 VM 待点"保存"按钮）
    /// 3. 点"取消" → 无副作用
    ///
    @objc private func nicknameButtonTapped() {
        let alert = UIAlertController(
            title: "修改昵称",
            message: "最多 \(Self.maxNicknameLength) 个字符",
            preferredStyle: .alert
        )
        alert.addTextField { [weak self] textField in
            textField.text = self?.nicknameValueLabel.text
            textField.placeholder = "请输入新昵称"
            textField.clearButtonMode = .whileEditing
            // 限制输入长度——用 `.editingChanged` 动态截断
            textField.addTarget(
                self,
                action: #selector(Self.nicknameFieldDidChange(_:)),
                for: .editingChanged
            )
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确认", style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let newName = alert?.textFields?.first?.text?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !newName.isEmpty else {
                // 空昵称不处理（保持原值）
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
    ///
    @objc private func nicknameFieldDidChange(_ textField: UITextField) {
        guard let text = textField.text else { return }
        guard text.count > Self.maxNicknameLength else { return }
        // 截断到最大长度
        textField.text = String(text.prefix(Self.maxNicknameLength))
    }

    /// 点击保存
    ///
    /// ## 头像处理
    /// - 用户选了新头像 → 传 `selectedAvatarImage`
    /// - 用户没选 → 传 `nil`（**不改头像**）
    ///
    /// ## 昵称处理
    /// 读取 `nicknameValueLabel.text`（即用户当前看到的昵称）——
    /// 与"用户所见即所得"一致。
    @objc private func saveButtonTapped() {
        view.endEditing(true)

        // 昵称二次校验（防御性——理论上 UI 已限制长度）
        let nickname = (nicknameValueLabel.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nickname.isEmpty else {
            showToast("请输入昵称")
            return
        }
        guard nickname.count <= Self.maxNicknameLength else {
            showToast("昵称最长 \(Self.maxNicknameLength) 个字符")
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
                self.showToast("保存成功")
                AppLog.profile.debug("保存用户资料成功")
                try? await Task.sleep(nanoseconds: 600_000_000)   // 0.6s

                //   pop 前做**栈顶检查**——
                //   若用户在 0.6s 延时期间手动返回，此时 `self` 已不在栈顶，
                //   直接 `popViewController` 会**误弹上一层 VC**。
                //   与 `ChangeAccountViewController` 保持一致的安全检查。
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
                    title: "云端同步失败"
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

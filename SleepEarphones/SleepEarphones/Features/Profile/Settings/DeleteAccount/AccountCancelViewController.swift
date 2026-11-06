//
//  AccountCancelViewController.swift
//  SleepEarphones
//
//  Created by 肖进凡 on 2026/11/5.
//

import UIKit
import SnapKit
import Combine

@MainActor
final class AccountCancelViewController: UIViewController {

    // MARK: - Step
    private enum Step {
        case warning      // 第一步警告
        case inputReason  // 第二步选择+输入
        case confirm      // 第三步风险确认
        case reviewing    // 状态：审核中（显示撤销按钮）
    }
    
    // MARK: - Properties
    private let service: AccountCancelServiceProtocol = AccountCancelService()
    private var cancellables = Set<AnyCancellable>()
    private var currentInfo: AccountCancelInfo?
    private var reasonList: [String] = ["不再使用该产品", "隐私顾虑", "功能不满意", "其他原因"]
    
    private var currentStep: Step = .warning {
        didSet { updateUIForStep() }
    }
    
    private var selectedReason: String? = nil
    private var customReason: String = ""
    
    // MARK: - UI Components (Base)
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let loadingView = UIActivityIndicatorView(style: .medium)
    
    // MARK: - UI (Warning)
    private lazy var warningView: UIView = {
        let view = UIView()
        let titleLabel = UILabel()
        titleLabel.text = L("您主动注销后，我们将停止为您提供产品/服务")
        titleLabel.font = AppFont.Body.regular
        titleLabel.textColor = AppColor.Text.primary
        titleLabel.numberOfLines = 0
        
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(AppSpacing.xl)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
        }
        return view
    }()
    
    // MARK: - UI (Input Reason)
    private lazy var inputReasonView: UIView = {
        let view = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = L("账号注销")
        titleLabel.font = AppFont.Title.section
        
        let descLabel = UILabel()
        descLabel.text = L("永久注销且无法恢复，请谨慎操作")
        descLabel.font = AppFont.Body.secondary
        descLabel.textColor = AppColor.Text.secondary
        
        let line1 = UIView()
        line1.backgroundColor = AppColor.separator
        
        let selectTitleLabel = UILabel()
        selectTitleLabel.text = L("请选择注销账号的原因：")
        selectTitleLabel.font = AppFont.Body.emphasized
        
        // 选择列表 (这里为简化用竖直Stack代替，实际可换TableView)
        let reasonStack = UIStackView()
        reasonStack.axis = .vertical
        reasonStack.spacing = AppSpacing.sm
        for reason in reasonList {
            let btn = UIButton(type: .system)
            btn.setTitle(reason, for: .normal)
            btn.contentHorizontalAlignment = .left
            btn.addTarget(self, action: #selector(reasonTapped(_:)), for: .touchUpInside)
            reasonStack.addArrangedSubview(btn)
        }
        
        let line2 = UIView()
        line2.backgroundColor = AppColor.separator
        
        let inputTitleLabel = UILabel()
        inputTitleLabel.text = L("请填写注销原因")
        inputTitleLabel.font = AppFont.Body.emphasized
        
        let textView = UITextView()
        textView.backgroundColor = AppColor.Background.secondary
        textView.layer.cornerRadius = AppSpacing.Corner.medium
        textView.font = AppFont.Body.regular
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        textView.delegate = self
        textView.tag = 999
        // 占位符处理（略，实际需要PlaceholderTextView或label代替）
        
        [titleLabel, descLabel, line1, selectTitleLabel, reasonStack, line2, inputTitleLabel, textView].forEach {
            view.addSubview($0)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(AppSpacing.lg)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
        }
        descLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(AppSpacing.sm)
            make.leading.trailing.equalTo(titleLabel)
        }
        line1.snp.makeConstraints { make in
            make.top.equalTo(descLabel.snp.bottom).offset(AppSpacing.lg)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
            make.height.equalTo(0.5)
        }
        selectTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(line1).offset(AppSpacing.lg)
            make.leading.trailing.equalTo(titleLabel)
        }
        reasonStack.snp.makeConstraints { make in
            make.top.equalTo(selectTitleLabel.snp.bottom).offset(AppSpacing.md)
            make.leading.trailing.equalTo(titleLabel)
        }
        line2.snp.makeConstraints { make in
            make.top.equalTo(reasonStack.snp.bottom).offset(AppSpacing.lg)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
            make.height.equalTo(0.5)
        }
        inputTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(line2).offset(AppSpacing.lg)
            make.leading.trailing.equalTo(titleLabel)
        }
        textView.snp.makeConstraints { make in
            make.top.equalTo(inputTitleLabel.snp.bottom).offset(AppSpacing.md)
            make.leading.trailing.equalTo(titleLabel)
            make.height.equalTo(100)
            make.bottom.equalToSuperview()
        }
        
        return view
    }()
    
    // MARK: - UI (Confirm Risks)
    private lazy var confirmView: UIView = {
        let view = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = L("账号注销")
        titleLabel.font = AppFont.Title.section
        
        let descLabel = UILabel()
        descLabel.text = L("永久注销且无法恢复，请谨慎操作")
        descLabel.font = AppFont.Body.secondary
        descLabel.textColor = AppColor.Text.secondary
        
        let line1 = UIView()
        line1.backgroundColor = AppColor.separator
        
        let risksLabel = UILabel()
        risksLabel.text = L("""
                            账号注销后将放弃以下权益：
                            1、账号信息、第三方授权信息将被清空且无法恢复。
                            2、账号相关信息将会一并被删除且无法恢复。
                            3、注销后手机号码可重新注册，所生成账号为全新的账号，不包含注销账号的任何信息。
                            """)
        risksLabel.font = AppFont.Body.regular
        risksLabel.textColor = AppColor.Text.primary
        risksLabel.numberOfLines = 0
        
        let warnLabel = UILabel()
        warnLabel.text = L("点击下方按钮，即表示你已阅读并了解以上风险")
        warnLabel.font = AppFont.Body.secondary
        warnLabel.textColor = AppColor.Semantic.error
        
        let checkButton = UIButton(type: .system)
        checkButton.setTitle(L("我已清楚风险，确定继续"), for: .normal)
        checkButton.titleLabel?.font = AppFont.Button.primary
        checkButton.setTitleColor(AppColor.Text.primary, for: .normal)
        checkButton.layer.borderWidth = 1
        checkButton.layer.borderColor = AppColor.separator.cgColor
        checkButton.layer.cornerRadius = AppSpacing.Corner.button
        checkButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        
        [titleLabel, descLabel, line1, risksLabel, warnLabel, checkButton].forEach {
            view.addSubview($0)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(AppSpacing.lg)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
        }
        descLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(AppSpacing.sm)
            make.leading.trailing.equalTo(titleLabel)
        }
        line1.snp.makeConstraints { make in
            make.top.equalTo(descLabel.snp.bottom).offset(AppSpacing.lg)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
            make.height.equalTo(0.5)
        }
        risksLabel.snp.makeConstraints { make in
            make.top.equalTo(line1).offset(AppSpacing.lg)
            make.leading.trailing.equalTo(titleLabel)
        }
        warnLabel.snp.makeConstraints { make in
            make.top.equalTo(risksLabel.snp.bottom).offset(AppSpacing.xl)
            make.leading.trailing.equalTo(titleLabel)
        }
        checkButton.snp.makeConstraints { make in
            make.top.equalTo(warnLabel.snp.bottom).offset(AppSpacing.xxl)
            make.leading.trailing.equalTo(titleLabel)
            make.height.equalTo(46)
            make.bottom.equalToSuperview()
        }
        
        return view
    }()
    
    // MARK: - 审核中 UI
    private lazy var reviewingView: UIView = {
        let view = UIView()
        let icon = UIImageView(image: UIImage(systemName: "hourglass"))
        icon.tintColor = AppColor.Brand.primary
        icon.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = L("注销申请审核中")
        titleLabel.font = AppFont.Title.section
        titleLabel.textAlignment = .center
        
        let descLabel = UILabel()
        descLabel.text = L("我们将在3个工作日内完成审核，请耐心等待。")
        descLabel.font = AppFont.Body.secondary
        descLabel.textColor = AppColor.Text.secondary
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0
        
        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle(L("撤销注销申请"), for: .normal)
        cancelBtn.setTitleColor(AppColor.Semantic.error, for: .normal)
        cancelBtn.addTarget(self, action: #selector(cancelApplicationTapped), for: .touchUpInside)
        
        [icon, titleLabel, descLabel, cancelBtn].forEach { view.addSubview($0) }
        
        icon.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(80)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(60)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(icon.snp.bottom).offset(AppSpacing.lg)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
        }
        descLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(AppSpacing.sm)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.xxl)
        }
        cancelBtn.snp.makeConstraints { make in
            make.top.equalTo(descLabel.snp.bottom).offset(AppSpacing.xxl)
            make.centerX.equalToSuperview()
        }
        
        return view
    }()
    
    // MARK: - Bottom Button
    private lazy var bottomButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(L("下一步"), for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = AppFont.Button.primary
        btn.backgroundColor = AppColor.Brand.primary
        btn.layer.cornerRadius = AppSpacing.Corner.button
        btn.addTarget(self, action: #selector(bottomButtonTapped), for: .touchUpInside)
        return btn
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = L("注销账号")
        view.backgroundColor = AppColor.Background.primary
        
        setupUI()
        loadData()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        view.addSubview(bottomButton)
        view.addSubview(loadingView)
        
        scrollView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomButton.snp.top).offset(-AppSpacing.md)
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }
        
        bottomButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-AppSpacing.md)
            make.height.equalTo(46)
        }
        
        loadingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        // 初始默认加载提示
        contentView.addSubview(warningView)
        warningView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.greaterThanOrEqualTo(300)
        }
    }
    
    // MARK: - Actions
    @objc private func bottomButtonTapped() {
        switch currentStep {
        case .warning:
            currentStep = .inputReason
        case .inputReason:
            // 校验
            if selectedReason == nil && customReason.isEmpty {
                showToast(L("请选择或填写注销原因"))
                return
            }
            currentStep = .confirm
        case .confirm:
            // 这里的按钮在图5内部，不应该走到这里
            break
        case .reviewing:
            break
        }
    }
    
    @objc private func reasonTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        selectedReason = title
        
        // 刷新按钮选中状态 (简单实现，实际应使用 UITableView 单选高亮)
        if let stack = sender.superview as? UIStackView {
            for case let btn as UIButton in stack.arrangedSubviews {
                let isSelected = (btn == sender)
                btn.setTitleColor(isSelected ? AppColor.Brand.primary : AppColor.Text.primary, for: .normal)
                btn.titleLabel?.font = isSelected ? AppFont.Body.emphasized : AppFont.Body.regular
            }
        }
    }
    
    @objc private func submitTapped() {
        submitApplication()
    }
    
    @objc private func cancelApplicationTapped() {
        showConfirm(title: L("撤销注销"), message: L("确定要撤销账号注销申请吗？"), destructive: true) { [weak self] in
            self?.cancelApplication()
        }
    }
    
    // MARK: - Logic
    private func updateUIForStep() {
        // 移除所有子视图
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        let targetView: UIView
        switch currentStep {
        case .warning:
            targetView = warningView
            bottomButton.setTitle(L("填写注销申请"), for: .normal)
            bottomButton.isHidden = false
        case .inputReason:
            targetView = inputReasonView
            bottomButton.setTitle(L("下一步"), for: .normal)
            bottomButton.isHidden = false
        case .confirm:
            targetView = confirmView
            bottomButton.isHidden = true // 图5的按钮在页面内
        case .reviewing:
            targetView = reviewingView
            bottomButton.isHidden = true
        }
        
        contentView.addSubview(targetView)
        targetView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.greaterThanOrEqualTo(500)
        }
    }
    
    private func loadData() {
        loadingView.startAnimating()
        service.fetchStatus()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.loadingView.stopAnimating()
                if case .failure(let error) = completion {
                    self?.showToast(error.errorDescription ?? L("获取状态失败"))
                }
            } receiveValue: { [weak self] info in
                guard let self = self else { return }
                self.currentInfo = info
                
                if let info = info {
                    if info.isReviewing {
                        self.currentStep = .reviewing
                    } else if info.isRejected {
                        // 被驳回：弹窗提示，并允许重新申请
                        self.showAlert(L("您的注销申请被驳回：\(info.cancelReason ?? "未知原因")"), title: L("提示")) {
                            self.currentStep = .warning
                        }
                    } else {
                        self.currentStep = .warning
                    }
                } else {
                    self.currentStep = .warning
                }
            }
            .store(in: &cancellables)
    }
    
    private func submitApplication() {
        loadingView.startAnimating()
        let type = selectedReason ?? ""
        let reason = customReason
        
        service.submit(cancelType: type, cancelReason: reason)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.loadingView.stopAnimating()
                if case .failure(let error) = completion {
                    self?.showToast(error.errorDescription ?? L("提交失败"))
                }
            } receiveValue: { [weak self] _ in
                guard let self = self else { return }
                self.showToast(L("申请已提交"))
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.navigationController?.popViewController(animated: true)
                }
            }
            .store(in: &cancellables)
    }
    
    private func cancelApplication() {
        loadingView.startAnimating()
        service.cancelSubmit()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.loadingView.stopAnimating()
                if case .failure(let error) = completion {
                    self?.showToast(error.errorDescription ?? L("撤销失败"))
                }
            } receiveValue: { [weak self] _ in
                guard let self = self else { return }
                self.showToast(L("已撤销注销申请"))
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.navigationController?.popViewController(animated: true)
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - UITextViewDelegate
extension AccountCancelViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        customReason = textView.text
    }
}

//
//  AccountCancelViewController.swift
//  SleepEarphones
//

import UIKit
import SnapKit
import Combine

@MainActor
final class AccountCancelViewController: UIViewController {

    // MARK: - Step
    
    /// 页面状态机
    private enum Step {
        case loading      // 首次加载中
        case warning      // 第一步：警告
        case inputReason  // 第二步：选择+输入
        case confirm      // 第三步：风险确认
        case reviewing    // 状态：审核中
    }
    
    // MARK: - Properties
    
    private let service: AccountCancelServiceProtocol = AccountCancelService()
    private var cancellables = Set<AnyCancellable>()
    private var currentInfo: AccountCancelInfo?
    
    /// 动态获取的注销原因列表
    private var reasons: [CancelReason] = []
    
    /// 当前步骤（触发 UI 刷新）
    private var currentStep: Step = .loading {
        didSet { updateUIForStep() }
    }
    
    /// 选中的原因
    private var selectedReason: CancelReason?
    /// 自定义输入的原因
    private var customReason: String = ""
    
    // MARK: - UI Components (Base)
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    /// 首次进入的全屏加载菊花
    private lazy var fullScreenLoadingView: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(style: .large)
        v.hidesWhenStopped = true
        v.color = AppColor.Text.tertiary
        return v
    }()
    
    /// 底部固定主按钮
    private lazy var bottomButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.titleLabel?.font = AppFont.Button.primary
        btn.backgroundColor = AppColor.Brand.primary
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = AppSpacing.Corner.button
        btn.addTarget(self, action: #selector(bottomButtonTapped), for: .touchUpInside)
        return btn
    }()
    
    // MARK: - UI (Step 1: Warning)
    
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
    
    // MARK: - UI (Step 2: Input Reason)
    
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
        
        // 动态原因列表容器
        let reasonStack = UIStackView()
        reasonStack.axis = .vertical
        reasonStack.spacing = AppSpacing.md
        reasonStack.tag = 1000 // 用 tag 标记以便后续渲染
        
        let line2 = UIView()
        line2.backgroundColor = AppColor.separator
        
        let inputTitleLabel = UILabel()
        inputTitleLabel.text = L("请填写注销原因（选填）")
        inputTitleLabel.font = AppFont.Body.emphasized
        
        let textView = UITextView()
        textView.backgroundColor = AppColor.Background.secondary
        textView.layer.cornerRadius = AppSpacing.Corner.medium
        textView.font = AppFont.Body.regular
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        textView.delegate = self
        textView.tag = 999
        
        [titleLabel, descLabel, line1, selectTitleLabel, reasonStack, line2, inputTitleLabel, textView].forEach {
            view.addSubview($0)
        }
        
        // 布局代码保持不变...
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
            make.top.equalTo(line1.snp.bottom).offset(AppSpacing.lg)
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
            make.top.equalTo(line2.snp.bottom).offset(AppSpacing.lg)
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
    
    // MARK: - UI (Step 3: Confirm Risks)
    
    private lazy var confirmView: UIView = {
        let view = UIView()
        
        // ... 视图配置省略（保持一致，只保留核心逻辑展示）
        let titleLabel = UILabel()
        titleLabel.text = L("账号注销")
        titleLabel.font = AppFont.Title.section
        
        let risksLabel = UILabel()
        risksLabel.text = L("""
                            账号注销后将放弃以下权益：
                            1、账号信息、第三方授权信息将被清空且无法恢复。
                            2、账号相关信息将会一并被删除且无法恢复。
                            3、注销后手机号码可重新注册，所生成账号为全新的账号，不包含注销账号的任何信息。
                            """)
        risksLabel.font = AppFont.Body.regular
        risksLabel.numberOfLines = 0
        
        let checkButton = UIButton(type: .system)
        checkButton.setTitle(L("我已清楚风险，确定继续"), for: .normal)
        checkButton.titleLabel?.font = AppFont.Button.primary
        checkButton.setTitleColor(AppColor.Text.primary, for: .normal)
        checkButton.layer.borderWidth = 1
        checkButton.layer.borderColor = AppColor.separator.cgColor
        checkButton.layer.cornerRadius = AppSpacing.Corner.button
        checkButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        
        [titleLabel, risksLabel, checkButton].forEach { view.addSubview($0) }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(AppSpacing.lg)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
        }
        risksLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(AppSpacing.xl)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
        }
        checkButton.snp.makeConstraints { make in
            make.top.equalTo(risksLabel.snp.bottom).offset(AppSpacing.xxl)
            make.leading.trailing.equalToSuperview().inset(AppSpacing.lg)
            make.height.equalTo(46)
            make.bottom.equalToSuperview()
        }
        
        return view
    }()
    
    // MARK: - UI (Step 4: Reviewing)
    
    private lazy var reviewingView: UIView = {
        let view = UIView()
        
        // ... 视图配置
        let icon = UIImageView(image: UIImage(systemName: "hourglass"))
        icon.tintColor = AppColor.Brand.primary
        
        let titleLabel = UILabel()
        titleLabel.text = L("注销申请审核中")
        titleLabel.font = AppFont.Title.section
        titleLabel.textAlignment = .center
        
        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle(L("撤销注销申请"), for: .normal)
        cancelBtn.setTitleColor(AppColor.Semantic.error, for: .normal)
        cancelBtn.addTarget(self, action: #selector(cancelApplicationTapped), for: .touchUpInside)
        
        [icon, titleLabel, cancelBtn].forEach { view.addSubview($0) }
        
        icon.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(80)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(60)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(icon.snp.bottom).offset(AppSpacing.lg)
            make.centerX.equalToSuperview()
        }
        cancelBtn.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(AppSpacing.xxl)
            make.centerX.equalToSuperview()
        }
        
        return view
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
        view.addSubview(fullScreenLoadingView)
        
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
        fullScreenLoadingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    // MARK: - Data Loading
    
    /// 并发获取状态和原因列表
    private func loadData() {
        // 失败降级处理：状态获取失败当作无记录，原因获取失败当作空列表
        let statusPublisher = service.fetchStatus()
            .replaceError(with: nil)
            
        let reasonsPublisher = service.fetchReasons()
            .replaceError(with: [])
            
        Publishers.Zip(statusPublisher, reasonsPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info, reasonList in
                guard let self = self else { return }
                self.currentInfo = info
                self.reasons = reasonList
                
                if let info = info {
                    if info.isReviewing {
                        self.currentStep = .reviewing
                    } else if info.isRejected {
                        // 被驳回：先弹窗提示，再引导重新发起
                        self.currentStep = .warning
                        self.showAlert(
                            L("您的注销申请被驳回：\(info.cancelReason ?? "未知原因")"),
                            title: L("提示")
                        )
                    } else {
                        self.currentStep = .warning
                    }
                } else {
                    self.currentStep = .warning
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - UI Rendering
    
    private func updateUIForStep() {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        let targetView: UIView
        
        switch currentStep {
        case .loading:
            fullScreenLoadingView.startAnimating()
            bottomButton.isHidden = true
            return
            
        case .warning:
            targetView = warningView
            bottomButton.setTitle(L("填写注销申请"), for: .normal)
            bottomButton.isHidden = false
            
        case .inputReason:
            targetView = inputReasonView
            renderReasonButtons() // 渲染动态数据
            bottomButton.setTitle(L("下一步"), for: .normal)
            bottomButton.isHidden = false
            
        case .confirm:
            targetView = confirmView
            bottomButton.isHidden = true
            
        case .reviewing:
            targetView = reviewingView
            bottomButton.isHidden = true
        }
        
        fullScreenLoadingView.stopAnimating()
        contentView.addSubview(targetView)
        targetView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.greaterThanOrEqualTo(500)
        }
    }
    
    /// 根据接口数据渲染原因列表（带单选框）
    private func renderReasonButtons() {
        guard let stack = inputReasonView.viewWithTag(1000) as? UIStackView else { return }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for reason in reasons {
            let isSelected = (selectedReason?.aid == reason.aid)
            
            // 使用 Configuration 统一管理图标和文字排版
            var config = UIButton.Configuration.plain()
            // 去除默认 padding，靠左对齐，上下留白方便点击
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
            config.imagePlacement = .leading
            config.imagePadding = 12 // 图标与文字的间距
            
            // 设置图标：选中为实心对勾，未选中为空心圆圈
            let iconName = isSelected ? "checkmark.circle.fill" : "circle"
            config.image = UIImage(systemName: iconName)
            
            // 设置文字样式
            var titleAttr = AttributedString(reason.name)
            titleAttr.font = isSelected ? AppFont.Body.emphasized : AppFont.Body.regular
            config.attributedTitle = titleAttr
            
            // 设置整体颜色（图标和文字同步变色）
            config.baseForegroundColor = isSelected ? AppColor.Brand.primary : AppColor.Text.primary
            
            let btn = UIButton(configuration: config)
            btn.contentHorizontalAlignment = .leading
            
            // 使用 UIAction 闭包捕获对应的 reason
            btn.addAction(UIAction { [weak self] _ in
                self?.handleReasonSelection(reason: reason)
            }, for: .touchUpInside)
            
            stack.addArrangedSubview(btn)
        }
    }
    
    // MARK: - Actions
    
    /// 处理单选逻辑
    private func handleReasonSelection(reason: CancelReason) {
        // 更新当前选中的原因
        selectedReason = reason
        // 重新渲染整个列表（全局刷新状态最稳妥）
        renderReasonButtons()
    }
    
    @objc private func bottomButtonTapped() {
        switch currentStep {
        case .warning:
            currentStep = .inputReason
        case .inputReason:
            // 校验：接口原因未选且手动输入为空
            if selectedReason == nil && customReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showToast(L("请选择或填写注销原因"))
                return
            }
            currentStep = .confirm
        default:
            break
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
    
    // MARK: - Network Request
    
    private func submitApplication() {
        fullScreenLoadingView.startAnimating()
        
        // 优先取选中的 aid，没有则传空，并传自定义文本
        let typeId = selectedReason?.aid ?? ""
        let reasonText = customReason.trimmingCharacters(in: .whitespacesAndNewlines)
        
        service.submit(cancelType: typeId, cancelReason: reasonText)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.fullScreenLoadingView.stopAnimating()
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
        fullScreenLoadingView.startAnimating()
        service.cancelSubmit()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.fullScreenLoadingView.stopAnimating()
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

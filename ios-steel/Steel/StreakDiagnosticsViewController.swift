import UIKit
import SnapKit
import SPIndicator

final class StreakDiagnosticsViewController: UIViewController {
    private let backgroundView = PersonalBackgroundView()
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let headerContainer = UIView()

    // Streak
    private let streakNumberLabel = UILabel()
    private let bestLabel = UILabel()
    private let statusLabel = UILabel()
    private let milestoneLabel = UILabel()

    // Progress
    private let progressRingView = ProgressRingView()
    private let progressPercentLabel = UILabel()
    private let tasksListStack = UIStackView()

    // Calendar
    private let calendarStack = UIStackView()

    // AI
    private let diagnoseButton = UIButton(type: .system)
    private let aiLoadingIndicator = UIActivityIndicatorView(style: .medium)
    private let aiResultLabel = UILabel()
    private let aiCard = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        // Keep navigation bar visible for back navigation
        navigationController?.navigationBar.isHidden = false
        navigationItem.title = "Диагностика серии"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(goBack)
        )

        setupBackground()
        setupScrollView()
        setupStreakCard()
        setupProgressCard()
        setupCalendarCard()
        setupAICard()
        refresh()

        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .steelSettingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .steelTasksChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadBackground), name: .steelBackgroundChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        backgroundView.apply(BackgroundManager.shared.config)
        backgroundView.resumeVideo()
        refresh()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backgroundView.pauseVideo()
    }

    private func setupBackground() {
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        backgroundView.apply(BackgroundManager.shared.config)
    }

    @objc private func goBack() {
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }

        contentStack.axis = .vertical
        contentStack.spacing = 20
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(8)
            $0.leading.trailing.equalTo(view).inset(20)
            $0.bottom.equalToSuperview().inset(40)
            $0.width.equalTo(view).inset(20)
        }
    }

    // MARK: - Streak Card (Liquid Glass)

    private func setupStreakCard() {
        let card = makeLiquidGlassCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(24) }

        // Flame icon
        let flameIcon = UIImageView(image: UIImage(systemName: "flame.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)))
        flameIcon.tintColor = .systemOrange
        flameIcon.contentMode = .scaleAspectFit

        streakNumberLabel.font = UIFont.systemFont(ofSize: 72, weight: .heavy)
        streakNumberLabel.textColor = .label
        streakNumberLabel.textAlignment = .center

        let caption = UILabel()
        caption.text = "ДНЕЙ СЕРИЯ"
        caption.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        caption.textColor = .secondaryLabel
        caption.textAlignment = .center
        caption.letterSpacing = 2

        let divider = UIView()
        divider.backgroundColor = .separator
        divider.layer.cornerRadius = 0.25
        divider.snp.makeConstraints { $0.height.equalTo(0.5) }

        let infoStack = UIStackView()
        infoStack.axis = .vertical
        infoStack.spacing = 14
        infoStack.alignment = .fill

        bestLabel.font = UIFont.preferredFont(forTextStyle: .body)
        statusLabel.font = UIFont.preferredFont(forTextStyle: .body)
        milestoneLabel.font = UIFont.preferredFont(forTextStyle: .body)
        milestoneLabel.textColor = .systemOrange

        infoStack.addArrangedSubviews([
            makeInfoRow(icon: "trophy.fill", iconColor: .systemYellow, label: "Лучшая серия", value: bestLabel),
            makeInfoRow(icon: "circle.fill", iconColor: .systemGreen, label: "Статус", value: statusLabel),
            makeInfoRow(icon: "flag.fill", iconColor: .systemOrange, label: "До рубежа", value: milestoneLabel),
        ])

        stack.addArrangedSubviews([flameIcon, streakNumberLabel, caption, divider, infoStack])
        contentStack.addArrangedSubview(card)
    }

    // MARK: - Progress Card (Liquid Glass)

    private func setupProgressCard() {
        let card = makeLiquidGlassCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(24) }

        let sectionTitle = UILabel()
        sectionTitle.text = "ПРОГРЕСС ЗА СЕГОДНЯ"
        sectionTitle.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        sectionTitle.textColor = .secondaryLabel
        sectionTitle.letterSpacing = 2

        progressRingView.snp.makeConstraints { $0.size.equalTo(110) }

        progressPercentLabel.font = UIFont.systemFont(ofSize: 40, weight: .bold)
        progressPercentLabel.textColor = .label
        progressPercentLabel.textAlignment = .center

        tasksListStack.axis = .vertical
        tasksListStack.spacing = 8
        tasksListStack.alignment = .fill

        stack.addArrangedSubviews([sectionTitle, progressRingView, progressPercentLabel, tasksListStack])
        contentStack.addArrangedSubview(card)
    }

    // MARK: - Calendar Card (Liquid Glass)

    private func setupCalendarCard() {
        let card = makeLiquidGlassCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .center
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(20) }

        let sectionTitle = UILabel()
        sectionTitle.text = "14 ДНЕЙ"
        sectionTitle.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        sectionTitle.textColor = .secondaryLabel
        sectionTitle.letterSpacing = 2

        calendarStack.axis = .horizontal
        calendarStack.distribution = .equalSpacing
        calendarStack.alignment = .center

        stack.addArrangedSubviews([sectionTitle, calendarStack])
        contentStack.addArrangedSubview(card)
    }

    // MARK: - AI Card (Liquid Glass)

    private func setupAICard() {
        let card = makeLiquidGlassCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(20) }

        diagnoseButton.setTitle("Диагностика от ИИ", for: .normal)
        diagnoseButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        diagnoseButton.setTitleColor(.white, for: .normal)
        diagnoseButton.backgroundColor = .systemBlue
        diagnoseButton.layer.cornerRadius = 14
        diagnoseButton.layer.cornerCurve = .continuous
        diagnoseButton.setImage(UIImage(systemName: "sparkles"), for: .normal)
        diagnoseButton.tintColor = .white
        diagnoseButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        diagnoseButton.addTarget(self, action: #selector(runDiagnostics), for: .touchUpInside)
        diagnoseButton.snp.makeConstraints { $0.height.equalTo(50) }

        aiLoadingIndicator.hidesWhenStopped = true
        aiLoadingIndicator.color = .secondaryLabel

        aiResultLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        aiResultLabel.textColor = .label
        aiResultLabel.numberOfLines = 0
        aiResultLabel.isHidden = true

        aiCard.layer.cornerRadius = 14
        aiCard.layer.cornerCurve = .continuous
        aiCard.clipsToBounds = true
        aiCard.isHidden = true

        aiCard.contentView.addSubview(aiResultLabel)
        aiResultLabel.snp.makeConstraints { $0.edges.equalToSuperview().inset(14) }

        stack.addArrangedSubviews([diagnoseButton, aiLoadingIndicator, aiCard])
        contentStack.addArrangedSubview(card)
    }

    // MARK: - Refresh

    @objc private func refresh() {
        let settings = DataManager.shared.settings
        let tasks = DataManager.shared.fetchTasks()
        let habits = DataManager.shared.fetchHabits()

        streakNumberLabel.text = "\(settings.streakDays)"

        let habitBest = habits.map(\.bestStreak).max() ?? 0
        bestLabel.text = "\(max(habitBest, settings.streakDays)) дн."

        if settings.streakPaused {
            statusLabel.text = "На паузе"
            statusLabel.textColor = .systemOrange
        } else if settings.streakDays > 0 {
            statusLabel.text = "Активна"
            statusLabel.textColor = .systemGreen
        } else {
            statusLabel.text = "Сброшена"
            statusLabel.textColor = .systemRed
        }

        let milestones = [7, 14, 30, 60, 90, 180, 365]
        let next = milestones.first { $0 > settings.streakDays } ?? 365
        milestoneLabel.text = "\(next - settings.streakDays) дн. до \(next)"

        // Progress
        let done = tasks.filter(\.isCompleted).count
        let total = tasks.count
        let pct = total > 0 ? Int(Double(done) / Double(total) * 100) : 0
        progressRingView.setProgress(CGFloat(pct) / 100.0, animated: true)
        progressPercentLabel.text = "\(pct)%"

        tasksListStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for task in tasks {
            let row = makeTaskCheckRow(title: task.title, detail: task.displayDetail, done: task.isCompleted)
            tasksListStack.addArrangedSubview(row)
        }
        if tasks.isEmpty {
            let empty = UILabel()
            empty.text = "Нет заданий на сегодня"
            empty.font = UIFont.preferredFont(forTextStyle: .subheadline)
            empty.textColor = .tertiaryLabel
            tasksListStack.addArrangedSubview(empty)
        }

        // Calendar
        calendarStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for offset in (0..<14).reversed() {
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayKey = DataManager.shared.dayKey(for: date)
            let col = UIStackView()
            col.axis = .vertical
            col.spacing = 4
            col.alignment = .center

            let dot = UIView()
            dot.layer.cornerRadius = 8
            dot.snp.makeConstraints { $0.size.equalTo(16) }
            if offset == 0 {
                dot.backgroundColor = .systemBlue
                dot.layer.borderWidth = 2
                dot.layer.borderColor = UIColor.systemBlue.cgColor
            } else if settings.lastCompletedDayKey == dayKey {
                dot.backgroundColor = .systemGreen
            } else {
                dot.backgroundColor = .systemGray5
            }

            let numLabel = UILabel()
            numLabel.text = "\(cal.component(.day, from: date))"
            numLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
            numLabel.textColor = .secondaryLabel

            col.addArrangedSubviews([dot, numLabel])
            calendarStack.addArrangedSubview(col)
        }
    }

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
    }

    // MARK: - AI Diagnostics

    @objc private func runDiagnostics() {
        UIImpactFeedbackGenerator.tap(.medium)
        guard !KeychainHelper.groqAPIKey.isEmpty else {
            SPIndicator.present(title: "Нет API ключа", message: "Добавьте в Настройки → Провайдеры", preset: .error, haptic: .error)
            return
        }

        diagnoseButton.isEnabled = false
        diagnoseButton.alpha = 0.5
        aiLoadingIndicator.startAnimating()
        aiCard.isHidden = true
        aiResultLabel.isHidden = true

        let settings = DataManager.shared.settings
        let tasks = DataManager.shared.fetchTasks()
        let habits = DataManager.shared.fetchHabits()
        let prompt = buildDiagnosticsPrompt(settings: settings, tasks: tasks, habits: habits)

        Task { @MainActor in
            do {
                let result = try await GroqAI.send(history: [GroqTurn(role: "user", content: prompt)])
                aiLoadingIndicator.stopAnimating()
                diagnoseButton.isEnabled = true
                diagnoseButton.alpha = 1
                aiResultLabel.text = result.message.isEmpty ? "Не удалось получить диагностику" : result.message
                aiResultLabel.isHidden = false
                aiCard.isHidden = false
                UINotificationFeedbackGenerator.notify(.success)
            } catch {
                aiLoadingIndicator.stopAnimating()
                diagnoseButton.isEnabled = true
                diagnoseButton.alpha = 1
                aiResultLabel.text = "Ошибка: \(error.localizedDescription)"
                aiResultLabel.isHidden = false
                aiCard.isHidden = false
                SPIndicator.present(title: "Ошибка", preset: .error, haptic: .error)
            }
        }
    }

    private func buildDiagnosticsPrompt(settings: AppSettings, tasks: [DailyTask], habits: [Habit]) -> String {
        let done = tasks.filter(\.isCompleted).count
        let total = tasks.count
        let pct = total > 0 ? Int(Double(done) / Double(total) * 100) : 0
        var taskList = tasks.map { "- \($0.title) (\($0.displayDetail)): \($0.isCompleted ? "✅" : "⬜")" }.joined(separator: "\n")
        if taskList.isEmpty { taskList = "Нет заданий" }
        var habitList = habits.map { "- \($0.title): \($0.cleanDays) дн. чисто, лучший \($0.bestStreak) дн." }.joined(separator: "\n")
        if habitList.isEmpty { habitList = "Нет привычек" }

        return """
        Проанализируй мои данные в Steel и составь короткую диагностику серии на русском языке. 3-4 предложения. Конкретные рекомендации. Всё строго на русском языке — никаких английских слов.
        Серия: \(settings.streakDays) дней. Пауза: \(settings.streakPaused ? "да" : "нет"). Выполнено сегодня: \(pct)%. Задания: \(taskList). Привычки: \(habitList).
        """
    }

    // MARK: - Helpers

    /// Liquid glass card with blur + border + subtle glow
    private func makeLiquidGlassCard() -> UIVisualEffectView {
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        card.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.5)
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        // Subtle inner shadow/glow for liquid glass look
        card.layer.shadowColor = UIColor.white.withAlphaComponent(0.1).cgColor
        card.layer.shadowOpacity = 0.5
        card.layer.shadowRadius = 10
        card.layer.shadowOffset = .zero
        return card
    }

    private func makeInfoRow(icon: String, iconColor: UIColor, label: String, value: UILabel) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)))
        iconView.tintColor = iconColor
        iconView.snp.makeConstraints { $0.size.equalTo(22) }

        let titleLabel = UILabel()
        titleLabel.text = label
        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = .secondaryLabel
        value.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(.semibold)

        let row = UIStackView(arrangedSubviews: [iconView, titleLabel, UIView(), value])
        row.alignment = .center
        row.spacing = 8
        return row
    }

    private func makeTaskCheckRow(title: String, detail: String, done: Bool) -> UIView {
        let check = UIImageView(image: UIImage(systemName: done ? "checkmark.circle.fill" : "circle"))
        check.tintColor = done ? .systemGreen : .systemGray3
        check.snp.makeConstraints { $0.size.equalTo(22) }

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(.medium)
        titleLabel.textColor = done ? .secondaryLabel : .label

        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        detailLabel.textColor = .tertiaryLabel

        let text = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        text.axis = .vertical
        text.spacing = 1

        let row = UIStackView(arrangedSubviews: [check, text])
        row.spacing = 10
        row.alignment = .center
        return row
    }
}

extension UIStackView {
    func addArrangedSubviews(_ views: [UIView]) {
        views.forEach { addArrangedSubview($0) }
    }
}

// MARK: - UILabel letter spacing
extension UILabel {
    var letterSpacing: CGFloat {
        get { 0 }
        set {
            guard let text = text else { return }
            let attrs: [NSAttributedString.Key: Any] = [
                .kern: newValue,
                .font: font as Any,
                .foregroundColor: textColor as Any
            ]
            attributedText = NSAttributedString(string: text, attributes: attrs)
        }
    }
}

// MARK: - Progress Ring
private final class ProgressRingView: UIView {
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let lineWidth: CGFloat = 10

    override init(frame: CGRect) { super.init(frame: frame); setupLayers() }
    required init?(coder: NSCoder) { super.init(coder: coder); setupLayers() }

    private func setupLayers() {
        backgroundColor = .clear
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor.systemGray5.cgColor
        trackLayer.lineWidth = lineWidth
        trackLayer.lineCap = .round
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.systemGreen.cgColor
        progressLayer.lineWidth = lineWidth
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        layer.addSublayer(trackLayer)
        layer.addSublayer(progressLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = (min(bounds.width, bounds.height) - lineWidth) / 2
        let path = UIBezierPath(arcCenter: center, radius: max(1, radius), startAngle: -.pi / 2, endAngle: 3 * .pi / 2, clockwise: true)
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }

    func setProgress(_ value: CGFloat, animated: Bool) {
        let clamped = min(1, max(0, value))
        if clamped >= 0.8 { progressLayer.strokeColor = UIColor.systemGreen.cgColor }
        else if clamped >= 0.5 { progressLayer.strokeColor = UIColor.systemOrange.cgColor }
        else { progressLayer.strokeColor = UIColor.systemRed.cgColor }
        if animated {
            let anim = CABasicAnimation(keyPath: "strokeEnd")
            anim.fromValue = progressLayer.strokeEnd
            anim.toValue = clamped
            anim.duration = 0.5
            anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            progressLayer.add(anim, forKey: "progress")
        }
        progressLayer.strokeEnd = clamped
    }
}

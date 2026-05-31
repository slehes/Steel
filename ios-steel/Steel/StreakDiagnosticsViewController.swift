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
        navigationController?.navigationBar.isHidden = true
        setupBackground()
        setupHeader()
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

    private func setupHeader() {
        headerContainer.backgroundColor = .clear
        view.addSubview(headerContainer)
        headerContainer.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(52)
        }

        let back = UIButton(type: .system)
        back.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        back.tintColor = .label
        back.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        back.snp.makeConstraints { $0.size.equalTo(32) }

        let titleLabel = UILabel()
        titleLabel.text = "Диагностика серии"
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .label

        let header = UIStackView(arrangedSubviews: [back, titleLabel])
        header.alignment = .center
        header.spacing = 10
        headerContainer.addSubview(header)
        header.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(20)
        }
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
        scrollView.contentInset.top = 56
        scrollView.scrollIndicatorInsets.top = 56
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

    // MARK: - Streak Card

    private func setupStreakCard() {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(24) }

        streakNumberLabel.font = UIFont.systemFont(ofSize: 80, weight: .heavy)
        streakNumberLabel.textColor = .label
        streakNumberLabel.textAlignment = .center

        let caption = UILabel()
        caption.text = "ДНЕЙ СЕРИЯ"
        caption.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        caption.textColor = .secondaryLabel
        caption.textAlignment = .center

        let divider = UIView()
        divider.backgroundColor = .separator
        divider.snp.makeConstraints { $0.height.equalTo(0.5) }

        let infoStack = UIStackView()
        infoStack.axis = .vertical
        infoStack.spacing = 12
        infoStack.alignment = .fill

        bestLabel.font = UIFont.preferredFont(forTextStyle: .body)
        statusLabel.font = UIFont.preferredFont(forTextStyle: .body)
        milestoneLabel.font = UIFont.preferredFont(forTextStyle: .body)
        milestoneLabel.textColor = .systemOrange

        infoStack.addArrangedSubviews([
            makeInfoRow(label: "Лучшая серия", value: bestLabel),
            makeInfoRow(label: "Статус", value: statusLabel),
            makeInfoRow(label: "До рубежа", value: milestoneLabel),
        ])

        stack.addArrangedSubviews([streakNumberLabel, caption, divider, infoStack])
        contentStack.addArrangedSubview(card)
    }

    // MARK: - Progress Card

    private func setupProgressCard() {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(24) }

        let sectionTitle = UILabel()
        sectionTitle.text = "ПРОГРЕСС ЗА СЕГОДНЯ"
        sectionTitle.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        sectionTitle.textColor = .secondaryLabel

        progressPercentLabel.font = UIFont.systemFont(ofSize: 36, weight: .bold)
        progressPercentLabel.textColor = .label
        progressPercentLabel.textAlignment = .center

        progressRingView.snp.makeConstraints { $0.size.equalTo(100) }

        tasksListStack.axis = .vertical
        tasksListStack.spacing = 8
        tasksListStack.alignment = .fill

        stack.addArrangedSubviews([sectionTitle, progressRingView, progressPercentLabel, tasksListStack])
        contentStack.addArrangedSubview(card)
    }

    // MARK: - Calendar Card

    private func setupCalendarCard() {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(20) }

        let sectionTitle = UILabel()
        sectionTitle.text = "14 ДНЕЙ"
        sectionTitle.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        sectionTitle.textColor = .secondaryLabel

        calendarStack.axis = .horizontal
        calendarStack.distribution = .equalSpacing
        calendarStack.alignment = .center

        stack.addArrangedSubviews([sectionTitle, calendarStack])
        contentStack.addArrangedSubview(card)
    }

    // MARK: - AI Card

    private func setupAICard() {
        let card = makeCard()
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
        diagnoseButton.snp.makeConstraints { $0.height.equalTo(48) }

        aiLoadingIndicator.hidesWhenStopped = true
        aiLoadingIndicator.color = .secondaryLabel

        aiResultLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        aiResultLabel.textColor = .label
        aiResultLabel.numberOfLines = 0
        aiResultLabel.isHidden = true

        aiCard.backgroundColor = .tertiarySystemBackground
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
            dot.layer.cornerRadius = 7
            dot.snp.makeConstraints { $0.size.equalTo(14) }
            if offset == 0 {
                dot.backgroundColor = .systemBlue
            } else if settings.lastCompletedDayKey == dayKey {
                dot.backgroundColor = .systemGreen
            } else {
                dot.backgroundColor = .systemGray5
            }

            let numLabel = UILabel()
            numLabel.text = "\(cal.component(.day, from: date))"
            numLabel.font = UIFont.systemFont(ofSize: 9)
            numLabel.textColor = .tertiaryLabel

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

    private func makeCard() -> UIVisualEffectView {
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 18
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        return card
    }

    private func makeInfoRow(label: String, value: UILabel) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = label
        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = .secondaryLabel
        value.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(.semibold)
        let row = UIStackView(arrangedSubviews: [titleLabel, UIView(), value])
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

private extension UIStackView {
    func addArrangedSubviews(_ views: [UIView]) {
        views.forEach { addArrangedSubview($0) }
    }
}

// MARK: - Progress Ring
private final class ProgressRingView: UIView {
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let lineWidth: CGFloat = 8

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

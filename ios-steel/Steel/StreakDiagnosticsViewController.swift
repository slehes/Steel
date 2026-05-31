import UIKit
import SnapKit
import SPIndicator

final class StreakDiagnosticsViewController: UIViewController {

    // MARK: - Subviews

    private let backgroundView = PersonalBackgroundView()
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Streak Overview
    private let streakNumberLabel = UILabel()
    private let streakCaptionLabel = UILabel()
    private let bestStreakValueLabel = UILabel()
    private let statusValueLabel = UILabel()
    private let startDateValueLabel = UILabel()
    private let milestoneValueLabel = UILabel()

    // Today's Progress
    private let progressRingView = ProgressRingView()
    private let progressPercentLabel = UILabel()
    private let tasksStack = UIStackView()
    private let habitsStack = UIStackView()

    // Activity Calendar
    private let calendarDotsStack = UIStackView()
    private let calendarDatesStack = UIStackView()

    // Statistics
    private let statsStack = UIStackView()

    // AI Diagnostics
    private let diagnoseButton = UIButton(type: .system)
    private let aiLoadingIndicator = UIActivityIndicatorView(style: .medium)
    private let aiResultLabel = UILabel()
    private let aiCard = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))

    // History
    private let historyStack = UIStackView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .always
        title = "Диагностика серии"

        setupBackground()
        setupScrollView()
        setupStreakOverview()
        setupTodayProgress()
        setupActivityCalendar()
        setupStatistics()
        setupAIDiagnostics()
        setupHistory()

        NotificationCenter.default.addObserver(self, selector: #selector(refreshAll), name: .steelSettingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshAll), name: .steelTasksChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadBackground), name: .steelBackgroundChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        backgroundView.apply(BackgroundManager.shared.config)
        backgroundView.resumeVideo()
        refreshAll()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backgroundView.pauseVideo()
    }

    // MARK: - Background

    private func setupBackground() {
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        backgroundView.apply(BackgroundManager.shared.config)
    }

    // MARK: - ScrollView

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.alwaysBounceVertical = true
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }

        contentStack.axis = .vertical
        contentStack.spacing = 24
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.leading.trailing.equalTo(view).inset(20)
            $0.bottom.equalToSuperview().inset(40)
            $0.width.equalTo(view).inset(20)
        }
    }

    // MARK: - A) Streak Overview

    private func setupStreakOverview() {
        let sectionTitle = makeSectionTitle("ОБЗОР СЕРИИ")
        contentStack.addArrangedSubview(sectionTitle)

        let card = makeCard()

        // Big streak number
        streakNumberLabel.font = UIFont.systemFont(ofSize: 72, weight: .heavy)
        streakNumberLabel.textColor = .label
        streakNumberLabel.textAlignment = .center

        streakCaptionLabel.text = "ТЕКУЩАЯ СЕРИЯ"
        streakCaptionLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        streakCaptionLabel.textColor = .secondaryLabel
        streakCaptionLabel.textAlignment = .center

        let heroStack = UIStackView(arrangedSubviews: [streakNumberLabel, streakCaptionLabel])
        heroStack.axis = .vertical
        heroStack.spacing = 2
        heroStack.alignment = .center

        // Detail rows
        let detailsStack = UIStackView()
        detailsStack.axis = .vertical
        detailsStack.spacing = 0

        bestStreakValueLabel.font = UIFont.preferredFont(forTextStyle: .body).withWeight(.semibold)
        statusValueLabel.font = UIFont.preferredFont(forTextStyle: .body).withWeight(.semibold)
        startDateValueLabel.font = UIFont.preferredFont(forTextStyle: .body).withWeight(.semibold)
        milestoneValueLabel.font = UIFont.preferredFont(forTextStyle: .body).withWeight(.semibold)
        milestoneValueLabel.textColor = .systemOrange

        let rows: [(String, UILabel)] = [
            ("Лучшая серия", bestStreakValueLabel),
            ("Статус", statusValueLabel),
            ("Начало серии", startDateValueLabel),
            ("До следующего рубежа", milestoneValueLabel),
        ]

        for (index, row) in rows.enumerated() {
            let rowView = makeDetailRow(title: row.0, valueLabel: row.1, isLast: index == rows.count - 1)
            detailsStack.addArrangedSubview(rowView)
        }

        let cardStack = UIStackView(arrangedSubviews: [heroStack, detailsStack])
        cardStack.axis = .vertical
        cardStack.spacing = 16

        card.contentView.addSubview(cardStack)
        cardStack.snp.makeConstraints { $0.edges.equalToSuperview().inset(20) }

        contentStack.addArrangedSubview(card)
    }

    // MARK: - B) Today's Progress

    private func setupTodayProgress() {
        let sectionTitle = makeSectionTitle("ПРОГРЕСС ЗА СЕГОДНЯ")
        contentStack.addArrangedSubview(sectionTitle)

        let card = makeCard()

        // Progress ring + percentage
        progressPercentLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        progressPercentLabel.textColor = .label
        progressPercentLabel.textAlignment = .center

        let ringContainer = UIStackView(arrangedSubviews: [progressRingView, progressPercentLabel])
        ringContainer.axis = .vertical
        ringContainer.spacing = 8
        ringContainer.alignment = .center

        progressRingView.snp.makeConstraints { $0.size.equalTo(120) }

        // Tasks label
        let tasksHeader = UILabel()
        tasksHeader.text = "Задания"
        tasksHeader.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(.semibold)
        tasksHeader.textColor = .secondaryLabel

        tasksStack.axis = .vertical
        tasksStack.spacing = 6

        // Habits label
        let habitsHeader = UILabel()
        habitsHeader.text = "Привычки"
        habitsHeader.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(.semibold)
        habitsHeader.textColor = .secondaryLabel

        habitsStack.axis = .vertical
        habitsStack.spacing = 6

        let cardStack = UIStackView(arrangedSubviews: [
            ringContainer, tasksHeader, tasksStack, habitsHeader, habitsStack
        ])
        cardStack.axis = .vertical
        cardStack.spacing = 10

        card.contentView.addSubview(cardStack)
        cardStack.snp.makeConstraints { $0.edges.equalToSuperview().inset(20) }

        contentStack.addArrangedSubview(card)
    }

    // MARK: - C) Activity Calendar

    private func setupActivityCalendar() {
        let sectionTitle = makeSectionTitle("Календарь активности")
        contentStack.addArrangedSubview(sectionTitle)

        let card = makeCard()

        calendarDotsStack.axis = .horizontal
        calendarDotsStack.distribution = .equalSpacing
        calendarDotsStack.alignment = .center

        calendarDatesStack.axis = .horizontal
        calendarDatesStack.distribution = .equalSpacing
        calendarDatesStack.alignment = .top

        let calendarStack = UIStackView(arrangedSubviews: [calendarDotsStack, calendarDatesStack])
        calendarStack.axis = .vertical
        calendarStack.spacing = 8

        card.contentView.addSubview(calendarStack)
        calendarStack.snp.makeConstraints { $0.edges.equalToSuperview().inset(20) }

        contentStack.addArrangedSubview(card)
    }

    // MARK: - D) Statistics

    private func setupStatistics() {
        let sectionTitle = makeSectionTitle("СТАТИСТИКА")
        contentStack.addArrangedSubview(sectionTitle)

        let card = makeCard()

        statsStack.axis = .vertical
        statsStack.spacing = 0

        card.contentView.addSubview(statsStack)
        statsStack.snp.makeConstraints { $0.edges.equalToSuperview() }

        contentStack.addArrangedSubview(card)
    }

    // MARK: - E) AI Diagnostics

    private func setupAIDiagnostics() {
        let sectionTitle = makeSectionTitle("ИИ ДИАГНОСТИКА")
        contentStack.addArrangedSubview(sectionTitle)

        let card = makeCard()

        diagnoseButton.setTitle("Составить диагностику", for: .normal)
        diagnoseButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        diagnoseButton.setTitleColor(.systemBackground, for: .normal)
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

        aiCard.backgroundColor = .tertiarySystemBackground
        aiCard.layer.cornerRadius = 14
        aiCard.layer.cornerCurve = .continuous
        aiCard.clipsToBounds = true
        aiCard.isHidden = true

        aiCard.contentView.addSubview(aiResultLabel)
        aiResultLabel.snp.makeConstraints { $0.edges.equalToSuperview().inset(16) }

        let cardStack = UIStackView(arrangedSubviews: [diagnoseButton, aiLoadingIndicator, aiCard])
        cardStack.axis = .vertical
        cardStack.spacing = 16
        cardStack.alignment = .fill

        card.contentView.addSubview(cardStack)
        cardStack.snp.makeConstraints { $0.edges.equalToSuperview().inset(20) }

        contentStack.addArrangedSubview(card)
    }

    // MARK: - F) History

    private func setupHistory() {
        let sectionTitle = makeSectionTitle("ИСТОРИЯ")
        contentStack.addArrangedSubview(sectionTitle)

        let card = makeCard()

        historyStack.axis = .vertical
        historyStack.spacing = 0

        card.contentView.addSubview(historyStack)
        historyStack.snp.makeConstraints { $0.edges.equalToSuperview() }

        contentStack.addArrangedSubview(card)
    }

    // MARK: - Refresh

    @objc private func refreshAll() {
        let settings = DataManager.shared.settings
        let tasks = DataManager.shared.fetchTasks()
        let habits = DataManager.shared.fetchHabits()

        refreshStreakOverview(settings: settings, habits: habits)
        refreshTodayProgress(tasks: tasks, habits: habits)
        refreshActivityCalendar(settings: settings)
        refreshStatistics(settings: settings, tasks: tasks, habits: habits)
        refreshHistory(settings: settings, tasks: tasks)
    }

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
    }

    // MARK: - A) Refresh Streak Overview

    private func refreshStreakOverview(settings: AppSettings, habits: [Habit]) {
        let currentStreak = settings.streakDays
        streakNumberLabel.text = "\(currentStreak)"

        // Best streak
        let habitBest = habits.map(\.bestStreak).max() ?? 0
        let overallBest = max(habitBest, currentStreak)
        bestStreakValueLabel.text = "\(overallBest) дн."

        // Status
        if settings.streakPaused {
            statusValueLabel.text = "⏸ На паузе"
            statusValueLabel.textColor = .systemOrange
        } else if currentStreak > 0 {
            statusValueLabel.text = "🔥 Активна"
            statusValueLabel.textColor = .systemGreen
        } else {
            statusValueLabel.text = "💤 Сброшена"
            statusValueLabel.textColor = .systemRed
        }

        // Start date
        let startLabel: String
        if !settings.lastCompletedDayKey.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "ru_RU")
            if let date = formatter.date(from: settings.lastCompletedDayKey) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "d MMMM yyyy"
                displayFormatter.locale = Locale(identifier: "ru_RU")
                startLabel = displayFormatter.string(from: date)
            } else {
                startLabel = settings.lastCompletedDayKey
            }
        } else {
            startLabel = "—"
        }
        startDateValueLabel.text = startLabel

        // Next milestone
        let milestones = [7, 14, 30, 60, 90, 180, 365]
        let nextMilestone = milestones.first { $0 > currentStreak } ?? 365
        let daysUntil = nextMilestone - currentStreak
        milestoneValueLabel.text = "\(daysUntil) дн. до \(nextMilestone)"
    }

    // MARK: - B) Refresh Today's Progress

    private func refreshTodayProgress(tasks: [DailyTask], habits: [Habit]) {
        let done = tasks.filter(\.isCompleted).count
        let total = tasks.count
        let percent = total > 0 ? Int(Double(done) / Double(total) * 100) : 0

        progressRingView.setProgress(CGFloat(percent) / 100.0, animated: true)
        progressPercentLabel.text = "\(percent)%"

        // Tasks list
        tasksStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for task in tasks {
            let row = makeTaskRow(title: task.displayDetail, subtitle: task.title, isCompleted: task.isCompleted)
            tasksStack.addArrangedSubview(row)
        }
        if tasks.isEmpty {
            let empty = makeEmptyLabel("Нет заданий")
            tasksStack.addArrangedSubview(empty)
        }

        // Habits list
        habitsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for habit in habits {
            let row = makeHabitRow(title: habit.title, cleanDays: habit.cleanDays, iconName: habit.iconName)
            habitsStack.addArrangedSubview(row)
        }
        if habits.isEmpty {
            let empty = makeEmptyLabel("Нет привычек")
            habitsStack.addArrangedSubview(empty)
        }
    }

    // MARK: - C) Refresh Activity Calendar

    private func refreshActivityCalendar(settings: AppSettings) {
        calendarDotsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        calendarDatesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for offset in (0..<14).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayKey = DataManager.shared.dayKey(for: date)

            let dotView = UIView()
            dotView.layer.cornerRadius = 8
            dotView.snp.makeConstraints { $0.size.equalTo(16) }

            let isFuture = offset == 0 && !calendar.isDateInToday(date)
            if isFuture {
                dotView.backgroundColor = .systemGray4
            } else if settings.lastCompletedDayKey == dayKey {
                dotView.backgroundColor = .systemGreen
            } else {
                // Check if it was a valid past day where the user should have completed
                let yesterdayKey = DataManager.shared.dayKey(for: calendar.date(byAdding: .day, value: -1, to: date) ?? date)
                if offset > 0 && settings.lastCompletedDayKey != dayKey && settings.lastDayKey != dayKey {
                    dotView.backgroundColor = .systemRed.withAlphaComponent(0.7)
                } else {
                    dotView.backgroundColor = .systemGray4
                }
            }

            calendarDotsStack.addArrangedSubview(dotView)

            let dateLabel = UILabel()
            dateLabel.font = UIFont.systemFont(ofSize: 9, weight: .medium)
            dateLabel.textColor = .tertiaryLabel
            dateLabel.textAlignment = .center
            let dayNum = calendar.component(.day, from: date)
            dateLabel.text = "\(dayNum)"
            dateLabel.snp.makeConstraints { $0.width.equalTo(16) }

            calendarDatesStack.addArrangedSubview(dateLabel)
        }
    }

    // MARK: - D) Refresh Statistics

    private func refreshStatistics(settings: AppSettings, tasks: [DailyTask], habits: [Habit]) {
        statsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let totalTasks = settings.totalCompletedTasks
        let totalHabits = habits.count
        let mostFrequent = settings.mostFrequentExercise
        let avgPerDay: String
        if settings.streakDays > 0 {
            avgPerDay = String(format: "%.1f", Double(totalTasks) / Double(max(1, settings.streakDays)))
        } else {
            avgPerDay = "—"
        }

        let done = tasks.filter(\.isCompleted).count
        let total = tasks.count
        let completionRate = total > 0 ? Int(Double(done) / Double(total) * 100) : 0

        let longestHabitStreak = habits.map(\.bestStreak).max() ?? 0

        let rows: [(String, String)] = [
            ("Всего выполнено заданий", "\(totalTasks)"),
            ("Привычек отслеживается", "\(totalHabits)"),
            ("Самое частое упражнение", mostFrequent),
            ("Среднее заданий в день", avgPerDay),
            ("Процент выполнения", "\(completionRate)%"),
            ("Самая длинная серия привычки", "\(longestHabitStreak) дн."),
        ]

        for (index, row) in rows.enumerated() {
            let valueLabel = UILabel()
            valueLabel.text = row.1
            valueLabel.font = UIFont.preferredFont(forTextStyle: .body).withWeight(.semibold)
            valueLabel.textColor = .label
            let rowView = makeDetailRow(title: row.0, valueLabel: valueLabel, isLast: index == rows.count - 1)
            statsStack.addArrangedSubview(rowView)
        }
    }

    // MARK: - F) Refresh History

    private func refreshHistory(settings: AppSettings, tasks: [DailyTask]) {
        historyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "ru_RU")
        dayFormatter.dateFormat = "EEEE"

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateFormat = "d MMM"

        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayKey = DataManager.shared.dayKey(for: date)
            let wasCompleted = settings.lastCompletedDayKey == dayKey

            let dayName = offset == 0 ? "Сегодня" : offset == 1 ? "Вчера" : dateFormatter.string(from: date)
            let weekday = dayFormatter.string(from: date).capitalized

            let statusIcon = wasCompleted ? "✅" : "⬜"
            let statusText = wasCompleted ? "День закрыт" : "Не закрыт"

            // Build task summary for that day (simplified: show current tasks for today, generic for past)
            let summary: String
            if offset == 0 {
                let done = tasks.filter(\.isCompleted).count
                let total = tasks.count
                summary = "Заданий: \(done)/\(total)"
            } else {
                summary = wasCompleted ? "Все задания выполнены" : "День не завершён"
            }

            let rowView = makeHistoryRow(
                dayName: dayName,
                weekday: weekday,
                statusIcon: statusIcon,
                statusText: statusText,
                summary: summary,
                isLast: offset == 6
            )
            historyStack.addArrangedSubview(rowView)
        }

        if historyStack.arrangedSubviews.isEmpty {
            let empty = makeEmptyLabel("Нет данных")
            historyStack.addArrangedSubview(empty)
        }
    }

    // MARK: - E) AI Diagnostics Action

    @objc private func runDiagnostics() {
        UIImpactFeedbackGenerator.tap(.medium)

        guard !KeychainHelper.groqAPIKey.isEmpty else {
            SPIndicator.present(
                title: "Нет API ключа",
                message: "Добавьте Groq API ключ в настройках",
                preset: .error,
                haptic: .error
            )
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
                let turns = [
                    GroqTurn(role: "user", content: prompt)
                ]
                let result = try await GroqAI.send(history: turns)

                aiLoadingIndicator.stopAnimating()
                diagnoseButton.isEnabled = true
                diagnoseButton.alpha = 1.0

                aiResultLabel.text = result.message.isEmpty ? "Не удалось получить диагностику" : result.message
                aiResultLabel.isHidden = false
                aiCard.isHidden = false

                UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut) {
                    self.aiCard.alpha = 1.0
                }

                UINotificationFeedbackGenerator.notify(.success)
            } catch {
                aiLoadingIndicator.stopAnimating()
                diagnoseButton.isEnabled = true
                diagnoseButton.alpha = 1.0

                aiResultLabel.text = "Ошибка: \(error.localizedDescription)"
                aiResultLabel.isHidden = false
                aiCard.isHidden = false

                SPIndicator.present(
                    title: "Ошибка",
                    message: error.localizedDescription,
                    preset: .error,
                    haptic: .error
                )
            }
        }
    }

    private func buildDiagnosticsPrompt(settings: AppSettings, tasks: [DailyTask], habits: [Habit]) -> String {
        let done = tasks.filter(\.isCompleted).count
        let total = tasks.count
        let completionRate = total > 0 ? Int(Double(done) / Double(total) * 100) : 0

        var taskList = tasks.map { t in
            "- \(t.title) (\(t.displayDetail)): \(t.isCompleted ? "✅" : "⬜"), всего выполнено \(t.totalCompletions) раз"
        }.joined(separator: "\n")

        if taskList.isEmpty { taskList = "Нет заданий" }

        var habitList = habits.map { h in
            "- \(h.title): \(h.cleanDays) дн. чисто, лучший результат \(h.bestStreak) дн., срывов \(h.relapseCount)"
        }.joined(separator: "\n")

        if habitList.isEmpty { habitList = "Нет привычек" }

        return """
        Проанализируй мои данные в Steel и составь диагностику серии. \
        Будь конкретным, давай рекомендации по улучшению. \
        Отметь паттерны, сильные и слабые стороны. \
        Ответ должен быть полезным, на русском языке, до 5 абзацев.

        Данные:
        - Текущая серия: \(settings.streakDays) дней
        - Серия на паузе: \(settings.streakPaused ? "да" : "нет")
        - Всего выполнено заданий за всё время: \(settings.totalCompletedTasks)
        - Самое частое упражнение: \(settings.mostFrequentExercise)
        - Процент выполнения сегодня: \(completionRate)%
        - Последний закрытый день: \(settings.lastCompletedDayKey)

        Задания на сегодня:
        \(taskList)

        Привычки:
        \(habitList)

        Дай диагностику: насколько стабильна серия, что мешает, что улучшить, какие паттерны заметны.
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

    private func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.preferredFont(forTextStyle: .footnote).withWeight(.semibold)
        label.textColor = .secondaryLabel
        return label
    }

    private func makeSeparator() -> UIView {
        let line = UIView()
        line.backgroundColor = .separator
        line.snp.makeConstraints { $0.height.equalTo(0.5) }
        return line
    }

    private func makeDetailRow(title: String, valueLabel: UILabel, isLast: Bool) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        titleLabel.textColor = .secondaryLabel

        let row = UIStackView(arrangedSubviews: [titleLabel, UIView(), valueLabel])
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = .init(top: 14, left: 16, bottom: 14, right: 16)

        let container = UIStackView(arrangedSubviews: [row])
        container.axis = .vertical
        if !isLast { container.addArrangedSubview(makeSeparator()) }
        return container
    }

    private func makeTaskRow(title: String, subtitle: String, isCompleted: Bool) -> UIView {
        let icon = UILabel()
        icon.text = isCompleted ? "✅" : "⭕"
        icon.font = UIFont.systemFont(ofSize: 18)

        let titleLabel = UILabel()
        titleLabel.text = subtitle
        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(.semibold)
        titleLabel.textColor = .label

        let detailLabel = UILabel()
        detailLabel.text = title
        detailLabel.font = UIFont.preferredFont(forTextStyle: .caption2)
        detailLabel.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 1

        let row = UIStackView(arrangedSubviews: [icon, textStack])
        row.spacing = 10
        row.alignment = .center

        return row
    }

    private func makeHabitRow(title: String, cleanDays: Int, iconName: String) -> UIView {
        let icon = UIImageView()
        icon.image = UIImage(systemName: iconName.isEmpty ? "flame.fill" : iconName)
        icon.tintColor = .systemOrange
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18)
        icon.snp.makeConstraints { $0.size.equalTo(22) }

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(.semibold)
        titleLabel.textColor = .label

        let daysLabel = UILabel()
        daysLabel.text = "\(cleanDays) дн."
        daysLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        daysLabel.textColor = cleanDays >= 30 ? .systemGreen : cleanDays >= 7 ? .systemOrange : .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [titleLabel, daysLabel])
        textStack.axis = .vertical
        textStack.spacing = 1

        let row = UIStackView(arrangedSubviews: [icon, textStack])
        row.spacing = 10
        row.alignment = .center

        return row
    }

    private func makeHistoryRow(dayName: String, weekday: String, statusIcon: String,
                                statusText: String, summary: String, isLast: Bool) -> UIView {
        let iconLabel = UILabel()
        iconLabel.text = statusIcon
        iconLabel.font = UIFont.systemFont(ofSize: 20)

        let dayLabel = UILabel()
        dayLabel.text = dayName
        dayLabel.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(.semibold)
        dayLabel.textColor = .label

        let weekdayLabel = UILabel()
        weekdayLabel.text = weekday
        weekdayLabel.font = UIFont.preferredFont(forTextStyle: .caption2)
        weekdayLabel.textColor = .secondaryLabel

        let nameStack = UIStackView(arrangedSubviews: [dayLabel, weekdayLabel])
        nameStack.axis = .vertical
        nameStack.spacing = 1

        let statusLabel = UILabel()
        statusLabel.text = statusText
        statusLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        statusLabel.textColor = statusIcon == "✅" ? .systemGreen : .secondaryLabel

        let summaryLabel = UILabel()
        summaryLabel.text = summary
        summaryLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        summaryLabel.textColor = .tertiaryLabel

        let rightStack = UIStackView(arrangedSubviews: [statusLabel, summaryLabel])
        rightStack.axis = .vertical
        rightStack.spacing = 1
        rightStack.alignment = .trailing

        let row = UIStackView(arrangedSubviews: [iconLabel, nameStack, UIView(), rightStack])
        row.alignment = .center
        row.spacing = 10
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = .init(top: 12, left: 16, bottom: 12, right: 16)

        let container = UIStackView(arrangedSubviews: [row])
        container.axis = .vertical
        if !isLast { container.addArrangedSubview(makeSeparator()) }
        return container
    }

    private func makeEmptyLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        return label
    }
}

// MARK: - Progress Ring View

private final class ProgressRingView: UIView {

    private var progress: CGFloat = 0
    private let lineWidth: CGFloat = 10

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    private func setupLayers() {
        backgroundColor = .clear

        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor.systemGray5.cgColor
        trackLayer.lineWidth = lineWidth
        trackLayer.lineCap = .round
        trackLayer.strokeStart = 0
        trackLayer.strokeEnd = 1

        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.systemGreen.cgColor
        progressLayer.lineWidth = lineWidth
        progressLayer.lineCap = .round
        progressLayer.strokeStart = 0
        progressLayer.strokeEnd = 0

        layer.addSublayer(trackLayer)
        layer.addSublayer(progressLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = (min(bounds.width, bounds.height) - lineWidth) / 2
        let path = UIBezierPath(
            arcCenter: center,
            radius: max(1, radius),
            startAngle: -.pi / 2,
            endAngle: 3 * .pi / 2,
            clockwise: true
        )
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }

    func setProgress(_ value: CGFloat, animated: Bool) {
        progress = min(1, max(0, value))

        // Color based on progress
        if progress >= 0.8 {
            progressLayer.strokeColor = UIColor.systemGreen.cgColor
        } else if progress >= 0.5 {
            progressLayer.strokeColor = UIColor.systemOrange.cgColor
        } else {
            progressLayer.strokeColor = UIColor.systemRed.cgColor
        }

        if animated {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = progressLayer.strokeEnd
            animation.toValue = progress
            animation.duration = 0.6
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            progressLayer.add(animation, forKey: "progressAnimation")
        }

        progressLayer.strokeEnd = progress
    }
}


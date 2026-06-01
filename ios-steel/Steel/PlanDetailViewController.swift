import UIKit
import SnapKit
import SPIndicator
import Hero

/// Подробный просмотр плана тренировок. Открывается модалкой поверх `PlanViewController`,
/// показывает структурированные секции: шапку программы, недели с днями, питание,
/// режим дня и восстановление. Каждая карточка — в стиле «жидкого стекла».
final class PlanDetailViewController: UIViewController {
    private let plan: TrainingPlan
    private let parsed: ParsedPlan
    private let scrollView = UIScrollView()
    private let content = UIView()
    private let backgroundView = PersonalBackgroundView()

    init(plan: TrainingPlan) {
        self.plan = plan
        self.parsed = PlanParser.parse(plan.body)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .formSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large(), .medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 32
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Подробный план"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(close)
        )
        setupBackground()
        setupScroll()
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        backgroundView.apply(BackgroundManager.shared.config)
        backgroundView.resumeVideo()
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

    private func setupScroll() {
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        scrollView.alwaysBounceVertical = true
        scrollView.addSubview(content)
        content.snp.makeConstraints {
            $0.top.equalToSuperview().offset(8)
            $0.leading.trailing.equalTo(view).inset(20)
            $0.bottom.equalToSuperview().inset(40)
            $0.width.equalTo(view).offset(-40)
        }
    }

    @objc private func close() { dismiss(animated: true) }

    // MARK: - Рендер

    private func render() {
        // Очистка контейнера
        content.subviews.forEach { $0.removeFromSuperview() }

        var lastBottom: UIView = content

        // Шапка: программа + цель + длительность + уровень
        let header = makeProgramHeader()
        content.addSubview(header)
        header.snp.makeConstraints { $0.top.leading.trailing.equalToSuperview() }
        lastBottom = header

        // Цитата / описание
        if !parsed.program.goal.isEmpty {
            let goal = makeInfoCard(
                title: "ЦЕЛЬ",
                icon: "target",
                body: parsed.program.goal
            )
            content.addSubview(goal)
            goal.snp.makeConstraints {
                $0.top.equalTo(lastBottom.snp.bottom).offset(14)
                $0.leading.trailing.equalToSuperview()
            }
            lastBottom = goal
        }

        // Недели
        for (i, week) in parsed.weeks.enumerated() {
            let weekView = makeWeekCard(week)
            content.addSubview(weekView)
            weekView.snp.makeConstraints {
                $0.top.equalTo(lastBottom.snp.bottom).offset(14)
                $0.leading.trailing.equalToSuperview()
            }
            lastBottom = weekView
            _ = i
        }

        // Питание
        if !parsed.meals.isEmpty {
            let meals = makeMealsCard()
            content.addSubview(meals)
            meals.snp.makeConstraints {
                $0.top.equalTo(lastBottom.snp.bottom).offset(14)
                $0.leading.trailing.equalToSuperview()
            }
            lastBottom = meals
        }

        // Режим дня
        if !parsed.schedule.isEmpty {
            let schedule = makeTipsCard(
                title: "РЕЖИМ ДНЯ",
                icon: "clock.fill",
                tips: parsed.schedule
            )
            content.addSubview(schedule)
            schedule.snp.makeConstraints {
                $0.top.equalTo(lastBottom.snp.bottom).offset(14)
                $0.leading.trailing.equalToSuperview()
            }
            lastBottom = schedule
        }

        // Восстановление
        if !parsed.recovery.isEmpty {
            let recovery = makeTipsCard(
                title: "ВОССТАНОВЛЕНИЕ",
                icon: "leaf.fill",
                tips: parsed.recovery
            )
            content.addSubview(recovery)
            recovery.snp.makeConstraints {
                $0.top.equalTo(lastBottom.snp.bottom).offset(14)
                $0.leading.trailing.equalToSuperview()
                $0.bottom.equalToSuperview()
            }
        } else {
            lastBottom.snp.makeConstraints { $0.bottom.equalToSuperview() }
        }
    }

    // MARK: - Карточки

    private func makeProgramHeader() -> UIView {
        let card = LiquidGlassView(cornerRadius: 24, intensity: .regular)
        card.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.45)

        let icon = UIImageView(image: UIImage(systemName: "flame.fill"))
        icon.tintColor = .systemOrange
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)

        let title = UILabel()
        title.text = parsed.program.title.isEmpty ? plan.title : parsed.program.title
        title.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        title.textColor = .label
        title.numberOfLines = 0

        let meta = UILabel()
        let parts: [String] = [
            parsed.program.duration.isEmpty ? nil : "⏱ \(parsed.program.duration)",
            parsed.program.level.isEmpty ? nil : "🏋️ \(parsed.program.level)",
            "📅 Обновлено: \(dateString(plan.updatedAt))"
        ].compactMap { $0 }
        meta.text = parts.joined(separator: "   •   ")
        meta.font = UIFont.preferredFont(forTextStyle: .subheadline)
        meta.textColor = .secondaryLabel
        meta.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [title, meta])
        textStack.axis = .vertical
        textStack.spacing = 6

        let h = UIStackView(arrangedSubviews: [icon, textStack])
        h.axis = .horizontal
        h.alignment = .top
        h.spacing = 14
        card.contentView.addSubview(h)
        h.snp.makeConstraints { $0.edges.equalToSuperview().inset(18) }
        icon.snp.makeConstraints { $0.width.height.equalTo(36) }

        return card
    }

    private func makeInfoCard(title: String, icon: String, body: String) -> UIView {
        let card = LiquidGlassView(cornerRadius: 20, intensity: .thin)
        card.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.35)

        let header = UILabel()
        header.text = title
        header.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        header.textColor = .secondaryLabel

        let bodyLbl = UILabel()
        bodyLbl.text = body
        bodyLbl.font = UIFont.preferredFont(forTextStyle: .body)
        bodyLbl.textColor = .label
        bodyLbl.numberOfLines = 0

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .systemBlue
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let headerRow = UIStackView(arrangedSubviews: [iconView, header])
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [headerRow, bodyLbl])
        stack.axis = .vertical
        stack.spacing = 8

        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(18) }

        return card
    }

    private func makeWeekCard(_ week: ParsedPlan.Week) -> UIView {
        let card = LiquidGlassView(cornerRadius: 20, intensity: .regular)
        card.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.4)

        let title = UILabel()
        title.text = "НЕДЕЛЯ \(week.index)"
        title.font = UIFont.systemFont(ofSize: 18, weight: .heavy)
        title.textColor = .label

        let dayStack = UIStackView()
        dayStack.axis = .vertical
        dayStack.spacing = 8

        for day in week.days {
            dayStack.addArrangedSubview(makeDayRow(day))
        }

        let v = UIStackView(arrangedSubviews: [title, dayStack])
        v.axis = .vertical
        v.spacing = 12
        card.contentView.addSubview(v)
        v.snp.makeConstraints { $0.edges.equalToSuperview().inset(18) }

        return card
    }

    private func makeDayRow(_ day: ParsedPlan.Day) -> UIView {
        let row = UIView()
        row.backgroundColor = .clear
        row.layer.cornerRadius = 12
        row.layer.cornerCurve = .continuous
        row.layer.borderWidth = 0.5
        row.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor

        // Иконка
        let icon = UIImageView(image: UIImage(systemName: iconForDay(day)))
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        icon.tintColor = colorForDay(day)

        // День недели
        let weekday = UILabel()
        weekday.text = day.weekday.isEmpty ? "Д\(day.index)" : day.weekday
        weekday.font = UIFont.systemFont(ofSize: 11, weight: .heavy)
        weekday.textColor = .secondaryLabel
        weekday.textAlignment = .center

        let dayIndex = UILabel()
        dayIndex.text = "День \(day.index)"
        dayIndex.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        dayIndex.textColor = .label

        let typeLabel = UILabel()
        typeLabel.text = day.type.isEmpty ? "Тренировка" : day.type
        typeLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        typeLabel.textColor = colorForDay(day)

        let bodyLabel = UILabel()
        bodyLabel.text = day.body
        bodyLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        bodyLabel.textColor = .label
        bodyLabel.numberOfLines = 0

        let leftStack = UIStackView(arrangedSubviews: [weekday, dayIndex])
        leftStack.axis = .vertical
        leftStack.alignment = .center
        leftStack.spacing = 2
        leftStack.snp.makeConstraints { $0.width.equalTo(54) }

        let rightStack = UIStackView(arrangedSubviews: [typeLabel, bodyLabel])
        rightStack.axis = .vertical
        rightStack.spacing = 4

        let h = UIStackView(arrangedSubviews: [leftStack, icon, rightStack])
        h.axis = .horizontal
        h.alignment = .center
        h.spacing = 10
        row.addSubview(h)
        h.snp.makeConstraints { $0.edges.equalToSuperview().inset(12) }
        icon.snp.makeConstraints { $0.width.height.equalTo(22) }
        row.snp.makeConstraints { $0.height.greaterThanOrEqualTo(56) }

        return row
    }

    private func makeMealsCard() -> UIView {
        let card = LiquidGlassView(cornerRadius: 20, intensity: .regular)
        card.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.4)

        let title = UILabel()
        title.text = "ПИТАНИЕ"
        title.font = UIFont.systemFont(ofSize: 18, weight: .heavy)
        title.textColor = .label

        let hint = UILabel()
        hint.text = "Что есть и в какое время"
        hint.font = UIFont.preferredFont(forTextStyle: .footnote)
        hint.textColor = .secondaryLabel

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8

        for meal in parsed.meals {
            stack.addArrangedSubview(makeMealRow(meal))
        }

        let v = UIStackView(arrangedSubviews: [title, hint, stack])
        v.axis = .vertical
        v.spacing = 12
        card.contentView.addSubview(v)
        v.snp.makeConstraints { $0.edges.equalToSuperview().inset(18) }

        return card
    }

    private func makeMealRow(_ meal: ParsedPlan.Meal) -> UIView {
        let row = UIView()
        row.backgroundColor = .clear
        row.layer.cornerRadius = 12
        row.layer.cornerCurve = .continuous
        row.layer.borderWidth = 0.5
        row.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor

        let icon = UIImageView(image: UIImage(systemName: "fork.knife"))
        icon.tintColor = .systemGreen
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)

        let name = UILabel()
        name.text = meal.name.isEmpty ? "Приём пищи" : meal.name
        name.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        name.textColor = .systemGreen

        let time = UILabel()
        time.text = meal.time
        time.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        time.textColor = .secondaryLabel

        let bodyLbl = UILabel()
        bodyLbl.text = meal.body
        bodyLbl.font = UIFont.preferredFont(forTextStyle: .footnote)
        bodyLbl.textColor = .label
        bodyLbl.numberOfLines = 0

        let topRow = UIStackView(arrangedSubviews: [name, time])
        topRow.axis = .horizontal
        topRow.spacing = 6
        topRow.alignment = .firstBaseline

        let rightStack = UIStackView(arrangedSubviews: [topRow, bodyLbl])
        rightStack.axis = .vertical
        rightStack.spacing = 2

        let h = UIStackView(arrangedSubviews: [icon, rightStack])
        h.axis = .horizontal
        h.alignment = .top
        h.spacing = 10
        row.addSubview(h)
        h.snp.makeConstraints { $0.edges.equalToSuperview().inset(12) }
        icon.snp.makeConstraints { $0.width.height.equalTo(22) }

        return row
    }

    private func makeTipsCard(title: String, icon: String, tips: [ParsedPlan.Tip]) -> UIView {
        let card = LiquidGlassView(cornerRadius: 20, intensity: .regular)
        card.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.4)

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = UIFont.systemFont(ofSize: 18, weight: .heavy)
        titleLbl.textColor = .label

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8

        for tip in tips {
            stack.addArrangedSubview(makeTipRow(tip, icon: icon))
        }

        let v = UIStackView(arrangedSubviews: [titleLbl, stack])
        v.axis = .vertical
        v.spacing = 12
        card.contentView.addSubview(v)
        v.snp.makeConstraints { $0.edges.equalToSuperview().inset(18) }
        return card
    }

    private func makeTipRow(_ tip: ParsedPlan.Tip, icon: String) -> UIView {
        let row = UIView()
        row.backgroundColor = .clear

        let dot = UIView()
        dot.backgroundColor = .systemBlue
        dot.layer.cornerRadius = 3
        row.addSubview(dot)
        dot.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(4)
            $0.top.equalToSuperview().inset(7)
            $0.width.height.equalTo(6)
        }

        let lbl = UILabel()
        let bold = NSMutableAttributedString(
            string: tip.title.isEmpty ? "" : "\(tip.title): ",
            attributes: [.font: UIFont.systemFont(ofSize: 14, weight: .heavy), .foregroundColor: UIColor.label]
        )
        bold.append(NSAttributedString(
            string: tip.body,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .footnote), .foregroundColor: UIColor.label]
        ))
        lbl.attributedText = bold
        lbl.numberOfLines = 0

        row.addSubview(lbl)
        lbl.snp.makeConstraints {
            $0.leading.equalTo(dot.snp.trailing).offset(10)
            $0.trailing.equalToSuperview().inset(4)
            $0.top.bottom.equalToSuperview().inset(2)
        }
        return row
    }

    // MARK: - Вспомогательные

    private func iconForDay(_ day: ParsedPlan.Day) -> String {
        let t = day.type.lowercased()
        if t.contains("отдых") { return "bed.double.fill" }
        if t.contains("силов") { return "dumbbell.fill" }
        if t.contains("кардио") || t.contains("бег") { return "figure.run" }
        if t.contains("hiit") || t.contains("табата") { return "bolt.fill" }
        if t.contains("кругов") { return "arrow.triangle.2.circlepath" }
        if t.contains("растяж") || t.contains("йога") { return "figure.flexibility" }
        if t.contains("пресс") || t.contains("кор") { return "figure.core.training" }
        return "figure.strengthtraining.traditional"
    }

    private func colorForDay(_ day: ParsedPlan.Day) -> UIColor {
        if day.type.lowercased().contains("отдых") { return .systemGray }
        return .systemOrange
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: date)
    }
}

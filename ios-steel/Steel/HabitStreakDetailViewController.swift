import UIKit
import SnapKit

final class HabitStreakDetailViewController: UIViewController {
    private let habit: Habit
    private let backgroundView = PersonalBackgroundView()

    init(habit: Habit) {
        self.habit = habit
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupUI()
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

    private func setupUI() {
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        backgroundView.apply(BackgroundManager.shared.config)

        let handle = UIView()
        handle.backgroundColor = UIColor.separator
        handle.layer.cornerRadius = 2.5
        view.addSubview(handle)
        handle.snp.makeConstraints {
            $0.top.equalToSuperview().offset(10)
            $0.centerX.equalToSuperview()
            $0.width.equalTo(36)
            $0.height.equalTo(5)
        }

        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }

        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 16
        content.alignment = .center
        content.isLayoutMarginsRelativeArrangement = true
        content.layoutMargins = UIEdgeInsets(top: 40, left: 24, bottom: 48, right: 24)
        scrollView.addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalToSuperview()
        }

        buildIconSection(in: content)
        buildMainCard(in: content)
        if habit.bestStreak > 0 || habit.relapseCount > 0 {
            buildStatsCard(in: content)
        }
        buildMotivationLabel(in: content)
    }

    private func buildIconSection(in stack: UIStackView) {
        let tint: UIColor = habit.category == .good ? .systemGreen : .systemRed

        let iconContainer = UIView()
        iconContainer.backgroundColor = tint
        iconContainer.layer.cornerRadius = 40
        iconContainer.layer.cornerCurve = .continuous
        iconContainer.layer.shadowColor = tint.cgColor
        iconContainer.layer.shadowRadius = 16
        iconContainer.layer.shadowOpacity = 0.35
        iconContainer.layer.shadowOffset = CGSize(width: 0, height: 6)
        stack.addArrangedSubview(iconContainer)
        iconContainer.snp.makeConstraints { $0.width.height.equalTo(80) }

        let iconView = UIImageView()
        iconView.image = UIImage(systemName: habit.iconName,
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 36, weight: .semibold))
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconContainer.addSubview(iconView)
        iconView.snp.makeConstraints { $0.center.equalToSuperview() }

        stack.setCustomSpacing(12, after: iconContainer)

        let titleLabel = UILabel()
        titleLabel.text = habit.title
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        stack.addArrangedSubview(titleLabel)

        let badge = UILabel()
        badge.text = "  \(habit.category.title.uppercased())  "
        badge.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        badge.textColor = .white
        badge.backgroundColor = tint
        badge.layer.cornerRadius = 8
        badge.layer.cornerCurve = .continuous
        badge.clipsToBounds = true
        stack.addArrangedSubview(badge)

        stack.setCustomSpacing(20, after: badge)
    }

    private func buildMainCard(in stack: UIStackView) {
        let card = makeCard()
        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 4
        cardStack.alignment = .center
        cardStack.isLayoutMarginsRelativeArrangement = true
        cardStack.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 28, right: 24)
        card.contentView.addSubview(cardStack)
        cardStack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let sinceCaption = UILabel()
        sinceCaption.text = "Начало серии"
        sinceCaption.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        sinceCaption.textColor = .secondaryLabel
        cardStack.addArrangedSubview(sinceCaption)

        let dateLabel = UILabel()
        dateLabel.text = formattedDate(habit.streakStart)
        dateLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        dateLabel.textColor = .label
        cardStack.addArrangedSubview(dateLabel)

        cardStack.setCustomSpacing(20, after: dateLabel)

        let tint: UIColor = habit.category == .good ? .systemGreen : .systemRed

        let daysNumber = UILabel()
        daysNumber.text = "\(habit.cleanDays)"
        daysNumber.font = UIFont.systemFont(ofSize: 80, weight: .heavy)
        daysNumber.textColor = tint
        daysNumber.textAlignment = .center
        cardStack.addArrangedSubview(daysNumber)

        let daysWord = UILabel()
        let days = habit.cleanDays
        var caption = habit.category == .good ? "\(russianDays(days)) подряд" : "\(russianDays(days)) чисто"
        if habit.category == .good && habit.isMarkedToday {
            caption += " (сегодня ✓)"
        }
        daysWord.text = caption
        daysWord.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        daysWord.textColor = habit.category == .good && habit.isMarkedToday ? .systemGreen : .secondaryLabel
        daysWord.textAlignment = .center
        cardStack.addArrangedSubview(daysWord)

        // Show last marked date for good habits
        if habit.category == .good, let lastMarked = habit.lastMarkedDate {
            let lastLabel = UILabel()
            lastLabel.text = "Последнее: \(formattedDate(lastMarked))"
            lastLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
            lastLabel.textColor = .tertiaryLabel
            lastLabel.textAlignment = .center
            cardStack.addArrangedSubview(lastLabel)
        }

        stack.addArrangedSubview(card)
        card.snp.makeConstraints { $0.leading.trailing.equalToSuperview() }
    }

    private func buildStatsCard(in stack: UIStackView) {
        let card = makeCard()
        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 0
        card.contentView.addSubview(cardStack)
        cardStack.snp.makeConstraints { $0.edges.equalToSuperview() }

        if habit.bestStreak > 0 {
            let row = makeStatRow(
                icon: "trophy.fill",
                iconColor: .systemYellow,
                title: "Рекорд",
                value: "\(habit.bestStreak) дн."
            )
            cardStack.addArrangedSubview(row)
        }

        if habit.bestStreak > 0 && habit.relapseCount > 0 {
            let sep = makeSeparator()
            cardStack.addArrangedSubview(sep)
        }

        if habit.relapseCount > 0 {
            let row = makeStatRow(
                icon: "arrow.counterclockwise",
                iconColor: .systemOrange,
                title: "Срывов",
                value: "\(habit.relapseCount)"
            )
            cardStack.addArrangedSubview(row)
        }

        stack.addArrangedSubview(card)
        card.snp.makeConstraints { $0.leading.trailing.equalToSuperview() }
    }

    private func buildMotivationLabel(in stack: UIStackView) {
        let days = habit.cleanDays
        let text: String
        let tint: UIColor = habit.category == .good ? .systemGreen : .systemRed

        if days == 0 {
            text = habit.category == .good ? "Начни сегодня — первый день самый важный!" : "Отказ начинается сейчас. Ты справишься!"
        } else if days < 7 {
            text = "Хорошее начало! Первая неделя — самая тяжёлая."
        } else if days < 30 {
            text = "Отличный прогресс! Привычка формируется."
        } else if days < 90 {
            text = "Месяц — это сила! Продолжай в том же духе."
        } else {
            text = "Невероятно! Ты — пример настоящей дисциплины."
        }

        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = tint
        label.textAlignment = .center
        label.numberOfLines = 0
        stack.addArrangedSubview(label)
    }

    private func makeStatRow(icon: String, iconColor: UIColor, title: String, value: String) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: icon,
                                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)))
        iconView.tintColor = iconColor
        iconView.contentMode = .center
        iconView.snp.makeConstraints { $0.width.equalTo(24) }

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        titleLabel.textColor = .label

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        valueLabel.textColor = .secondaryLabel
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [iconView, titleLabel, UIView(), valueLabel])
        row.alignment = .center
        row.spacing = 12
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        return row
    }

    private func makeSeparator() -> UIView {
        let sep = UIView()
        sep.backgroundColor = .separator
        sep.snp.makeConstraints { $0.height.equalTo(0.5) }
        return sep
    }

    private func makeCard() -> UIVisualEffectView {
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        card.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.5)
        card.layer.cornerRadius = 22
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        return card
    }

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMMM yyyy"
        fmt.locale = Locale(identifier: "ru_RU")
        return fmt.string(from: date)
    }

    private func russianDays(_ n: Int) -> String {
        let last2 = n % 100
        let last1 = n % 10
        if last2 >= 11 && last2 <= 19 { return "\(n) дней" }
        if last1 == 1 { return "\(n) день" }
        if last1 >= 2 && last1 <= 4 { return "\(n) дня" }
        return "\(n) дней"
    }
}

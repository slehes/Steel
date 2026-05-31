import UIKit
import SnapKit
import SPIndicator

final class SettingsViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private static let russianRegions: [(String, String)] = [
        ("Москва", "Europe/Moscow"),
        ("Санкт-Петербург", "Europe/Moscow"),
        ("Калининград", "Europe/Kaliningrad"),
        ("Самара", "Europe/Samara"),
        ("Казань", "Europe/Moscow"),
        ("Екатеринбург", "Asia/Yekaterinburg"),
        ("Омск", "Asia/Omsk"),
        ("Новосибирск", "Asia/Novosibirsk"),
        ("Красноярск", "Asia/Krasnoyarsk"),
        ("Иркутск", "Asia/Irkutsk"),
        ("Якутск", "Asia/Yakutsk"),
        ("Владивосток", "Asia/Vladivostok"),
        ("Магадан", "Asia/Magadan"),
        ("Камчатка", "Asia/Kamchatka"),
        ("Чита", "Asia/Chita"),
        ("Хабаровск", "Asia/Vladivostok"),
        ("Тюмень", "Asia/Yekaterinburg"),
        ("Уфа", "Asia/Yekaterinburg"),
        ("Краснодар", "Europe/Moscow"),
        ("Ростов-на-Дону", "Europe/Moscow"),
        ("Волгоград", "Europe/Moscow"),
        ("Нижний Новгород", "Europe/Moscow"),
        ("Воронеж", "Europe/Moscow"),
        ("Пермь", "Asia/Yekaterinberg"),
        ("Томск", "Asia/Novosibirsk"),
        ("Барнаул", "Asia/Barnaul"),
        ("Мурманск", "Europe/Moscow"),
        ("Архангельск", "Europe/Moscow"),
        ("Петропавловск-Камчатский", "Asia/Kamchatka"),
        ("Южно-Сахалинск", "Asia/Sakhalin"),
        ("Анадырь", "Asia/Anadyr"),
        ("Норильск", "Asia/Krasnoyarsk"),
    ]

    private var customReminderHoursField: UITextField?
    private var customReminderMinutesField: UITextField?
    private var customReminderSecondsField: UITextField?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Настройки"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))

        setup()
    }

    private func setup() {
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        scrollView.alwaysBounceVertical = true

        contentStack.axis = .vertical
        contentStack.spacing = 24
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.leading.trailing.equalTo(view).inset(20)
            $0.bottom.equalToSuperview().inset(40)
        }

        setupCategoriesSection()
    }

    private func setupCategoriesSection() {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let appearance = makeCategoryRow(title: "Оформление", subtitle: "Фон, шрифт", icon: "paintpalette.fill") { [weak self] in
            self?.openAppearance()
        }
        let providers = makeCategoryRow(title: "Провайдеры", subtitle: "Groq, Gemini", icon: "server.rack") { [weak self] in
            self?.openProviders()
        }
        let region = makeCategoryRow(title: "Регион", subtitle: currentRegionSubtitle(), icon: "globe") { [weak self] in
            self?.openRegionPicker()
        }
        let streak = makeCategoryRow(title: "Серия", subtitle: "Пауза, защита серии", icon: "flame.shield") { [weak self] in
            self?.openStreakSettings()
        }
        let reminders = makeCategoryRow(title: "Напоминания", subtitle: "Время, таймер", icon: "bell.badge") { [weak self] in
            self?.openReminderSettings()
        }

        stack.addArrangedSubview(appearance)
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(providers)
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(region)
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(streak)
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(reminders)

        contentStack.addArrangedSubview(card)
    }

    private func currentRegionSubtitle() -> String {
        let city = DataManager.shared.settings.regionCity
        return city.isEmpty ? "Москва" : city
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    private func openAppearance() {
        let vc = AppearanceViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func openProviders() {
        let vc = ProvidersViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func openRegionPicker() {
        let alert = UIAlertController(title: "Выберите город", message: nil, preferredStyle: .actionSheet)
        for (city, tz) in Self.russianRegions {
            alert.addAction(UIAlertAction(title: city, style: .default) { _ in
                DataManager.shared.updateSettings {
                    $0.regionCity = city
                    $0.regionTimeZone = tz
                }
                DataManager.shared.setTimeZone(TimeZone(identifier: tz) ?? TimeZone(identifier: "Europe/Moscow")!)
                SPIndicator.present(title: city, preset: .done, haptic: .success)
            })
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(alert, animated: true)
    }

    private func openStreakSettings() {
        let vc = StreakSettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func openReminderSettings() {
        let vc = ReminderSettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func makeCard() -> UIVisualEffectView {
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 18
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        return card
    }

    private func separator() -> UIView {
        let line = UIView()
        line.backgroundColor = .separator
        line.snp.makeConstraints { $0.height.equalTo(0.5) }
        return line
    }

    private func makeCategoryRow(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .white
        iconView.contentMode = .center
        iconView.layer.cornerRadius = 8
        iconView.layer.cornerCurve = .continuous
        iconView.backgroundColor = .darkGray
        iconView.snp.makeConstraints { $0.size.equalTo(32) }

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.preferredFont(forTextStyle: .body).withWeight(.semibold)
        titleLabel.textColor = .label

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.snp.makeConstraints { $0.size.equalTo(14) }

        let row = UIStackView(arrangedSubviews: [iconView, textStack, UIView(), chevron])
        row.alignment = .center
        row.spacing = 12
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = .init(top: 14, left: 16, bottom: 14, right: 16)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleRowTap(_:)))
        row.addGestureRecognizer(tap)
        row.isUserInteractionEnabled = true
        objc_setAssociatedObject(row, "rowAction", action, .OBJC_ASSOCIATION_COPY_NONATOMIC)

        return row
    }

    @objc private func handleRowTap(_ gesture: UITapGestureRecognizer) {
        guard let action = objc_getAssociatedObject(gesture.view, "rowAction") as? () -> Void else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        action()
    }
}

final class StreakSettingsViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Серия"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        setup()
    }

    private func setup() {
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        scrollView.alwaysBounceVertical = true

        contentStack.axis = .vertical
        contentStack.spacing = 24
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.leading.trailing.equalTo(view).inset(20)
            $0.bottom.equalToSuperview().inset(40)
        }

        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let pauseLabel = UILabel()
        pauseLabel.text = "Пауза серии"
        pauseLabel.font = UIFont.preferredFont(forTextStyle: .body)
        pauseLabel.textColor = .label

        let pauseToggle = UISwitch()
        pauseToggle.onTintColor = .systemOrange
        pauseToggle.isOn = DataManager.shared.settings.streakPaused
        pauseToggle.addTarget(self, action: #selector(streakPauseChanged(_:)), for: .valueChanged)

        let pauseRow = UIStackView(arrangedSubviews: [pauseLabel, UIView(), pauseToggle])
        pauseRow.alignment = .center
        pauseRow.isLayoutMarginsRelativeArrangement = true
        pauseRow.layoutMargins = .init(top: 14, left: 16, bottom: 14, right: 16)
        stack.addArrangedSubview(pauseRow)

        let descLabel = UILabel()
        descLabel.text = "Серия не сбросится, если вы не завершили день"
        descLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        descLabel.textColor = .secondaryLabel
        descLabel.numberOfLines = 2
        let descRow = UIStackView(arrangedSubviews: [descLabel])
        descRow.isLayoutMarginsRelativeArrangement = true
        descRow.layoutMargins = .init(top: 0, left: 16, bottom: 12, right: 16)
        stack.addArrangedSubview(descRow)

        contentStack.addArrangedSubview(card)
    }

    @objc private func streakPauseChanged(_ toggle: UISwitch) {
        let today = DataManager.shared.dayKey(for: Date())
        DataManager.shared.updateSettings {
            $0.streakPaused = toggle.isOn
            $0.streakPausedSince = toggle.isOn ? today : ""
        }
        SPIndicator.present(title: toggle.isOn ? "Серия на паузе" : "Серия активна", preset: .done, haptic: .success)
    }

    private func makeCard() -> UIVisualEffectView {
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 18
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        return card
    }
}

final class ReminderSettingsViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var reminderPickers: [UIDatePicker] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Напоминания"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        setup()
    }

    private func setup() {
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        scrollView.alwaysBounceVertical = true

        contentStack.axis = .vertical
        contentStack.spacing = 24
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.leading.trailing.equalTo(view).inset(20)
            $0.bottom.equalToSuperview().inset(40)
        }

        setupScheduleSection()
        setupCustomTimerSection()
    }

    private func setupScheduleSection() {
        let sectionLabel = UILabel()
        sectionLabel.text = "РАСПИСАНИЕ"
        sectionLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        sectionLabel.textColor = .secondaryLabel
        contentStack.addArrangedSubview(sectionLabel)

        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let hours = DataManager.shared.settings.reminderHours
        let labels = ["Утро", "Вечер", "Ночь"]
        for index in 0..<3 {
            let picker = UIDatePicker()
            picker.datePickerMode = .time
            picker.preferredDatePickerStyle = .compact
            picker.minuteInterval = 5
            picker.tag = index
            picker.addTarget(self, action: #selector(reminderChanged(_:)), for: .valueChanged)
            var comps = DateComponents()
            comps.hour = index < hours.count ? hours[index] : [9, 19, 22][index]
            comps.minute = 0
            picker.date = Calendar.current.date(from: comps) ?? Date()
            reminderPickers.append(picker)

            let label = UILabel()
            label.text = index < labels.count ? labels[index] : "Напоминание"
            label.font = UIFont.preferredFont(forTextStyle: .body)
            label.textColor = .label

            let row = UIStackView(arrangedSubviews: [label, UIView(), picker])
            row.alignment = .center
            row.isLayoutMarginsRelativeArrangement = true
            row.layoutMargins = .init(top: 14, left: 16, bottom: 14, right: 16)
            stack.addArrangedSubview(row)
            if index < 2 { stack.addArrangedSubview(makeSeparator()) }
        }
        contentStack.addArrangedSubview(card)

        let descLabel = UILabel()
        descLabel.text = "Текст уведомления: У вас еще не все тренировки выполнены"
        descLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        descLabel.textColor = .secondaryLabel
        descLabel.numberOfLines = 2
        contentStack.addArrangedSubview(descLabel)
    }

    private func setupCustomTimerSection() {
        let sectionLabel = UILabel()
        sectionLabel.text = "ТАЙМЕР"
        sectionLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        sectionLabel.textColor = .secondaryLabel
        contentStack.addArrangedSubview(sectionLabel)

        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let hoursField = makeTimeField(placeholder: "0")
        let minutesField = makeTimeField(placeholder: "0")
        let secondsField = makeTimeField(placeholder: "0")

        let hLabel = UILabel()
        hLabel.text = "ч"
        hLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        hLabel.textColor = .secondaryLabel

        let mLabel = UILabel()
        mLabel.text = "м"
        mLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        mLabel.textColor = .secondaryLabel

        let sLabel = UILabel()
        sLabel.text = "с"
        sLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        sLabel.textColor = .secondaryLabel

        let fieldsRow = UIStackView(arrangedSubviews: [hoursField, hLabel, minutesField, mLabel, secondsField, sLabel])
        fieldsRow.alignment = .center
        fieldsRow.spacing = 6

        let rowLabel = UILabel()
        rowLabel.text = "Через сколько напомнить"
        rowLabel.font = UIFont.preferredFont(forTextStyle: .body)
        rowLabel.textColor = .label

        let topRow = UIStackView(arrangedSubviews: [rowLabel])
        topRow.isLayoutMarginsRelativeArrangement = true
        topRow.layoutMargins = .init(top: 14, left: 16, bottom: 0, right: 16)

        let centerRow = UIStackView(arrangedSubviews: [fieldsRow])
        centerRow.isLayoutMarginsRelativeArrangement = true
        centerRow.layoutMargins = .init(top: 8, left: 16, bottom: 0, right: 16)

        let startButton = UIButton(type: .system)
        startButton.setTitle("Запустить таймер", for: .normal)
        startButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        startButton.setTitleColor(.white, for: .normal)
        startButton.backgroundColor = .systemOrange
        startButton.layer.cornerRadius = 14
        startButton.layer.cornerCurve = .continuous
        startButton.addTarget(self, action: #selector(startCustomTimer), for: .touchUpInside)
        startButton.snp.makeConstraints { $0.height.equalTo(44) }

        let buttonRow = UIStackView(arrangedSubviews: [startButton])
        buttonRow.isLayoutMarginsRelativeArrangement = true
        buttonRow.layoutMargins = .init(top: 12, left: 16, bottom: 14, right: 16)

        stack.addArrangedSubview(topRow)
        stack.addArrangedSubview(centerRow)
        stack.addArrangedSubview(buttonRow)

        objc_setAssociatedObject(self, "hoursField", hoursField, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, "minutesField", minutesField, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, "secondsField", secondsField, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        contentStack.addArrangedSubview(card)
    }

    private func makeTimeField(placeholder: String) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.keyboardType = .numberPad
        field.textAlignment = .center
        field.font = UIFont.monospacedDigitSystemFont(ofSize: 24, weight: .medium)
        field.textColor = .label
        field.backgroundColor = .tertiarySystemFill
        field.layer.cornerRadius = 10
        field.layer.cornerCurve = .continuous
        field.snp.makeConstraints { $0.width.equalTo(56); $0.height.equalTo(44) }
        return field
    }

    @objc private func reminderChanged(_ picker: UIDatePicker) {
        let hours = reminderPickers.map { Calendar.current.component(.hour, from: $0.date) }
        DataManager.shared.updateSettings { $0.reminderHours = hours }
        NotificationManager.shared.rescheduleAll()
    }

    @objc private func startCustomTimer() {
        let hoursField = objc_getAssociatedObject(self, "hoursField") as? UITextField
        let minutesField = objc_getAssociatedObject(self, "minutesField") as? UITextField
        let secondsField = objc_getAssociatedObject(self, "secondsField") as? UITextField

        let h = Int(hoursField?.text ?? "0") ?? 0
        let m = Int(minutesField?.text ?? "0") ?? 0
        let s = Int(secondsField?.text ?? "0") ?? 0

        let totalSeconds = TimeInterval(h * 3600 + m * 60 + s)
        guard totalSeconds > 0 else {
            SPIndicator.present(title: "Укажите время", preset: .error, haptic: .error)
            return
        }

        NotificationManager.shared.scheduleCustomReminder(
            seconds: totalSeconds,
            message: "У вас еще не все тренировки выполнены"
        )
        SPIndicator.present(title: "Таймер запущен", preset: .done, haptic: .success)
    }

    private func makeCard() -> UIVisualEffectView {
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 18
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        return card
    }

    private func makeSeparator() -> UIView {
        let line = UIView()
        line.backgroundColor = .separator
        line.snp.makeConstraints { $0.height.equalTo(0.5) }
        return line
    }
}

import UIKit
import SnapKit
import SPIndicator
import UniformTypeIdentifiers
import UserNotifications

final class SettingsViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let backgroundView = PersonalBackgroundView()

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
        ("Уфа", "Asia/Yekaterinberg"),
        ("Краснодар", "Europe/Moscow"),
        ("Ростов-на-Дону", "Europe/Moscow"),
        ("Волгоград", "Europe/Moscow"),
        ("Нижний Новгород", "Europe/Moscow"),
        ("Воронеж", "Europe/Moscow"),
        ("Пермь", "Asia/Yekaterinburg"),
        ("Томск", "Asia/Novosibirsk"),
        ("Барнаул", "Asia/Barnaul"),
        ("Мурманск", "Europe/Moscow"),
        ("Архангельск", "Europe/Moscow"),
        ("Петропавловск-Камчатский", "Asia/Kamchatka"),
        ("Южно-Сахалинск", "Asia/Sakhalin"),
        ("Анадырь", "Asia/Anadyr"),
        ("Норильск", "Asia/Krasnoyarsk"),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Настройки"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))

        setup()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadBackground), name: .steelBackgroundChanged, object: nil)
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

    private func setup() {
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        backgroundView.apply(BackgroundManager.shared.config)

        scrollView.backgroundColor = .clear
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
        let rows: [(title: String, subtitle: String, icon: String, iconBg: UIColor, action: () -> Void)] = [
            ("День рождения",  birthdaySubtitle(),     "gift.fill",                 .systemPink,   { [weak self] in self?.openBirthdayPicker() }),
            ("Оформление",     "Фон, шрифт",           "paintpalette.fill",         .systemIndigo, { [weak self] in self?.openAppearance() }),
            ("Провайдеры",     "Groq, Gemini",          "network",                   .systemTeal,   { [weak self] in self?.openProviders() }),
            ("Регион",         currentRegionSubtitle(), "globe.europe.africa.fill",  .systemBlue,   { [weak self] in self?.openRegionPicker() }),
            ("Серия",          "Пауза серии",           "bolt.fill",                 .systemGreen,  { [weak self] in self?.openStreakSettings() }),
            ("Резервная копия", "Экспорт / Импорт",      "doc.on.clipboard.fill",     .systemCyan,   { [weak self] in self?.openSync() }),
        ]

        for row in rows {
            let glass = LiquidGlassView(cornerRadius: 18, intensity: .thin)
            glass.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.35)
            let rowView = makeCategoryRow(
                title: row.title,
                subtitle: row.subtitle,
                icon: row.icon,
                iconBg: row.iconBg,
                action: row.action
            )
            glass.contentView.addSubview(rowView)
            rowView.snp.makeConstraints { $0.edges.equalToSuperview() }
            contentStack.addArrangedSubview(glass)
        }

        buildUUIDFooter()
    }

    private func buildUUIDFooter() {
        let containerStack = UIStackView()
        containerStack.axis = .vertical
        containerStack.spacing = 4
        containerStack.alignment = .center

        let uuidLabel = UILabel()
        uuidLabel.text = KeychainHelper.formattedUserID
        uuidLabel.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        uuidLabel.textColor = .tertiaryLabel
        uuidLabel.textAlignment = .center
        uuidLabel.isUserInteractionEnabled = true
        uuidLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyUUID)))

        let hintLabel = UILabel()
        hintLabel.text = "Нажмите на ID, чтобы скопировать"
        hintLabel.font = UIFont.systemFont(ofSize: 11)
        hintLabel.textColor = UIColor.tertiaryLabel.withAlphaComponent(0.7)
        hintLabel.textAlignment = .center

        containerStack.addArrangedSubview(uuidLabel)
        containerStack.addArrangedSubview(hintLabel)
        contentStack.addArrangedSubview(containerStack)
    }

    @objc private func copyUUID() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UIPasteboard.general.string = KeychainHelper.formattedUserID
        SPIndicator.present(title: "ID скопирован", preset: .done, haptic: .success)
    }

    private func birthdaySubtitle() -> String {
        let s = DataManager.shared.settings.birthdayDateString
        guard !s.isEmpty else { return "Не указан" }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: s) else { return "Не указан" }
        let display = DateFormatter(); display.dateFormat = "d MMMM yyyy"; display.locale = Locale(identifier: "ru_RU")
        return display.string(from: d)
    }

    private func openBirthdayPicker() {
        let alert = UIAlertController(title: "День рождения", message: "\n\n\n\n\n\n\n\n\n\n", preferredStyle: .alert)
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.maximumDate = Date()
        picker.locale = Locale(identifier: "ru_RU")

        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let current = DataManager.shared.settings.birthdayDateString
        if !current.isEmpty, let d = fmt.date(from: current) { picker.date = d }

        picker.frame = CGRect(x: 0, y: 44, width: 270, height: 160)
        alert.view.addSubview(picker)

        alert.addAction(UIAlertAction(title: "Сохранить", style: .default) { _ in
            let dateStr = fmt.string(from: picker.date)
            DataManager.shared.updateSettings { $0.birthdayDateString = dateStr }
            NotificationManager.shared.scheduleBirthdayNotifications(birthdayString: dateStr)
            SPIndicator.present(title: "Дата сохранена", preset: .done, haptic: .success)
        })
        alert.addAction(UIAlertAction(title: "Очистить", style: .destructive) { _ in
            DataManager.shared.updateSettings { $0.birthdayDateString = "" }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["steel.birthday.midnight","steel.birthday.noon"])
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }

    private func currentRegionSubtitle() -> String {
        let city = DataManager.shared.settings.regionCity
        return city.isEmpty ? "Москва" : city
    }

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
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

    private func openSync() {
        let vc = SyncViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func makeCategoryRow(title: String, subtitle: String, icon: String, iconBg: UIColor, action: @escaping () -> Void) -> UIView {
        let iconContainer = UIView()
        iconContainer.layer.cornerRadius = 10
        iconContainer.layer.cornerCurve = .continuous
        iconContainer.backgroundColor = iconBg
        iconContainer.snp.makeConstraints { $0.size.equalTo(38) }

        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)))
        iconView.tintColor = .white
        iconView.contentMode = .center
        iconContainer.addSubview(iconView)
        iconView.snp.makeConstraints { $0.center.equalToSuperview() }

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
        textStack.spacing = 3

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
        chevron.tintColor = .tertiaryLabel

        let row = UIStackView(arrangedSubviews: [iconContainer, textStack, UIView(), chevron])
        row.alignment = .center
        row.spacing = 14
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

// MARK: - StreakSettingsViewController
final class StreakSettingsViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let backgroundView = PersonalBackgroundView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Серия"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        setup()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadBackground), name: .steelBackgroundChanged, object: nil)
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

    private func setup() {
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        backgroundView.apply(BackgroundManager.shared.config)

        scrollView.backgroundColor = .clear
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
        pauseToggle.onTintColor = .systemGreen
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

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
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
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        card.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.5)
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        return card
    }
}

import UIKit
import SnapKit
import SPIndicator
import UniformTypeIdentifiers
import UserNotifications

// MARK: - SettingsViewController

final class SettingsViewController: UIViewController {

    private let scrollView    = UIScrollView()
    private let contentStack  = UIStackView()
    private let backgroundView = PersonalBackgroundView()
    private let glassTabBar   = SettingsGlassTabBar()

    private static let russianRegions: [(String, String)] = [
        ("Москва", "Europe/Moscow"), ("Санкт-Петербург", "Europe/Moscow"),
        ("Калининград", "Europe/Kaliningrad"), ("Самара", "Europe/Samara"),
        ("Казань", "Europe/Moscow"), ("Екатеринбург", "Asia/Yekaterinburg"),
        ("Омск", "Asia/Omsk"), ("Новосибирск", "Asia/Novosibirsk"),
        ("Красноярск", "Asia/Krasnoyarsk"), ("Иркутск", "Asia/Irkutsk"),
        ("Якутск", "Asia/Yakutsk"), ("Владивосток", "Asia/Vladivostok"),
        ("Магадан", "Asia/Magadan"), ("Камчатка", "Asia/Kamchatka"),
        ("Чита", "Asia/Chita"), ("Хабаровск", "Asia/Vladivostok"),
        ("Тюмень", "Asia/Yekaterinburg"), ("Уфа", "Asia/Yekaterinberg"),
        ("Краснодар", "Europe/Moscow"), ("Ростов-на-Дону", "Europe/Moscow"),
        ("Волгоград", "Europe/Moscow"), ("Нижний Новгород", "Europe/Moscow"),
        ("Воронеж", "Europe/Moscow"), ("Пермь", "Asia/Yekaterinburg"),
        ("Томск", "Asia/Novosibirsk"), ("Барнаул", "Asia/Barnaul"),
        ("Мурманск", "Europe/Moscow"), ("Архангельск", "Europe/Moscow"),
        ("Петропавловск-Камчатский", "Asia/Kamchatka"),
        ("Южно-Сахалинск", "Asia/Sakhalin"), ("Анадырь", "Asia/Anadyr"),
        ("Норильск", "Asia/Krasnoyarsk"),
    ]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationController?.setNavigationBarHidden(true, animated: false)
        setup()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadBackground),
                                               name: .steelBackgroundChanged, object: nil)
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

    // MARK: - Setup

    private func setup() {
        // Background
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        backgroundView.apply(BackgroundManager.shared.config)

        // Scroll
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.contentInset.bottom = 110
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }

        contentStack.axis = .vertical
        contentStack.spacing = 28
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.leading.trailing.equalTo(view).inset(20)
            $0.bottom.equalToSuperview()
        }

        buildHeaderCard()
        buildSection(title: "ЛИЧНОЕ",     rows: personalRows())
        buildSection(title: "ВНЕШНИЙ ВИД", rows: appearanceRows())
        buildSection(title: "ПРИЛОЖЕНИЕ",  rows: appRows())
        buildSection(title: "ДАННЫЕ",      rows: dataRows())
        buildUUIDFooter()

        // Glass tab bar floats above content
        view.addSubview(glassTabBar)
        glassTabBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(12)
            $0.height.equalTo(64)
        }
        glassTabBar.onTab = { [weak self] index in self?.switchToTab(index) }
    }

    // MARK: - Header Card

    private func buildHeaderCard() {
        let card = makeBlurCard(radius: 28)
        let content = card.contentView

        // Close button top-right
        let closeBtn = UIButton(type: .system)
        let closeCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        closeBtn.setImage(UIImage(systemName: "xmark", withConfiguration: closeCfg), for: .normal)
        closeBtn.tintColor = .secondaryLabel
        closeBtn.backgroundColor = UIColor.tertiarySystemFill
        closeBtn.layer.cornerRadius = 16
        closeBtn.clipsToBounds = true
        closeBtn.addTarget(self, action: #selector(close), for: .touchUpInside)
        content.addSubview(closeBtn)
        closeBtn.snp.makeConstraints {
            $0.top.trailing.equalToSuperview().inset(16)
            $0.size.equalTo(32)
        }

        // App icon
        let iconBg = UIView()
        iconBg.backgroundColor = .label
        iconBg.layer.cornerRadius = 22
        iconBg.layer.cornerCurve = .continuous
        content.addSubview(iconBg)
        iconBg.snp.makeConstraints {
            $0.top.equalToSuperview().offset(24)
            $0.leading.equalToSuperview().offset(20)
            $0.size.equalTo(52)
        }

        let iconView = UIImageView(image: UIImage(systemName: "bolt.shield.fill",
                                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .bold)))
        iconView.tintColor = .systemBackground
        iconView.contentMode = .scaleAspectFit
        iconBg.addSubview(iconView)
        iconView.snp.makeConstraints { $0.center.equalToSuperview() }

        // App name
        let appNameLabel = UILabel()
        appNameLabel.text = "Steel"
        appNameLabel.font = UIFont.systemFont(ofSize: 26, weight: .heavy)
        appNameLabel.textColor = .label
        content.addSubview(appNameLabel)
        appNameLabel.snp.makeConstraints {
            $0.leading.equalTo(iconBg.snp.trailing).offset(14)
            $0.centerY.equalTo(iconBg)
        }

        let subLabel = UILabel()
        subLabel.text = "Настройки"
        subLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subLabel.textColor = .secondaryLabel
        content.addSubview(subLabel)
        subLabel.snp.makeConstraints {
            $0.leading.equalTo(appNameLabel)
            $0.top.equalTo(appNameLabel.snp.bottom).offset(2)
        }

        // Divider
        let div = UIView()
        div.backgroundColor = UIColor.separator.withAlphaComponent(0.5)
        content.addSubview(div)
        div.snp.makeConstraints {
            $0.top.equalTo(iconBg.snp.bottom).offset(20)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(0.5)
        }

        // Streak pill
        let streak = DataManager.shared.settings.streakDays
        let streakPill = makePill(
            icon: "flame.fill", iconColor: .systemOrange,
            title: "\(streak) дней", subtitle: "Серия"
        )
        content.addSubview(streakPill)
        streakPill.snp.makeConstraints {
            $0.top.equalTo(div.snp.bottom).offset(16)
            $0.leading.equalToSuperview().offset(20)
        }

        // Habits count pill
        let habitsCount = DataManager.shared.fetchHabits().count
        let habitsPill = makePill(
            icon: "shield.lefthalf.filled", iconColor: .systemGreen,
            title: "\(habitsCount)", subtitle: "Привычек"
        )
        content.addSubview(habitsPill)
        habitsPill.snp.makeConstraints {
            $0.top.equalTo(streakPill)
            $0.leading.equalTo(streakPill.snp.trailing).offset(12)
        }

        // Username
        let name = DataManager.shared.settings.userName
        let nameLabel = UILabel()
        nameLabel.text = name.isEmpty ? "Воин" : name
        nameLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = .tertiaryLabel
        content.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.top.equalTo(streakPill.snp.bottom).offset(16)
            $0.leading.equalToSuperview().offset(20)
            $0.bottom.equalToSuperview().inset(20)
        }

        contentStack.addArrangedSubview(card)
    }

    private func makePill(icon: String, iconColor: UIColor, title: String, subtitle: String) -> UIView {
        let pill = UIView()
        pill.backgroundColor = UIColor.tertiarySystemFill
        pill.layer.cornerRadius = 14
        pill.layer.cornerCurve = .continuous

        let iconImg = UIImageView(image: UIImage(systemName: icon,
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
        iconImg.tintColor = iconColor
        iconImg.contentMode = .scaleAspectFit

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        titleLbl.textColor = .label

        let subtitleLbl = UILabel()
        subtitleLbl.text = subtitle
        subtitleLbl.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLbl.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [titleLbl, subtitleLbl])
        textStack.axis = .vertical
        textStack.spacing = 1

        let row = UIStackView(arrangedSubviews: [iconImg, textStack])
        row.alignment = .center
        row.spacing = 8
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 14)

        pill.addSubview(row)
        row.snp.makeConstraints { $0.edges.equalToSuperview() }
        return pill
    }

    // MARK: - Section Builder

    private func buildSection(title: String, rows: [SettingsRow]) {
        // Section title
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .tertiaryLabel
        label.letterSpacing(1.2)
        contentStack.addArrangedSubview(label)
        contentStack.setCustomSpacing(8, after: label)

        // Card
        let card = makeBlurCard(radius: 22)
        let inner = UIStackView()
        inner.axis = .vertical
        inner.spacing = 0
        card.contentView.addSubview(inner)
        inner.snp.makeConstraints { $0.edges.equalToSuperview() }

        for (i, row) in rows.enumerated() {
            let rowView = makeRow(row)
            inner.addArrangedSubview(rowView)
            if i < rows.count - 1 {
                let sep = makeSeparator()
                inner.addArrangedSubview(sep)
            }
        }

        contentStack.addArrangedSubview(card)
    }

    private func makeRow(_ row: SettingsRow) -> UIView {
        // Icon
        let iconWrap = UIView()
        iconWrap.backgroundColor = row.color
        iconWrap.layer.cornerRadius = 11
        iconWrap.layer.cornerCurve = .continuous
        iconWrap.snp.makeConstraints { $0.size.equalTo(40) }

        let iconImg = UIImageView(image: UIImage(systemName: row.icon,
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)))
        iconImg.tintColor = .white
        iconImg.contentMode = .center
        iconWrap.addSubview(iconImg)
        iconImg.snp.makeConstraints { $0.center.equalToSuperview() }

        // Labels
        let titleLbl = UILabel()
        titleLbl.text = row.title
        titleLbl.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLbl.textColor = .label

        let subtitleLbl = UILabel()
        subtitleLbl.text = row.subtitle
        subtitleLbl.font = UIFont.systemFont(ofSize: 13)
        subtitleLbl.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [titleLbl, subtitleLbl])
        textStack.axis = .vertical
        textStack.spacing = 2

        // Chevron
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right",
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)))
        chevron.tintColor = UIColor.tertiaryLabel

        let hstack = UIStackView(arrangedSubviews: [iconWrap, textStack, UIView(), chevron])
        hstack.alignment = .center
        hstack.spacing = 14
        hstack.isLayoutMarginsRelativeArrangement = true
        hstack.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        hstack.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleRowTap(_:)))
        hstack.addGestureRecognizer(tap)
        objc_setAssociatedObject(hstack, "rowAction", row.action, .OBJC_ASSOCIATION_COPY_NONATOMIC)

        return hstack
    }

    // MARK: - Row Definitions

    private struct SettingsRow {
        let title: String
        let subtitle: String
        let icon: String
        let color: UIColor
        let action: () -> Void
    }

    private func personalRows() -> [SettingsRow] {[
        SettingsRow(title: "День рождения", subtitle: birthdaySubtitle(),
                    icon: "gift.fill", color: .systemPink,
                    action: { [weak self] in self?.openBirthdayPicker() }),
        SettingsRow(title: "Регион", subtitle: currentRegionSubtitle(),
                    icon: "globe.europe.africa.fill", color: .systemBlue,
                    action: { [weak self] in self?.openRegionPicker() }),
    ]}

    private func appearanceRows() -> [SettingsRow] {[
        SettingsRow(title: "Оформление", subtitle: "Фон, шрифт",
                    icon: "paintpalette.fill", color: .systemIndigo,
                    action: { [weak self] in self?.openAppearance() }),
    ]}

    private func appRows() -> [SettingsRow] {[
        SettingsRow(title: "Серия", subtitle: "Пауза серии",
                    icon: "bolt.fill", color: .systemGreen,
                    action: { [weak self] in self?.openStreakSettings() }),
        SettingsRow(title: "Провайдеры", subtitle: "Groq, Gemini",
                    icon: "network", color: .systemTeal,
                    action: { [weak self] in self?.openProviders() }),
    ]}

    private func dataRows() -> [SettingsRow] {[
        SettingsRow(title: "Резервная копия", subtitle: "Экспорт / Импорт",
                    icon: "doc.on.clipboard.fill", color: .systemCyan,
                    action: { [weak self] in self?.openSync() }),
    ]}

    // MARK: - UUID Footer

    private func buildUUIDFooter() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center

        let uuidLabel = UILabel()
        uuidLabel.text = KeychainHelper.formattedUserID
        uuidLabel.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        uuidLabel.textColor = .tertiaryLabel
        uuidLabel.isUserInteractionEnabled = true
        uuidLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyUUID)))

        let hint = UILabel()
        hint.text = "Нажмите на ID, чтобы скопировать"
        hint.font = UIFont.systemFont(ofSize: 11)
        hint.textColor = UIColor.quaternaryLabel

        stack.addArrangedSubview(uuidLabel)
        stack.addArrangedSubview(hint)
        contentStack.addArrangedSubview(stack)
    }

    // MARK: - Tab Switching

    private func switchToTab(_ index: Int) {
        // nav controller was presented by ProfileVC which lives in the tab bar
        let presenter = navigationController?.presentingViewController ?? presentingViewController
        let tbc = presenter?.tabBarController ?? (presenter as? UITabBarController)
        dismiss(animated: true) { tbc?.selectedIndex = index }
    }

    // MARK: - Actions

    @objc private func handleRowTap(_ gesture: UITapGestureRecognizer) {
        guard let action = objc_getAssociatedObject(gesture.view, "rowAction") as? () -> Void else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Animate press
        UIView.animate(withDuration: 0.1, animations: {
            gesture.view?.alpha = 0.6
        }) { _ in
            UIView.animate(withDuration: 0.15) { gesture.view?.alpha = 1 }
        }
        action()
    }

    @objc private func copyUUID() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UIPasteboard.general.string = KeychainHelper.formattedUserID
        SPIndicator.present(title: "ID скопирован", preset: .done, haptic: .success)
    }

    @objc private func close() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss(animated: true)
    }

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
    }

    // MARK: - Navigation

    private func openBirthdayPicker() {
        let alert = UIAlertController(title: "День рождения",
                                      message: "\n\n\n\n\n\n\n\n\n\n",
                                      preferredStyle: .alert)
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
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["steel.birthday.midnight", "steel.birthday.noon"])
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func openRegionPicker() {
        let alert = UIAlertController(title: "Выберите город", message: nil, preferredStyle: .actionSheet)
        for (city, tz) in Self.russianRegions {
            alert.addAction(UIAlertAction(title: city, style: .default) { _ in
                DataManager.shared.updateSettings { $0.regionCity = city; $0.regionTimeZone = tz }
                DataManager.shared.setTimeZone(TimeZone(identifier: tz) ?? TimeZone(identifier: "Europe/Moscow")!)
                SPIndicator.present(title: city, preset: .done, haptic: .success)
            })
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(alert, animated: true)
    }

    private func openAppearance() {
        let vc = AppearanceViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
        present(nav, animated: true)
    }

    private func openProviders() {
        let vc = ProvidersViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
        present(nav, animated: true)
    }

    private func openStreakSettings() {
        let vc = StreakSettingsViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
        present(nav, animated: true)
    }

    private func openSync() {
        let vc = SyncViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
        present(nav, animated: true)
    }

    // MARK: - Helpers

    private func birthdaySubtitle() -> String {
        let s = DataManager.shared.settings.birthdayDateString
        guard !s.isEmpty else { return "Не указан" }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: s) else { return "Не указан" }
        let display = DateFormatter()
        display.dateFormat = "d MMMM yyyy"
        display.locale = Locale(identifier: "ru_RU")
        return display.string(from: d)
    }

    private func currentRegionSubtitle() -> String {
        let city = DataManager.shared.settings.regionCity
        return city.isEmpty ? "Москва" : city
    }

    private func makeBlurCard(radius: CGFloat) -> UIVisualEffectView {
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        card.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.45)
        card.layer.cornerRadius = radius
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        return card
    }

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
        v.snp.makeConstraints { $0.height.equalTo(0.5) }
        return v
    }
}

// MARK: - SettingsGlassTabBar

final class SettingsGlassTabBar: UIView {

    var onTab: ((Int) -> Void)?

    private let glass = LiquidGlassView(cornerRadius: 24, intensity: .regular)
    private var buttons: [UIButton] = []

    private let items: [(icon: String, label: String)] = [
        ("flame.fill",           "Сегодня"),
        ("shield.lefthalf.filled", "Привычки"),
        ("person.fill",          "Профиль"),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupView() {
        // Shadow beneath
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = 20
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 6)

        glass.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.3)
        addSubview(glass)
        glass.snp.makeConstraints { $0.edges.equalToSuperview() }

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill
        glass.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        for (index, item) in items.enumerated() {
            let btn = makeTabButton(icon: item.icon, label: item.label, tag: index)
            buttons.append(btn)
            stack.addArrangedSubview(btn)
        }
    }

    private func makeTabButton(icon: String, label: String, tag: Int) -> UIButton {
        let btn = UIButton(type: .system)
        btn.tag = tag
        btn.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)

        let iconImg = UIImageView(image: UIImage(systemName: icon,
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)))
        iconImg.tintColor = .label
        iconImg.contentMode = .scaleAspectFit

        let lbl = UILabel()
        lbl.text = label
        lbl.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        lbl.textColor = .secondaryLabel
        lbl.textAlignment = .center

        let vstack = UIStackView(arrangedSubviews: [iconImg, lbl])
        vstack.axis = .vertical
        vstack.spacing = 4
        vstack.alignment = .center
        vstack.isUserInteractionEnabled = false

        btn.addSubview(vstack)
        vstack.snp.makeConstraints { $0.center.equalToSuperview() }
        iconImg.snp.makeConstraints { $0.width.height.equalTo(24) }

        return btn
    }

    @objc private func tabTapped(_ sender: UIButton) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Bounce animation
        UIView.animate(withDuration: 0.12, animations: {
            sender.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0,
                           usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 0.8) {
                sender.transform = .identity
            }
        }

        onTab?(sender.tag)
    }
}

// MARK: - UILabel letter spacing helper

private extension UILabel {
    func letterSpacing(_ spacing: CGFloat) {
        guard let text = text else { return }
        let attr = NSMutableAttributedString(string: text)
        attr.addAttribute(.kern, value: spacing, range: NSRange(location: 0, length: text.count))
        attributedText = attr
    }
}

// MARK: - StreakSettingsViewController

final class StreakSettingsViewController: UIViewController {
    private let backgroundView = PersonalBackgroundView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Серия"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
        setup()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadBackground),
                                               name: .steelBackgroundChanged, object: nil)
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

        let card = makeCard()
        view.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            $0.leading.trailing.equalToSuperview().inset(20)
        }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let pauseLabel = UILabel()
        pauseLabel.text = "Пауза серии"
        pauseLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        pauseLabel.textColor = .label

        let pauseToggle = UISwitch()
        pauseToggle.onTintColor = .systemGreen
        pauseToggle.isOn = DataManager.shared.settings.streakPaused
        pauseToggle.addTarget(self, action: #selector(streakPauseChanged(_:)), for: .valueChanged)

        let pauseRow = UIStackView(arrangedSubviews: [pauseLabel, UIView(), pauseToggle])
        pauseRow.alignment = .center
        pauseRow.isLayoutMarginsRelativeArrangement = true
        pauseRow.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.addArrangedSubview(pauseRow)

        let sep = UIView()
        sep.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
        sep.snp.makeConstraints { $0.height.equalTo(0.5) }
        stack.addArrangedSubview(sep)

        let descLabel = UILabel()
        descLabel.text = "Серия не сбросится, если вы не завершили день"
        descLabel.font = UIFont.systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabel
        descLabel.numberOfLines = 2
        let descRow = UIStackView(arrangedSubviews: [descLabel])
        descRow.isLayoutMarginsRelativeArrangement = true
        descRow.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 12, right: 16)
        stack.addArrangedSubview(descRow)
    }

    @objc private func reloadBackground() { backgroundView.apply(BackgroundManager.shared.config) }

    @objc private func streakPauseChanged(_ toggle: UISwitch) {
        let today = DataManager.shared.dayKey(for: Date())
        DataManager.shared.updateSettings {
            $0.streakPaused = toggle.isOn
            $0.streakPausedSince = toggle.isOn ? today : ""
        }
        SPIndicator.present(title: toggle.isOn ? "Серия на паузе" : "Серия активна",
                            preset: .done, haptic: .success)
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

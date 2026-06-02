import UIKit
import SnapKit
import SPIndicator
import UserNotifications

// MARK: - SettingsViewController

final class SettingsViewController: UIViewController {

    private let scrollView     = UIScrollView()
    private let contentStack   = UIStackView()
    private let backgroundView = PersonalBackgroundView()
    private let glassTabBar    = SettingsGlassTabBar()

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
        title = "Настройки"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)),
            style: .plain, target: self, action: #selector(close)
        )
        navigationItem.rightBarButtonItem?.tintColor = .secondaryLabel
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
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        backgroundView.apply(BackgroundManager.shared.config)

        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.contentInset.bottom = 96
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }

        contentStack.axis = .vertical
        contentStack.spacing = 32
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(8)
            $0.leading.trailing.equalTo(view).inset(16)
            $0.bottom.equalToSuperview()
        }

        buildGroup(rows: [
            makeRow(icon: "gift.fill",               color: .systemPink,    title: "День рождения", subtitle: birthdaySubtitle(),      action: { [weak self] in self?.openBirthdayPicker() }),
            makeRow(icon: "globe.europe.africa.fill", color: .systemBlue,    title: "Регион",        subtitle: currentRegionSubtitle(), action: { [weak self] in self?.openRegionPicker() }),
            makeRow(icon: "paintpalette.fill",        color: .systemIndigo,  title: "Оформление",    subtitle: "Фон, шрифт",            action: { [weak self] in self?.openAppearance() }),
            makeRow(icon: "bolt.fill",                color: .systemGreen,   title: "Серия",         subtitle: "Пауза серии",           action: { [weak self] in self?.openStreakSettings() }),
            makeRow(icon: "network",                  color: .systemTeal,    title: "Провайдеры",    subtitle: "Groq, Gemini",          action: { [weak self] in self?.openProviders() }),
            makeRow(icon: "doc.on.clipboard.fill",    color: .systemCyan,    title: "Резервная копия", subtitle: "Экспорт / Импорт",   action: { [weak self] in self?.openSync() }),
        ])

        buildUUIDFooter()

        // Floating glass tab bar
        view.addSubview(glassTabBar)
        glassTabBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(10)
            $0.height.equalTo(60)
        }
        glassTabBar.onTab = { [weak self] index in self?.switchToTab(index) }
    }

    // MARK: - Group Builder

    private func buildGroup(rows: [UIView]) {
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        card.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.5)
        card.layer.cornerRadius = 16
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        for (i, row) in rows.enumerated() {
            stack.addArrangedSubview(row)
            if i < rows.count - 1 {
                let sep = UIView()
                sep.backgroundColor = UIColor.separator.withAlphaComponent(0.35)
                sep.snp.makeConstraints { $0.height.equalTo(0.5) }
                let wrapper = UIStackView(arrangedSubviews: [sep])
                wrapper.isLayoutMarginsRelativeArrangement = true
                wrapper.layoutMargins = UIEdgeInsets(top: 0, left: 52, bottom: 0, right: 0)
                stack.addArrangedSubview(wrapper)
            }
        }
        contentStack.addArrangedSubview(card)
    }

    // MARK: - Row Factory

    private func makeRow(icon: String, color: UIColor, title: String, subtitle: String, action: @escaping () -> Void) -> UIView {
        // Icon
        let iconWrap = UIView()
        iconWrap.backgroundColor = color
        iconWrap.layer.cornerRadius = 9
        iconWrap.layer.cornerCurve = .continuous
        iconWrap.snp.makeConstraints { $0.size.equalTo(34) }

        let iconImg = UIImageView(image: UIImage(systemName: icon,
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)))
        iconImg.tintColor = .white
        iconImg.contentMode = .center
        iconWrap.addSubview(iconImg)
        iconImg.snp.makeConstraints { $0.center.equalToSuperview() }

        // Labels
        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        titleLbl.textColor = .label

        let subtitleLbl = UILabel()
        subtitleLbl.text = subtitle
        subtitleLbl.font = UIFont.systemFont(ofSize: 14)
        subtitleLbl.textColor = .secondaryLabel
        subtitleLbl.setContentHuggingPriority(.required, for: .horizontal)
        subtitleLbl.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Chevron
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right",
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)))
        chevron.tintColor = .tertiaryLabel

        let row = UIStackView(arrangedSubviews: [iconWrap, titleLbl, UIView(), subtitleLbl, chevron])
        row.alignment = .center
        row.spacing = 12
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 11, left: 12, bottom: 11, right: 14)
        row.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(rowTapped(_:)))
        row.addGestureRecognizer(tap)
        objc_setAssociatedObject(row, "rowAction", action, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        return row
    }

    // MARK: - UUID Footer

    private func buildUUIDFooter() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 3
        stack.alignment = .center

        let lbl = UILabel()
        lbl.text = KeychainHelper.formattedUserID
        lbl.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        lbl.textColor = .quaternaryLabel
        lbl.isUserInteractionEnabled = true
        lbl.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyUUID)))

        let hint = UILabel()
        hint.text = "Нажмите, чтобы скопировать ID"
        hint.font = UIFont.systemFont(ofSize: 11)
        hint.textColor = .quaternaryLabel

        stack.addArrangedSubview(lbl)
        stack.addArrangedSubview(hint)
        contentStack.addArrangedSubview(stack)
    }

    // MARK: - Tab Switch

    private func switchToTab(_ index: Int) {
        let presenter = navigationController?.presentingViewController ?? presentingViewController
        let tbc = presenter?.tabBarController ?? (presenter as? UITabBarController)
        dismiss(animated: true) { tbc?.selectedIndex = index }
    }

    // MARK: - Actions

    @objc private func rowTapped(_ gesture: UITapGestureRecognizer) {
        guard let action = objc_getAssociatedObject(gesture.view, "rowAction") as? () -> Void else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        action()
    }

    @objc private func copyUUID() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UIPasteboard.general.string = KeychainHelper.formattedUserID
        SPIndicator.present(title: "ID скопирован", preset: .done, haptic: .success)
    }

    @objc private func close() { dismiss(animated: true) }

    @objc private func reloadBackground() { backgroundView.apply(BackgroundManager.shared.config) }

    // MARK: - Navigation

    private func openBirthdayPicker() {
        let alert = UIAlertController(title: "День рождения", message: "\n\n\n\n\n\n\n\n\n\n", preferredStyle: .alert)
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.maximumDate = Date()
        picker.locale = Locale(identifier: "ru_RU")
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let cur = DataManager.shared.settings.birthdayDateString
        if !cur.isEmpty, let d = fmt.date(from: cur) { picker.date = d }
        picker.frame = CGRect(x: 0, y: 44, width: 270, height: 160)
        alert.view.addSubview(picker)
        alert.addAction(UIAlertAction(title: "Сохранить", style: .default) { _ in
            let s = fmt.string(from: picker.date)
            DataManager.shared.updateSettings { $0.birthdayDateString = s }
            NotificationManager.shared.scheduleBirthdayNotifications(birthdayString: s)
            SPIndicator.present(title: "Сохранено", preset: .done, haptic: .success)
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
                DataManager.shared.setTimeZone(TimeZone(identifier: tz) ?? .current)
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
        navigationController?.pushViewController(vc, animated: true)
    }

    private func openProviders() {
        let vc = ProvidersViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func openStreakSettings() {
        let vc = StreakSettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func openSync() {
        let vc = SyncViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Helpers

    private func birthdaySubtitle() -> String {
        let s = DataManager.shared.settings.birthdayDateString
        guard !s.isEmpty else { return "Не указан" }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: s) else { return "Не указан" }
        let disp = DateFormatter(); disp.dateFormat = "d MMM yyyy"; disp.locale = Locale(identifier: "ru_RU")
        return disp.string(from: d)
    }

    private func currentRegionSubtitle() -> String {
        let c = DataManager.shared.settings.regionCity
        return c.isEmpty ? "Москва" : c
    }
}

// MARK: - SettingsGlassTabBar

final class SettingsGlassTabBar: UIView {

    var onTab: ((Int) -> Void)?

    private let glass = LiquidGlassView(cornerRadius: 20, intensity: .regular)

    private let items: [(icon: String, label: String)] = [
        ("flame.fill",             "Сегодня"),
        ("shield.lefthalf.filled", "Привычки"),
        ("person.fill",            "Профиль"),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = 18
        layer.shadowOpacity = 0.14
        layer.shadowOffset = CGSize(width: 0, height: 4)

        glass.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.28)
        addSubview(glass)
        glass.snp.makeConstraints { $0.edges.equalToSuperview() }

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        glass.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        for (i, item) in items.enumerated() {
            stack.addArrangedSubview(makeBtn(icon: item.icon, label: item.label, tag: i))
        }
    }

    private func makeBtn(icon: String, label: String, tag: Int) -> UIView {
        let btn = UIButton(type: .system)
        btn.tag = tag
        btn.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)

        let img = UIImageView(image: UIImage(systemName: icon,
                                             withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)))
        img.tintColor = .secondaryLabel
        img.contentMode = .scaleAspectFit
        img.isUserInteractionEnabled = false

        let lbl = UILabel()
        lbl.text = label
        lbl.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        lbl.textColor = .secondaryLabel
        lbl.textAlignment = .center
        lbl.isUserInteractionEnabled = false

        let vs = UIStackView(arrangedSubviews: [img, lbl])
        vs.axis = .vertical
        vs.spacing = 3
        vs.alignment = .center
        vs.isUserInteractionEnabled = false

        btn.addSubview(vs)
        vs.snp.makeConstraints { $0.center.equalToSuperview() }
        img.snp.makeConstraints { $0.size.equalTo(22) }
        return btn
    }

    @objc private func tap(_ sender: UIButton) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UIView.animate(withDuration: 0.1, animations: { sender.transform = CGAffineTransform(scaleX: 0.84, y: 0.84) }) { _ in
            UIView.animate(withDuration: 0.22, delay: 0,
                           usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8) {
                sender.transform = .identity
            }
        }
        onTab?(sender.tag)
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
        NotificationCenter.default.addObserver(self, selector: #selector(bg),
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

        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        card.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.5)
        card.layer.cornerRadius = 16
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        view.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        let inner = UIStackView()
        inner.axis = .vertical
        inner.spacing = 0
        card.contentView.addSubview(inner)
        inner.snp.makeConstraints { $0.edges.equalToSuperview() }

        let tgl = UISwitch()
        tgl.onTintColor = .systemGreen
        tgl.isOn = DataManager.shared.settings.streakPaused
        tgl.addTarget(self, action: #selector(toggle(_:)), for: .valueChanged)

        let label = UILabel()
        label.text = "Пауза серии"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .label

        let row = UIStackView(arrangedSubviews: [label, UIView(), tgl])
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        inner.addArrangedSubview(row)

        let sep = UIView()
        sep.backgroundColor = UIColor.separator.withAlphaComponent(0.35)
        sep.snp.makeConstraints { $0.height.equalTo(0.5) }
        inner.addArrangedSubview(sep)

        let desc = UILabel()
        desc.text = "Серия не сбросится, если вы не завершили день"
        desc.font = UIFont.systemFont(ofSize: 13)
        desc.textColor = .secondaryLabel
        desc.numberOfLines = 2
        let dRow = UIStackView(arrangedSubviews: [desc])
        dRow.isLayoutMarginsRelativeArrangement = true
        dRow.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 12, right: 16)
        inner.addArrangedSubview(dRow)
    }

    @objc private func bg() { backgroundView.apply(BackgroundManager.shared.config) }

    @objc private func toggle(_ s: UISwitch) {
        let today = DataManager.shared.dayKey(for: Date())
        DataManager.shared.updateSettings {
            $0.streakPaused = s.isOn
            $0.streakPausedSince = s.isOn ? today : ""
        }
        SPIndicator.present(title: s.isOn ? "Серия на паузе" : "Серия активна",
                            preset: .done, haptic: .success)
    }
}

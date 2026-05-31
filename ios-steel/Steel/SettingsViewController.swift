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

        setupMainSection()
        setupRegionSection()
        setupStreakSection()
    }

    private func setupMainSection() {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let appearance = makeSettingsRow(title: "Оформление", subtitle: "Фон, шрифт", icon: "paintpalette.fill", color: .systemPurple) { [weak self] in
            self?.openAppearance()
        }
        let providers = makeSettingsRow(title: "Провайдеры", subtitle: "Groq, Gemini", icon: "server.rack", color: .systemOrange) { [weak self] in
            self?.openProviders()
        }

        stack.addArrangedSubview(appearance)
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(providers)
        contentStack.addArrangedSubview(card)
    }

    private func setupRegionSection() {
        let title = sectionTitle("РЕГИОН")
        contentStack.addArrangedSubview(title)

        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let regionRow = makeRegionRow()
        stack.addArrangedSubview(regionRow)

        let descLabel = UILabel()
        descLabel.text = "Серия обнуляется в 00:00 по выбранному региону"
        descLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        descLabel.textColor = .secondaryLabel
        descLabel.numberOfLines = 2
        let descRow = UIStackView(arrangedSubviews: [descLabel])
        descRow.isLayoutMarginsRelativeArrangement = true
        descRow.layoutMargins = .init(top: 0, left: 16, bottom: 12, right: 16)
        stack.addArrangedSubview(descRow)

        contentStack.addArrangedSubview(card)
    }

    private func makeRegionRow() -> UIView {
        let label = UILabel()
        label.text = "Часовой пояс"
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = .label

        let currentRegion = DataManager.shared.settings.regionCity
        let valueLabel = UILabel()
        valueLabel.text = currentRegion.isEmpty ? "Москва" : currentRegion
        valueLabel.font = UIFont.preferredFont(forTextStyle: .body).withWeight(.semibold)
        valueLabel.textColor = .secondaryLabel
        valueLabel.tag = 300

        let row = UIStackView(arrangedSubviews: [label, UIView(), valueLabel])
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = .init(top: 14, left: 16, bottom: 14, right: 16)
        row.tag = 301

        let tap = UITapGestureRecognizer(target: self, action: #selector(openRegionPicker))
        row.addGestureRecognizer(tap)
        row.isUserInteractionEnabled = true

        return row
    }

    private func setupStreakSection() {
        let title = sectionTitle("СЕРИЯ")
        contentStack.addArrangedSubview(title)

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
            alert.addAction(UIAlertAction(title: city, style: .default) { [weak self] _ in
                DataManager.shared.updateSettings {
                    $0.regionCity = city
                    $0.regionTimeZone = tz
                }
                DataManager.shared.setTimeZone(TimeZone(identifier: tz) ?? TimeZone(identifier: "Europe/Moscow")!)
                SPIndicator.present(title: city, preset: .done, haptic: .success)
                self?.updateRegionLabel(city)
            })
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        if let popover = alert.popoverPresentationController {
            if let regionRow = view.viewWithTag(301) {
                popover.sourceView = regionRow
            }
        }
        present(alert, animated: true)
    }

    private func updateRegionLabel(_ city: String) {
        if let row = view.viewWithTag(301) as? UIStackView,
           let valueLabel = row.viewWithTag(300) as? UILabel {
            valueLabel.text = city
        }
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

    private func sectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        return label
    }

    private func separator() -> UIView {
        let line = UIView()
        line.backgroundColor = .separator
        line.snp.makeConstraints { $0.height.equalTo(0.5) }
        return line
    }

    private func makeSettingsRow(title: String, subtitle: String, icon: String, color: UIColor, action: @escaping () -> Void) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .white
        iconView.contentMode = .center
        iconView.layer.cornerRadius = 8
        iconView.layer.cornerCurve = .continuous
        iconView.backgroundColor = color
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

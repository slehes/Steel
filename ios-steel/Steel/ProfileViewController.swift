import UIKit
import SnapKit
import SPIndicator

final class ProfileViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let avatarView = UIImageView()
    private let nameField = UITextField()
    private let streakLabel = UILabel()
    private let statsStack = UIStackView()
    private var reminderPickers: [UIDatePicker] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .always
        setup()
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .steelSettingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .steelTasksChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
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

        setupHeader()
        setupStreak()
        setupStats()
        setupReminders()
        setupBackgroundSection()
    }

    private func setupHeader() {
        avatarView.image = UIImage(systemName: "person.crop.circle.fill")
        avatarView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 84, weight: .regular)
        avatarView.tintColor = .label
        avatarView.contentMode = .center
        avatarView.isUserInteractionEnabled = true
        avatarView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(changeAvatar)))

        nameField.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        nameField.textColor = .label
        nameField.textAlignment = .center
        nameField.borderStyle = .none
        nameField.returnKeyType = .done
        nameField.delegate = self

        let header = UIStackView(arrangedSubviews: [avatarView, nameField])
        header.axis = .vertical
        header.alignment = .center
        header.spacing = 8
        contentStack.addArrangedSubview(header)
    }

    private func setupStreak() {
        let card = makeCard()
        streakLabel.font = UIFont.systemFont(ofSize: 44, weight: .heavy)
        streakLabel.textColor = .label
        streakLabel.textAlignment = .center

        let caption = UILabel()
        caption.text = "ТЕКУЩАЯ СЕРИЯ"
        caption.font = UIFont.preferredFont(forTextStyle: .caption1)
        caption.textColor = .secondaryLabel
        caption.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [streakLabel, caption])
        stack.axis = .vertical
        stack.spacing = 2
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(20) }
        contentStack.addArrangedSubview(card)
    }

    private func setupStats() {
        let card = makeCard()
        statsStack.axis = .vertical
        statsStack.spacing = 0
        card.contentView.addSubview(statsStack)
        statsStack.snp.makeConstraints { $0.edges.equalToSuperview() }
        contentStack.addArrangedSubview(card)
    }

    private func setupReminders() {
        let title = sectionTitle("НАПОМИНАНИЯ")
        contentStack.addArrangedSubview(title)

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
            if index < 2 { stack.addArrangedSubview(separator()) }
        }
        contentStack.addArrangedSubview(card)
    }

    private func setupBackgroundSection() {
        let title = sectionTitle("ФОН ЭКРАНА")
        contentStack.addArrangedSubview(title)

        let choose = makeRowButton(title: "Выбрать фото или видео", icon: "photo.on.rectangle.angled", action: #selector(chooseBackground))
        let dimToggleRow = makeDimRow()
        let disable = makeRowButton(title: "Отключить фон", icon: "xmark.circle", action: #selector(disableBackground), destructive: true)

        let card = makeCard()
        let stack = UIStackView(arrangedSubviews: [choose, separator(), dimToggleRow, separator(), disable])
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }
        contentStack.addArrangedSubview(card)
    }

    private func makeDimRow() -> UIView {
        let label = UILabel()
        label.text = "Затемнение для читаемости"
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = .label
        label.numberOfLines = 2

        let toggle = UISwitch()
        toggle.onTintColor = .label
        toggle.isOn = DataManager.shared.settings.background.dimmed
        toggle.addTarget(self, action: #selector(dimChanged(_:)), for: .valueChanged)

        let row = UIStackView(arrangedSubviews: [label, UIView(), toggle])
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = .init(top: 12, left: 16, bottom: 12, right: 16)
        return row
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

    private func makeRowButton(title: String, icon: String, action: Selector, destructive: Bool = false) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePadding = 12
        config.contentInsets = .init(top: 14, leading: 16, bottom: 14, trailing: 16)
        config.baseForegroundColor = destructive ? .secondaryLabel : .label
        let button = UIButton(configuration: config)
        button.contentHorizontalAlignment = .leading
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func statRow(title: String, value: String, isLast: Bool) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        titleLabel.textColor = .secondaryLabel

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.preferredFont(forTextStyle: .body).withWeight(.semibold)
        valueLabel.textColor = .label

        let row = UIStackView(arrangedSubviews: [titleLabel, UIView(), valueLabel])
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = .init(top: 14, left: 16, bottom: 14, right: 16)

        let container = UIStackView(arrangedSubviews: [row])
        container.axis = .vertical
        if !isLast { container.addArrangedSubview(separator()) }
        return container
    }

    @objc private func refresh() {
        let settings = DataManager.shared.settings
        nameField.text = settings.userName
        streakLabel.text = "\(settings.streakDays)"

        statsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let cleanDays = DataManager.shared.fetchHabits().map(\.cleanDays).max() ?? 0
        let rows = [
            ("Всего заданий", "\(settings.totalCompletedTasks)"),
            ("Частое упражнение", settings.mostFrequentExercise),
            ("Дней без срыва", "\(cleanDays)"),
        ]
        for (i, row) in rows.enumerated() {
            statsStack.addArrangedSubview(statRow(title: row.0, value: row.1, isLast: i == rows.count - 1))
        }
    }

    @objc private func changeAvatar() {
        UIImpactFeedbackGenerator.tap(.light)
        let symbols = ["person.crop.circle.fill", "figure.strengthtraining.traditional.circle.fill", "flame.circle.fill", "bolt.circle.fill", "shield.fill"]
        let sheet = UIAlertController(title: "Аватар", message: nil, preferredStyle: .actionSheet)
        for symbol in symbols {
            sheet.addAction(UIAlertAction(title: symbol, style: .default) { [weak self] _ in
                self?.avatarView.image = UIImage(systemName: symbol)
            })
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        sheet.popoverPresentationController?.sourceView = avatarView
        present(sheet, animated: true)
    }

    @objc private func reminderChanged(_ picker: UIDatePicker) {
        let hours = reminderPickers.map { Calendar.current.component(.hour, from: $0.date) }
        DataManager.shared.updateSettings { $0.reminderHours = hours }
        NotificationManager.shared.rescheduleAll()
    }

    @objc private func chooseBackground() {
        BackgroundPicker.shared.present(from: self)
    }

    @objc private func disableBackground() {
        BackgroundManager.shared.disable()
        SPIndicator.present(title: "Фон отключён", preset: .done, haptic: .success)
    }

    @objc private func dimChanged(_ toggle: UISwitch) {
        BackgroundManager.shared.setDimmed(toggle.isOn)
    }
}

extension ProfileViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        let name = textField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !name.isEmpty else {
            textField.text = DataManager.shared.settings.userName
            return
        }
        DataManager.shared.updateSettings { $0.userName = name }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

import UIKit
import SnapKit
import SPIndicator
import PhotosUI

final class ProfileViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let backgroundView = PersonalBackgroundView()
    private let pinnedTitleLabel = UILabel()

    private let avatarView = UIImageView()
    private let nameField = UITextField()
    private let musicPreviewButton = UIButton(type: .system)
    private let streakLabel = UILabel()
    private let statsStack = UIStackView()
    private var reminderPickers: [UIDatePicker] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupBackground()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape.fill"),
            style: .plain,
            target: self,
            action: #selector(openSettings)
        )
        setupPinnedTitle()
        setup()
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .steelSettingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .steelTasksChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .steelHabitsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadBackground), name: .steelBackgroundChanged, object: nil)

        MusicManager.shared.onSongChanged = { [weak self] in
            DispatchQueue.main.async { self?.updateMusicPreview() }
        }
        MusicManager.shared.onPlaybackStateChanged = { [weak self] in
            DispatchQueue.main.async { self?.updateMusicPreview() }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        backgroundView.apply(BackgroundManager.shared.config)
        backgroundView.resumeVideo()
        navigationController?.navigationBar.isHidden = true
        refresh()
        updateMusicPreview()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backgroundView.pauseVideo()
        navigationController?.navigationBar.isHidden = false
    }

    private func setupBackground() {
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        backgroundView.apply(BackgroundManager.shared.config)
    }

    private func setupPinnedTitle() {
        pinnedTitleLabel.text = "Профиль"
        pinnedTitleLabel.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        pinnedTitleLabel.textColor = .label
        view.addSubview(pinnedTitleLabel)
        pinnedTitleLabel.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).inset(8)
            $0.leading.equalToSuperview().inset(20)
        }
    }

    private func setup() {
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        scrollView.alwaysBounceVertical = true
        scrollView.delaysContentTouches = false

        contentStack.axis = .vertical
        contentStack.spacing = 24
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(56)
            $0.leading.trailing.equalTo(view).inset(20)
            $0.bottom.equalToSuperview().inset(40)
        }

        setupHeader()
        setupMusicPreview()
        setupStreak()
        setupStats()
        setupReminders()
    }

    private func setupHeader() {
        avatarView.image = UIImage(systemName: "person.crop.circle.fill")
        avatarView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 84, weight: .regular)
        avatarView.tintColor = .label
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 42
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

    private func setupMusicPreview() {
        musicPreviewButton.backgroundColor = UIColor(white: 0.15, alpha: 0.7)
        musicPreviewButton.layer.cornerRadius = 14
        musicPreviewButton.layer.cornerCurve = .continuous
        musicPreviewButton.clipsToBounds = true
        musicPreviewButton.addTarget(self, action: #selector(openMusicPlayer), for: .touchUpInside)

        musicPreviewButton.snp.makeConstraints { $0.height.equalTo(44) }

        let noteIcon = UIImageView(image: UIImage(systemName: "music.note"))
        noteIcon.tintColor = .systemBlue
        noteIcon.contentMode = .center
        noteIcon.snp.makeConstraints { $0.size.equalTo(20) }

        let arrowIcon = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrowIcon.tintColor = UIColor(white: 0.5, alpha: 1)
        arrowIcon.contentMode = .center
        arrowIcon.snp.makeConstraints { $0.size.equalTo(12) }

        let label = UILabel()
        label.text = "Добавить песню"
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.tag = 100

        let stack = UIStackView(arrangedSubviews: [noteIcon, label, UIView(), arrowIcon])
        stack.alignment = .center
        stack.spacing = 8
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = .init(top: 0, left: 12, bottom: 0, right: 12)

        musicPreviewButton.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        contentStack.addArrangedSubview(musicPreviewButton)
    }

    private func updateMusicPreview() {
        guard let label = musicPreviewButton.viewWithTag(100) as? UILabel else { return }
        let song = MusicManager.shared.currentSong
        if let song = song {
            label.text = "\(song.title) - \(song.artist)"
        } else {
            label.text = "Добавить песню"
        }
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
        card.isUserInteractionEnabled = true
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openStreakDetails)))
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

    @objc private func openSettings() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let vc = SettingsViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.navigationBar.prefersLargeTitles = true
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func openStreakDetails() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let vc = StreakDiagnosticsViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.navigationBar.prefersLargeTitles = true
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func openMusicPlayer() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let vc = MusicPlayerViewController()
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    @objc private func refresh() {
        let settings = DataManager.shared.settings
        nameField.text = settings.userName
        streakLabel.text = "\(settings.streakDays)"

        statsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let tasks = DataManager.shared.fetchTasks()
        let habits = DataManager.shared.fetchHabits()
        let totalItems = tasks.count + habits.count
        let cleanDays = habits.map(\.cleanDays).max() ?? 0
        let rows = [
            ("Всего заданий", "\(totalItems)"),
            ("Выполнено всего", "\(settings.totalCompletedTasks)"),
            ("Частое упражнение", settings.mostFrequentExercise),
            ("Дней без срыва", "\(cleanDays)"),
        ]
        for (i, row) in rows.enumerated() {
            statsStack.addArrangedSubview(statRow(title: row.0, value: row.1, isLast: i == rows.count - 1))
        }
    }

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
    }

    @objc private func changeAvatar() {
        UIImpactFeedbackGenerator.tap(.light)
        let alert = UIAlertController(title: "Аватар", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Из галереи", style: .default) { [weak self] _ in
            self?.pickFromGallery()
        })
        alert.addAction(UIAlertAction(title: "Из проводника", style: .default) { [weak self] _ in
            self?.pickFromFiles()
        })
        alert.addAction(UIAlertAction(title: "Сбросить", style: .destructive) { [weak self] _ in
            self?.avatarView.image = UIImage(systemName: "person.crop.circle.fill")
            self?.avatarView.contentMode = .center
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.popoverPresentationController?.sourceView = avatarView
        present(alert, animated: true)
    }

    private func pickFromGallery() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func pickFromFiles() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    @objc private func reminderChanged(_ picker: UIDatePicker) {
        let hours = reminderPickers.map { Calendar.current.component(.hour, from: $0.date) }
        DataManager.shared.updateSettings { $0.reminderHours = hours }
        NotificationManager.shared.rescheduleAll()
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

extension ProfileViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                DispatchQueue.main.async {
                    if let img = image as? UIImage {
                        self?.avatarView.image = img
                        self?.avatarView.contentMode = .scaleAspectFill
                    }
                }
            }
        }
    }
}

extension ProfileViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
            avatarView.image = img
            avatarView.contentMode = .scaleAspectFill
        }
    }
}

extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

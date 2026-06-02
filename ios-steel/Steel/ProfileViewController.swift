import UIKit
import SnapKit
import SPIndicator
import PhotosUI

final class ProfileViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let backgroundView = PersonalBackgroundView()

    private let avatarView     = UIImageView()
    private let nameField      = UITextField()
    private let birthdayLabel  = UILabel()
    private let streakLabel    = UILabel()
    private let statsStack = UIStackView()
    private var reminderPickers: [UIDatePicker] = []

    // Sound controls
    private var soundButtonItem: UIBarButtonItem!
    private var soundButtonView: UIButton!
    private var volumePopupView: VolumePopupView?
    private var volumePopupDismissTimer: Timer?
    private var isAdjustingVolume = false  // guard to prevent refresh during drag

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Профиль"
        navigationItem.largeTitleDisplayMode = .always
        setupBackground()
        setupNavigationButtons()
        setup()
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .steelSettingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .steelTasksChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .steelHabitsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadBackground), name: .steelBackgroundChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        backgroundView.apply(BackgroundManager.shared.config)
        backgroundView.resumeVideo()
        loadAvatar()
        refresh()
        updateSoundButton()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backgroundView.pauseVideo()
        hideVolumePopup()
    }

    private func setupBackground() {
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }
        backgroundView.apply(BackgroundManager.shared.config)
    }

    private func setupNavigationButtons() {
        let notifButton = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal"),
                                          style: .plain, target: self, action: #selector(openNotifications))

        // Sound button — tap to toggle mute, long press to adjust volume
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "speaker.slash.fill"), for: .normal)
        btn.tintColor = .label
        btn.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
        btn.addTarget(self, action: #selector(soundButtonTapped), for: .touchUpInside)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(soundButtonLongPressed(_:)))
        longPress.minimumPressDuration = 0.3
        btn.addGestureRecognizer(longPress)

        soundButtonView = btn
        soundButtonItem = UIBarButtonItem(customView: btn)

        navigationItem.leftBarButtonItem  = notifButton
        navigationItem.rightBarButtonItem = soundButtonItem
    }

    @objc private func openNotifications() {
        let vc = NotificationsCenterViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
        present(nav, animated: true)
    }

    // MARK: - Sound Control

    private func updateSoundButton() {
        let isVideo = backgroundView.currentKind == .video
        soundButtonItem.isVisible = isVideo

        guard isVideo else { return }

        let muted = backgroundView.isMuted
        let volume = backgroundView.volume

        if muted || volume == 0 {
            soundButtonView.setImage(UIImage(systemName: "speaker.slash.fill"), for: .normal)
        } else if volume < 0.33 {
            soundButtonView.setImage(UIImage(systemName: "speaker.wave.1.fill"), for: .normal)
        } else if volume < 0.66 {
            soundButtonView.setImage(UIImage(systemName: "speaker.wave.2.fill"), for: .normal)
        } else {
            soundButtonView.setImage(UIImage(systemName: "speaker.wave.3.fill"), for: .normal)
        }
    }

    @objc private func soundButtonTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        backgroundView.toggleMuted(animated: true)
        updateSoundButton()
    }

    @objc private func soundButtonLongPressed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            isAdjustingVolume = true
            showVolumePopup()
            // Cancel the touchUpInside to avoid triggering toggle
            soundButtonView.isHighlighted = false

        case .changed:
            guard let popup = volumePopupView else { return }
            // Use popup's track area for position calculation
            let location = gesture.location(in: popup.trackArea)
            let trackHeight = popup.trackArea.bounds.height
            guard trackHeight > 0 else { return }
            let ratio = max(0, min(1, 1 - location.y / trackHeight))
            let newVolume = Float(ratio)

            // ONLY update player volume directly — NO settings save during drag
            backgroundView.setPlayerVolume(newVolume)
            popup.updateVolume(newVolume)
            updateSoundButton()

        case .ended, .cancelled:
            // Save settings once when gesture finishes
            backgroundView.saveVolumeSettings()
            isAdjustingVolume = false
            scheduleVolumePopupDismiss()

        default:
            break
        }
    }

    private func showVolumePopup() {
        hideVolumePopup()

        guard let soundBtnView = soundButtonItem.customView else { return }
        let btnFrameInView = soundBtnView.convert(soundBtnView.bounds, to: view)

        let popup = VolumePopupView(initialVolume: backgroundView.volume)
        popup.onVolumeChange = { [weak self] vol in
            guard let self else { return }
            // ONLY update player volume — no settings save during drag
            self.backgroundView.setPlayerVolume(vol)
            self.updateSoundButton()
        }
        popup.onVolumeChangeEnded = { [weak self] in
            // Save settings when drag in popup ends
            self?.backgroundView.saveVolumeSettings()
        }
        view.addSubview(popup)
        popup.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(8)
            $0.top.equalTo(btnFrameInView.minY + btnFrameInView.height + 4)
            $0.width.equalTo(52)
            $0.height.equalTo(200)
        }
        // Force layout so popup has correct bounds before .changed events
        view.layoutIfNeeded()
        popup.layoutIfNeeded()

        volumePopupView = popup
        scheduleVolumePopupDismiss()
    }

    private func hideVolumePopup() {
        volumePopupView?.removeFromSuperview()
        volumePopupView = nil
        volumePopupDismissTimer?.invalidate()
        volumePopupDismissTimer = nil
    }

    private func scheduleVolumePopupDismiss() {
        volumePopupDismissTimer?.invalidate()
        volumePopupDismissTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            self?.hideVolumePopup()
        }
    }

    // MARK: - Setup

    private func setup() {
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        scrollView.alwaysBounceVertical = true
        scrollView.delaysContentTouches = false

        contentStack.axis = .vertical
        contentStack.spacing = 24
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(8)
            $0.leading.trailing.equalTo(view).inset(20)
            $0.bottom.equalToSuperview().inset(40)
            $0.width.equalTo(view).inset(20)
        }

        setupHeaderSection()
        setupStreak()
        setupStats()
        setupReminders()
    }

    private func setupHeaderSection() {
        avatarView.image = UIImage(systemName: "person.crop.circle.fill")
        avatarView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 84, weight: .regular)
        avatarView.tintColor = .label
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 42
        avatarView.layer.borderWidth = 0
        avatarView.isUserInteractionEnabled = true
        avatarView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(changeAvatar)))
        avatarView.snp.makeConstraints { $0.size.equalTo(84) }

        nameField.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        nameField.textColor = .label
        nameField.textAlignment = .center
        nameField.borderStyle = .none
        nameField.returnKeyType = .done
        nameField.delegate = self

        birthdayLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        birthdayLabel.textColor = .secondaryLabel
        birthdayLabel.textAlignment = .center
        birthdayLabel.isHidden = true

        let header = UIStackView(arrangedSubviews: [avatarView, nameField, birthdayLabel])
        header.axis = .vertical
        header.alignment = .center
        header.spacing = 4
        header.setCustomSpacing(8, after: avatarView)
        contentStack.addArrangedSubview(header)
    }


    private func setupStreak() {
        let card = makeLiquidGlassCard()
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
        let card = makeLiquidGlassCard()
        statsStack.axis = .vertical
        statsStack.spacing = 0
        card.contentView.addSubview(statsStack)
        statsStack.snp.makeConstraints { $0.edges.equalToSuperview() }
        contentStack.addArrangedSubview(card)
    }

    private func setupReminders() {
        let title = sectionTitle("НАПОМИНАНИЯ")
        contentStack.addArrangedSubview(title)

        let card = makeLiquidGlassCard()
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

    private func makeLiquidGlassCard() -> UIVisualEffectView {
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        card.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.5)
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
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

    private func refreshBirthdayLabel(birthdayString: String) {
        guard !birthdayString.isEmpty else { birthdayLabel.isHidden = true; return }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let bdate = fmt.date(from: birthdayString) else { birthdayLabel.isHidden = true; return }

        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let bMonth = cal.component(.month, from: bdate)
        let bDay   = cal.component(.day,   from: bdate)
        let bYear  = cal.component(.year,  from: bdate)

        var nextComps   = DateComponents()
        nextComps.month = bMonth; nextComps.day = bDay
        var nextBday    = cal.nextDate(after: today, matching: nextComps, matchingPolicy: .nextTime) ?? today
        if cal.isDate(today, equalTo: nextBday, toGranularity: .day) { nextBday = today }

        let days = cal.dateComponents([.day], from: today, to: nextBday).day ?? 0

        let russianMonths = ["","января","февраля","марта","апреля","мая","июня",
                             "июля","августа","сентября","октября","ноября","декабря"]
        let monthName = bMonth < russianMonths.count ? russianMonths[bMonth] : ""
        let dateStr = "\(bDay) \(monthName) \(bYear)"

        if days == 0 {
            birthdayLabel.text = "Сегодня твой день рождения! (\(dateStr))"
        } else {
            birthdayLabel.text = "осталось \(days) дн. (\(dateStr))"
        }
        birthdayLabel.isHidden = false
    }

    @objc private func refresh() {
        // Skip refresh during volume adjustment to prevent crash
        guard !isAdjustingVolume else { return }

        let settings = DataManager.shared.settings
        nameField.text = settings.userName
        streakLabel.text = "\(settings.streakDays)"
        refreshBirthdayLabel(birthdayString: settings.birthdayDateString)

        statsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let rows = [
            ("Выполнено дней", "\(settings.streakDays)"),
            ("Всего выполнено", "\(settings.totalCompletedTasks)"),
            ("Частое упражнение", settings.mostFrequentExercise),
        ]
        for (i, row) in rows.enumerated() {
            statsStack.addArrangedSubview(statRow(title: row.0, value: row.1, isLast: i == rows.count - 1))
        }
    }

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
        updateSoundButton()
    }

    private func loadAvatar() {
        if let avatarData = KeychainHelper.savedAvatarData,
           let img = UIImage(data: avatarData) {
            avatarView.image = img
            avatarView.contentMode = .scaleAspectFill
            return
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let avatarURL = docs.appendingPathComponent("avatar.jpg")
        if let data = try? Data(contentsOf: avatarURL),
           let img = UIImage(data: data) {
            avatarView.image = img
            avatarView.contentMode = .scaleAspectFill
            return
        }
        avatarView.image = UIImage(systemName: "person.crop.circle.fill")
        avatarView.contentMode = .center
    }

    private func saveAvatar(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.85) {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let avatarURL = docs.appendingPathComponent("avatar.jpg")
            try? data.write(to: avatarURL, options: .atomic)
            KeychainHelper.saveAvatarToKeychain(data)
        }
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
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let avatarURL = docs.appendingPathComponent("avatar.jpg")
            try? FileManager.default.removeItem(at: avatarURL)
            KeychainHelper.clearAvatarFromKeychain()
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

// MARK: - Volume Popup View

private final class VolumePopupView: UIView {
    private let fillView = UIView()
    private let thumbView = UIView()
    private let percentLabel = UILabel()
    private var fillHeight: Constraint?

    /// Expose track area for gesture coordinate calculation
    private(set) var trackArea = UIView()

    var onVolumeChange: ((Float) -> Void)?
    var onVolumeChangeEnded: (() -> Void)?

    init(initialVolume: Float) {
        super.init(frame: .zero)
        setup(initialVolume: initialVolume)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(initialVolume: Float) {
        backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.9)
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        clipsToBounds = true
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor

        // Track (background)
        trackArea.backgroundColor = UIColor.systemFill
        trackArea.layer.cornerRadius = 6
        addSubview(trackArea)
        trackArea.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(14)
            $0.top.equalToSuperview().inset(28)
            $0.bottom.equalToSuperview().inset(36)
        }

        // Fill (filled portion from bottom)
        fillView.backgroundColor = .systemBlue
        fillView.layer.cornerRadius = 6
        trackArea.addSubview(fillView)
        fillView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            fillHeight = $0.height.equalTo(0).constraint
        }

        // Thumb indicator
        thumbView.backgroundColor = .white
        thumbView.layer.cornerRadius = 8
        thumbView.layer.shadowColor = UIColor.black.cgColor
        thumbView.layer.shadowOpacity = 0.3
        thumbView.layer.shadowOffset = CGSize(width: 0, height: 1)
        thumbView.layer.shadowRadius = 2
        addSubview(thumbView)
        thumbView.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.size.equalTo(16)
        }

        // Percentage label
        percentLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        percentLabel.textColor = .label
        percentLabel.textAlignment = .center
        addSubview(percentLabel)
        percentLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().inset(10)
        }

        // Pan gesture for dragging inside popup
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)

        // Tap gesture for direct position
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)

        // Set initial volume after layout
        DispatchQueue.main.async { [weak self] in
            self?.updateVolume(initialVolume)
        }
    }

    func updateVolume(_ volume: Float) {
        let clamped = max(0, min(1, volume))
        let trackHeight = trackArea.bounds.height
        guard trackHeight > 0 else { return }

        fillHeight?.update(offset: trackHeight * CGFloat(clamped))
        layoutIfNeeded()

        // Position thumb at top of fill
        let thumbY = trackArea.frame.minY + trackHeight * (1 - CGFloat(clamped)) - 8
        thumbView.snp.remakeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalTo(thumbY)
            $0.size.equalTo(16)
        }

        percentLabel.text = "\(Int(clamped * 100))%"
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: trackArea)
        let trackHeight = trackArea.bounds.height
        guard trackHeight > 0 else { return }
        let ratio = max(0, min(1, 1 - location.y / trackHeight))
        let newVolume = Float(ratio)
        updateVolume(newVolume)
        onVolumeChange?(newVolume)

        if gesture.state == .ended || gesture.state == .cancelled {
            onVolumeChangeEnded?()
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: trackArea)
        let trackHeight = trackArea.bounds.height
        guard trackHeight > 0 else { return }
        let ratio = max(0, min(1, 1 - location.y / trackHeight))
        let newVolume = Float(ratio)
        updateVolume(newVolume)
        onVolumeChange?(newVolume)
        onVolumeChangeEnded?()
    }
}

// MARK: - UIBarButtonItem visibility

extension UIBarButtonItem {
    var isVisible: Bool {
        get { !isHidden }
        set { isHidden = !newValue }
    }

    var isHidden: Bool {
        get { objc_getAssociatedObject(self, &BarItemAssocKeys.isHidden) as? Bool ?? false }
        set {
            objc_setAssociatedObject(self, &BarItemAssocKeys.isHidden, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            tintColor = newValue ? .clear : nil
            isEnabled = !newValue
            (customView as? UIButton)?.isUserInteractionEnabled = !newValue
        }
    }
}

private struct BarItemAssocKeys {
    nonisolated(unsafe) static var isHidden: UInt8 = 0
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
                        self?.saveAvatar(img)
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
            saveAvatar(img)
        }
    }
}

extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

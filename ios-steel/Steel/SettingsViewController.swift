import UIKit
import SnapKit
import SPIndicator

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
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let appearance = makeCategoryRow(title: "Оформление", subtitle: "Фон, шрифт", icon: "paintbrush.pointed.fill", iconBg: .systemIndigo) { [weak self] in
            self?.openAppearance()
        }
        let music = makeCategoryRow(title: "Музыка", subtitle: "Песни для профиля", icon: "headphones", iconBg: .systemPink) { [weak self] in
            self?.openMusicSettings()
        }
        let providers = makeCategoryRow(title: "Провайдеры", subtitle: "Groq, Gemini", icon: "server.rack", iconBg: .systemTeal) { [weak self] in
            self?.openProviders()
        }
        let region = makeCategoryRow(title: "Регион", subtitle: currentRegionSubtitle(), icon: "globe", iconBg: .systemBlue) { [weak self] in
            self?.openRegionPicker()
        }
        let streak = makeCategoryRow(title: "Серия", subtitle: "Пауза серии", icon: "flame.fill", iconBg: .systemOrange) { [weak self] in
            self?.openStreakSettings()
        }

        let items: [UIView] = [appearance, separator(), music, separator(), providers, separator(), region, separator(), streak]
        for item in items {
            stack.addArrangedSubview(item)
        }

        contentStack.addArrangedSubview(card)
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

    private func openMusicSettings() {
        let vc = MusicSettingsViewController()
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

    private func makeCategoryRow(title: String, subtitle: String, icon: String, iconBg: UIColor, action: @escaping () -> Void) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .white
        iconView.contentMode = .center
        iconView.layer.cornerRadius = 8
        iconView.layer.cornerCurve = .continuous
        iconView.backgroundColor = iconBg
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

// MARK: - MusicSettingsViewController
final class MusicSettingsViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let backgroundView = PersonalBackgroundView()

    private var tableView = UITableView()
    private var songs: [SongItem] { MusicManager.shared.songs }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Музыка"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
        setup()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadBackground), name: .steelBackgroundChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
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

        let addCard = makeCard()
        let addStack = UIStackView()
        addStack.axis = .vertical
        addStack.spacing = 0
        addCard.contentView.addSubview(addStack)
        addStack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let addRow = makeActionRow(title: "Добавить песню", subtitle: "Из проводника", icon: "plus.circle.fill") { [weak self] in
            self?.addSong()
        }
        addStack.addArrangedSubview(addRow)
        contentStack.addArrangedSubview(addCard)

        let songsCard = makeCard()
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.isScrollEnabled = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MusicSettingsSongCell.self, forCellReuseIdentifier: MusicSettingsSongCell.reuseID)

        songsCard.contentView.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }

        contentStack.addArrangedSubview(songsCard)
        updateTableHeight()
    }

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
    }

    private func updateTableHeight() {
        tableView.snp.updateConstraints { make in
            make.edges.equalToSuperview()
        }
        tableView.layoutIfNeeded()
        let height = max(CGFloat(songs.count) * 64, 64)
        tableView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(height)
        }
    }

    private func addSong() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
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

    private func makeActionRow(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .systemBlue
        iconView.contentMode = .center
        iconView.snp.makeConstraints { $0.size.equalTo(28) }

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        titleLabel.textColor = .label

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [iconView, textStack])
        row.alignment = .center
        row.spacing = 12
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = .init(top: 14, left: 16, bottom: 14, right: 16)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleActionTap(_:)))
        row.addGestureRecognizer(tap)
        row.isUserInteractionEnabled = true
        objc_setAssociatedObject(row, "action", action, .OBJC_ASSOCIATION_COPY_NONATOMIC)

        return row
    }

    @objc private func handleActionTap(_ gesture: UITapGestureRecognizer) {
        guard let action = objc_getAssociatedObject(gesture.view, "action") as? () -> Void else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        action()
    }
}

extension MusicSettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        songs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MusicSettingsSongCell.reuseID, for: indexPath) as! MusicSettingsSongCell
        let song = songs[indexPath.row]
        cell.configure(with: song)
        cell.onDelete = { [weak self] in
            MusicManager.shared.removeSong(at: indexPath.row)
            self?.tableView.reloadData()
            self?.updateTableHeight()
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        64
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        MusicManager.shared.play(at: indexPath.row)
    }
}

extension MusicSettingsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let title = url.deletingPathExtension().lastPathComponent
            MusicManager.shared.addSong(from: url, title: title, artist: "Неизвестен")
        }
        tableView.reloadData()
        updateTableHeight()
        SPIndicator.present(title: "Песни добавлены", preset: .done, haptic: .success)
    }
}

// MARK: - MusicSettingsSongCell
private final class MusicSettingsSongCell: UITableViewCell {
    static let reuseID = "MusicSettingsSongCell"
    var onDelete: (() -> Void)?

    private let artworkView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let deleteButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        artworkView.contentMode = .scaleAspectFill
        artworkView.clipsToBounds = true
        artworkView.layer.cornerRadius = 8
        artworkView.layer.cornerCurve = .continuous
        artworkView.backgroundColor = .tertiarySystemFill
        artworkView.image = UIImage(systemName: "music.note")
        artworkView.tintColor = .secondaryLabel
        artworkView.snp.makeConstraints { $0.size.equalTo(44) }

        titleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        titleLabel.textColor = .label
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.lineBreakMode = .byTruncatingTail

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.tintColor = .systemRed
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [artworkView, textStack, UIView(), deleteButton])
        stack.alignment = .center
        stack.spacing = 12
        contentView.addSubview(stack)
        stack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.top.bottom.equalToSuperview().inset(8)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with song: SongItem) {
        titleLabel.text = song.title
        subtitleLabel.text = song.artist
        if let art = song.artwork {
            artworkView.image = art
        } else {
            artworkView.image = UIImage(systemName: "music.note")
            artworkView.tintColor = .secondaryLabel
        }
    }

    @objc private func deleteTapped() { onDelete?() }
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
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 18
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        return card
    }
}

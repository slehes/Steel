import UIKit
import SnapKit
import SPIndicator
import UniformTypeIdentifiers

final class AppearanceViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let backgroundView = PersonalBackgroundView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Оформление"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        setup()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshFont), name: .steelFontChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshBackground), name: .steelBackgroundChanged, object: nil)
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

        setupBackgroundSection()
        setupFontSection()
    }

    private func setupBackgroundSection() {
        let title = sectionTitle("ФОН ЭКРАНА")
        contentStack.addArrangedSubview(title)

        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let choose = makeRowButton(title: "Выбрать фото или видео", icon: "photo.on.rectangle.angled", action: #selector(chooseBackground))
        let dimToggleRow = makeDimRow()
        let disable = makeRowButton(title: "Отключить фон", icon: "xmark.circle", action: #selector(disableBackground), destructive: true)

        stack.addArrangedSubviews([choose, separator(), dimToggleRow, separator(), disable])
        contentStack.addArrangedSubview(card)
    }

    private func setupFontSection() {
        let title = sectionTitle("ШРИФТ")
        contentStack.addArrangedSubview(title)

        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let addFont = makeRowButton(title: "Загрузить шрифт", icon: "doc.text.magnifyingglass", action: #selector(pickFont))
        let currentFontRow = makeCurrentFontRow()
        let removeFont = makeRowButton(title: "Вернуть системный шрифт", icon: "textformat", action: #selector(removeFont), destructive: true)

        stack.addArrangedSubviews([addFont, separator(), currentFontRow, separator(), removeFont])
        contentStack.addArrangedSubview(card)
    }

    private func makeCurrentFontRow() -> UIView {
        let label = UILabel()
        label.text = "Текущий шрифт"
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = .label

        let valueLabel = UILabel()
        valueLabel.text = FontManager.shared.currentDisplayName
        valueLabel.font = UIFont.preferredFont(forTextStyle: .body).withWeight(.semibold)
        valueLabel.textColor = .secondaryLabel
        valueLabel.textAlignment = .right
        valueLabel.tag = 200

        let row = UIStackView(arrangedSubviews: [label, UIView(), valueLabel])
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = .init(top: 14, left: 16, bottom: 14, right: 16)
        return row
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

    @objc private func pickFont() {
        let ttfType = UTType("public.ttf") ?? UTType.font
        let otfType = UTType("public.opentype-font") ?? UTType.font
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.font, ttfType, otfType], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    @objc private func removeFont() {
        FontManager.shared.removeCustomFont()
        SPIndicator.present(title: "Системный шрифт", preset: .done, haptic: .success)
        let alert = UIAlertController(title: "Шрифт сброшен", message: "Перезапустите приложение для применения системного шрифта.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func refreshFont() {
        if let valueLabel = view.viewWithTag(200) as? UILabel {
            valueLabel.text = FontManager.shared.currentDisplayName
        }
    }

    @objc private func refreshBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
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
}

extension AppearanceViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }

        let alert = UIAlertController(title: "Название шрифта", message: "Введите имя для этого шрифта", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Мой шрифт"
            tf.text = url.deletingPathExtension().lastPathComponent
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Применить", style: .default) { [weak self] _ in
            let displayName = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? "Кастомный"
            guard let self else { return }
            let success = FontManager.shared.installFont(from: url, displayName: displayName)
            if success {
                SPIndicator.present(title: "Шрифт установлен", preset: .done, haptic: .success)
                let restart = UIAlertController(title: "Шрифт применён", message: "Перезапустите приложение для полного применения шрифта ко всем элементам.", preferredStyle: .alert)
                restart.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(restart, animated: true)
            } else {
                SPIndicator.present(title: "Ошибка шрифта", preset: .error, haptic: .error)
            }
        })
        present(alert, animated: true)
    }
}

private extension UIStackView {
    func addArrangedSubviews(_ views: [UIView]) {
        views.forEach { addArrangedSubview($0) }
    }
}

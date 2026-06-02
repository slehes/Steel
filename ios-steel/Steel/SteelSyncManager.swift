import Foundation
import UIKit
import SwiftData
import SnapKit
import SPIndicator

@MainActor
final class SteelSyncManager {
    static let shared = SteelSyncManager()

    @discardableResult
    func exportToClipboard() -> Bool {
        let payload = buildPayload()
        guard let data = try? JSONEncoder().encode(payload) else { return false }
        UIPasteboard.general.string = data.base64EncodedString()
        return true
    }

    @discardableResult
    func importFromString(_ input: String) -> Bool {
        let clean = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty,
              let data = Data(base64Encoded: clean),
              let payload = try? JSONDecoder().decode(SyncPayload.self, from: data) else { return false }

        DataManager.shared.fetchHabits().forEach { DataManager.shared.context.delete($0) }
        DataManager.shared.fetchTasks().forEach { DataManager.shared.context.delete($0) }
        try? DataManager.shared.context.save()

        payload.habits.forEach { DataManager.shared.addHabitFromDTO($0) }
        payload.tasks.forEach { DataManager.shared.addTaskFromDTO($0) }

        DataManager.shared.updateSettings {
            $0.streakDays = payload.streakDays
            $0.userName = payload.userName
            $0.totalCompletedTasks = payload.totalCompletedTasks
        }

        KeychainHelper.backupAllData()
        NotificationCenter.default.post(name: .steelHabitsChanged, object: nil)
        NotificationCenter.default.post(name: .steelTasksChanged, object: nil)
        return true
    }

    func buildPayload() -> SyncPayload {
        let habits = DataManager.shared.fetchHabits().map { HabitDTO(from: $0) }
        let tasks  = DataManager.shared.fetchTasks().map { TaskDTO(from: $0) }
        let s = DataManager.shared.settings
        return SyncPayload(
            habits: habits,
            tasks: tasks,
            streakDays: s.streakDays,
            userName: s.userName,
            totalCompletedTasks: s.totalCompletedTasks,
            lastSync: Date().timeIntervalSince1970
        )
    }

    struct SyncPayload: Codable {
        var habits: [HabitDTO]
        var tasks: [TaskDTO]
        var streakDays: Int
        var userName: String
        var totalCompletedTasks: Int
        var lastSync: Double
    }
}

final class SyncViewController: UIViewController {
    private let scrollView  = UIScrollView()
    private let contentStack = UIStackView()
    private let backgroundView = PersonalBackgroundView()

    private weak var importField: UITextView?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Резервная копия"
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

        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .onDrag
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }

        contentStack.axis = .vertical
        contentStack.spacing = 20
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.leading.trailing.equalTo(view).inset(20)
            $0.bottom.equalToSuperview().inset(40)
        }

        buildUUIDCard()
        buildExportCard()
        buildImportCard()
        buildInfoCard()
    }

    private func buildUUIDCard() {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let caption = UILabel()
        caption.text = "Ваш UUID"
        caption.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        caption.textColor = .secondaryLabel
        stack.addArrangedSubview(caption)

        let uuidLabel = UILabel()
        uuidLabel.text = KeychainHelper.formattedUserID
        uuidLabel.font = UIFont.monospacedSystemFont(ofSize: 20, weight: .bold)
        uuidLabel.textColor = .label
        uuidLabel.isUserInteractionEnabled = true
        uuidLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyUUID)))
        stack.addArrangedSubview(uuidLabel)

        let hint = UILabel()
        hint.text = "Нажмите, чтобы скопировать"
        hint.font = UIFont.systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabel
        stack.addArrangedSubview(hint)

        contentStack.addArrangedSubview(card)
    }

    private func buildExportCard() {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        stack.addArrangedSubview(makeSectionHeader(icon: "arrow.up.doc.fill", iconColor: .systemBlue, title: "Создать копию"))
        stack.addArrangedSubview(makeSeparator())

        let desc = makeDescLabel("Все привычки, задачи и серии будут скопированы в буфер обмена.\nВставьте строку в заметки или мессенджер — она понадобится для восстановления.")
        stack.addArrangedSubview(desc)
        stack.addArrangedSubview(makeSeparator())

        stack.addArrangedSubview(makeActionRow(
            icon: "doc.on.clipboard.fill",
            iconColor: .systemBlue,
            title: "Скопировать резервную копию"
        ) { [weak self] in self?.doExport() })

        contentStack.addArrangedSubview(card)
    }

    private func buildImportCard() {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        stack.addArrangedSubview(makeSectionHeader(icon: "arrow.down.doc.fill", iconColor: .systemGreen, title: "Восстановить из копии"))
        stack.addArrangedSubview(makeSeparator())

        let fieldContainer = UIView()
        let textView = UITextView()
        textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .label
        textView.backgroundColor = .clear
        textView.layer.cornerRadius = 10
        textView.layer.cornerCurve = .continuous
        textView.isScrollEnabled = false
        textView.text = "Вставьте строку резервной копии сюда..."
        textView.textColor = .placeholderText
        textView.delegate = self
        fieldContainer.addSubview(textView)
        textView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
            $0.height.greaterThanOrEqualTo(64)
        }
        importField = textView
        stack.addArrangedSubview(fieldContainer)
        stack.addArrangedSubview(makeSeparator())

        stack.addArrangedSubview(makeActionRow(
            icon: "clipboard",
            iconColor: .systemTeal,
            title: "Вставить из буфера"
        ) { [weak self] in
            guard let tv = self?.importField else { return }
            if let s = UIPasteboard.general.string, !s.isEmpty {
                tv.text = s
                tv.textColor = .label
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        })
        stack.addArrangedSubview(makeSeparator())

        stack.addArrangedSubview(makeActionRow(
            icon: "arrow.triangle.2.circlepath",
            iconColor: .systemGreen,
            title: "Восстановить данные"
        ) { [weak self] in self?.doImport() })

        contentStack.addArrangedSubview(card)
    }

    private func buildInfoCard() {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        for (icon, text) in [
            ("checkmark.shield.fill", "Данные в Keychain не удалятся при переустановке приложения на том же устройстве"),
            ("iphone.and.arrow.forward", "Для переноса на новый телефон — создайте копию, затем вставьте её на новом устройстве"),
            ("lock.fill", "Строка копии содержит все ваши данные — храните её в надёжном месте"),
        ] as [(String, String)] {
            let row = makeInfoRow(icon: icon, text: text)
            stack.addArrangedSubview(row)
        }
        contentStack.addArrangedSubview(card)
    }

    @objc private func copyUUID() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UIPasteboard.general.string = KeychainHelper.formattedUserID
        SPIndicator.present(title: "UUID скопирован", preset: .done, haptic: .success)
    }

    private func doExport() {
        let ok = SteelSyncManager.shared.exportToClipboard()
        if ok {
            SPIndicator.present(title: "Копия создана", message: "Вставьте куда удобно", preset: .done, haptic: .success)
        } else {
            SPIndicator.present(title: "Ошибка", preset: .error, haptic: .error)
        }
    }

    private func doImport() {
        let text = importField?.text ?? ""
        guard text != "Вставьте строку резервной копии сюда...", !text.isEmpty else {
            SPIndicator.present(title: "Вставьте строку", preset: .error, haptic: .error)
            return
        }

        let alert = UIAlertController(
            title: "Восстановить?",
            message: "Текущие данные будут заменены. Это нельзя отменить.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Восстановить", style: .destructive) { [weak self] _ in
            let ok = SteelSyncManager.shared.importFromString(text)
            if ok {
                SPIndicator.present(title: "Данные восстановлены", preset: .done, haptic: .success)
                self?.importField?.text = "Вставьте строку резервной копии сюда..."
                self?.importField?.textColor = .placeholderText
            } else {
                SPIndicator.present(title: "Неверная строка", preset: .error, haptic: .error)
            }
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
    }

    private func makeSectionHeader(icon: String, iconColor: UIColor, title: String) -> UIView {
        let iconContainer = UIView()
        iconContainer.backgroundColor = iconColor
        iconContainer.layer.cornerRadius = 10
        iconContainer.layer.cornerCurve = .continuous
        iconContainer.snp.makeConstraints { $0.size.equalTo(38) }

        let iconView = UIImageView(image: UIImage(systemName: icon,
                                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)))
        iconView.tintColor = .white
        iconView.contentMode = .center
        iconContainer.addSubview(iconView)
        iconView.snp.makeConstraints { $0.center.equalToSuperview() }

        let label = UILabel()
        label.text = title
        label.font = UIFont.preferredFont(forTextStyle: .body).withWeight(.semibold)
        label.textColor = .label

        let row = UIStackView(arrangedSubviews: [iconContainer, label, UIView()])
        row.alignment = .center
        row.spacing = 14
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        return row
    }

    private func makeActionRow(icon: String, iconColor: UIColor, title: String, action: @escaping () -> Void) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: icon,
                                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)))
        iconView.tintColor = iconColor
        iconView.contentMode = .center
        iconView.snp.makeConstraints { $0.size.equalTo(24) }

        let label = UILabel()
        label.text = title
        label.font = UIFont.preferredFont(forTextStyle: .body).withWeight(.semibold)
        label.textColor = iconColor

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right",
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)))
        chevron.tintColor = .tertiaryLabel

        let row = UIStackView(arrangedSubviews: [iconView, label, UIView(), chevron])
        row.alignment = .center
        row.spacing = 12
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        row.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer()
        tap.addTarget(self, action: #selector(rowTapped(_:)))
        row.addGestureRecognizer(tap)
        objc_setAssociatedObject(row, "action", action, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        return row
    }

    private func makeDescLabel(_ text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0

        let wrap = UIStackView(arrangedSubviews: [label])
        wrap.isLayoutMarginsRelativeArrangement = true
        wrap.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        return wrap
    }

    private func makeInfoRow(icon: String, text: String) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: icon,
                                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 14)))
        iconView.tintColor = .secondaryLabel
        iconView.contentMode = .top
        iconView.snp.makeConstraints { $0.width.equalTo(20) }

        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [iconView, label])
        row.alignment = .top
        row.spacing = 10
        return row
    }

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.backgroundColor = .separator
        v.snp.makeConstraints { $0.height.equalTo(0.5) }
        return v
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

    @objc private func rowTapped(_ gesture: UITapGestureRecognizer) {
        guard let action = objc_getAssociatedObject(gesture.view as Any, "action") as? () -> Void else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        action()
    }
}

extension SyncViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .placeholderText {
            textView.text = ""
            textView.textColor = .label
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "Вставьте строку резервной копии сюда..."
            textView.textColor = .placeholderText
        }
    }
}

import Foundation
import UIKit
import SwiftData
import SnapKit
import SPIndicator

// MARK: - SteelSyncManager
// Облачная синхронизация через Firebase Realtime Database.
// Инструкция:
//   1. Перейдите на firebase.google.com → создайте проект → включите Realtime Database
//   2. В правилах базы данных установите: { "rules": { ".read": true, ".write": true } }
//   3. В приложении: Настройки → Синхронизация → введите ID проекта Firebase

private let kFirebaseProjectIDKey = "steel.firebase.projectId"

@MainActor
final class SteelSyncManager {
    static let shared = SteelSyncManager()

    private(set) var isSyncing = false

    var firebaseProjectID: String {
        get { UserDefaults.standard.string(forKey: kFirebaseProjectIDKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: kFirebaseProjectIDKey) }
    }

    var isConfigured: Bool { !firebaseProjectID.isEmpty }

    private func firebaseURL(for uid: String) -> URL? {
        guard isConfigured else { return nil }
        let safe = uid.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? uid
        return URL(string: "https://\(firebaseProjectID)-default-rtdb.firebaseio.com/steel/\(safe).json")
    }

    // MARK: - Upload

    @discardableResult
    func upload() async -> Bool {
        guard let url = firebaseURL(for: KeychainHelper.userID) else { return false }
        guard !isSyncing else { return false }
        isSyncing = true
        defer { isSyncing = false }

        let payload = buildPayload()
        guard let body = try? JSONEncoder().encode(payload) else { return false }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Restore

    @discardableResult
    func restore(uuid: String) async -> Bool {
        let cleanUUID = uuid.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
        guard cleanUUID.count == 12, let url = firebaseURL(for: cleanUUID) else { return false }
        guard !isSyncing else { return false }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
            guard data != Data("null".utf8) else { return false }

            let payload = try JSONDecoder().decode(SyncPayload.self, from: data)

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

            KeychainHelper.setUserID(cleanUUID)
            KeychainHelper.backupAllData()

            NotificationCenter.default.post(name: .steelHabitsChanged, object: nil)
            NotificationCenter.default.post(name: .steelTasksChanged, object: nil)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Payload

    private func buildPayload() -> SyncPayload {
        let habits = DataManager.shared.fetchHabits().map { HabitDTO(from: $0) }
        let tasks = DataManager.shared.fetchTasks().map { TaskDTO(from: $0) }
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

// MARK: - SyncViewController

final class SyncViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let backgroundView = PersonalBackgroundView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Синхронизация"
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
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        scrollView.alwaysBounceVertical = true

        contentStack.axis = .vertical
        contentStack.spacing = 20
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.leading.trailing.equalTo(view).inset(20)
            $0.bottom.equalToSuperview().inset(40)
        }

        buildUUIDCard()
        buildSyncCard()
        buildFirebaseCard()
        buildRestoreCard()
    }

    // MARK: - UUID Card

    private func buildUUIDCard() {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let headerLabel = UILabel()
        headerLabel.text = "Ваш ID устройства"
        headerLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = .secondaryLabel
        stack.addArrangedSubview(headerLabel)

        let uuidLabel = UILabel()
        uuidLabel.text = KeychainHelper.formattedUserID
        uuidLabel.font = UIFont.monospacedSystemFont(ofSize: 22, weight: .bold)
        uuidLabel.textColor = .label
        uuidLabel.textAlignment = .center
        uuidLabel.isUserInteractionEnabled = true
        uuidLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyUUID)))
        stack.addArrangedSubview(uuidLabel)

        let hintLabel = UILabel()
        hintLabel.text = "Нажмите, чтобы скопировать"
        hintLabel.font = UIFont.systemFont(ofSize: 12)
        hintLabel.textColor = .tertiaryLabel
        stack.addArrangedSubview(hintLabel)

        contentStack.addArrangedSubview(card)
    }

    // MARK: - Sync Card

    private func buildSyncCard() {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let uploadRow = makeActionRow(
            icon: "icloud.and.arrow.up.fill",
            iconColor: .systemBlue,
            title: "Сохранить в облако",
            subtitle: "Загрузить данные по текущему ID"
        ) { [weak self] in self?.uploadData() }

        let sep = UIView()
        sep.backgroundColor = .separator
        sep.snp.makeConstraints { $0.height.equalTo(0.5) }

        let infoRow = makeInfoRow(
            icon: "info.circle.fill",
            iconColor: .systemGray,
            text: "Данные сохраняются на сервере Firebase по вашему UUID"
        )

        stack.addArrangedSubview(uploadRow)
        stack.addArrangedSubview(sep)
        stack.addArrangedSubview(infoRow)

        contentStack.addArrangedSubview(card)
    }

    // MARK: - Firebase Config Card

    private func buildFirebaseCard() {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let headerRow = makeStaticRow(icon: "flame.fill", iconColor: .systemOrange, title: "Firebase проект")

        let sep = UIView()
        sep.backgroundColor = .separator
        sep.snp.makeConstraints { $0.height.equalTo(0.5) }

        let fieldContainer = UIView()

        let textField = UITextField()
        textField.placeholder = "ID проекта (напр. my-app-12345)"
        textField.font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        textField.textColor = .label
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.returnKeyType = .done
        textField.text = SteelSyncManager.shared.firebaseProjectID
        textField.addTarget(self, action: #selector(firebaseIDChanged(_:)), for: .editingDidEndOnExit)
        textField.addTarget(self, action: #selector(firebaseIDChanged(_:)), for: .editingDidEnd)

        fieldContainer.addSubview(textField)
        textField.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        }

        let hint = UILabel()
        hint.text = "  Создайте проект на firebase.google.com → Realtime Database → разрешите read/write  "
        hint.font = UIFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabel
        hint.numberOfLines = 0

        let hintRow = UIStackView(arrangedSubviews: [hint])
        hintRow.isLayoutMarginsRelativeArrangement = true
        hintRow.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 12, right: 16)

        stack.addArrangedSubview(headerRow)
        stack.addArrangedSubview(sep)
        stack.addArrangedSubview(fieldContainer)
        stack.addArrangedSubview(hintRow)

        contentStack.addArrangedSubview(card)
    }

    // MARK: - Restore Card

    private func buildRestoreCard() {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        card.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        let headerRow = makeStaticRow(icon: "arrow.down.circle.fill", iconColor: .systemGreen, title: "Восстановить данные")

        let sep = UIView()
        sep.backgroundColor = .separator
        sep.snp.makeConstraints { $0.height.equalTo(0.5) }

        let fieldContainer = UIView()
        let restoreField = UITextField()
        restoreField.placeholder = "XXXX-XXXX-XXXX или без дефисов"
        restoreField.font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        restoreField.textColor = .label
        restoreField.autocapitalizationType = .allCharacters
        restoreField.autocorrectionType = .no
        restoreField.returnKeyType = .done
        restoreField.tag = 99

        fieldContainer.addSubview(restoreField)
        restoreField.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        }

        let sep2 = UIView()
        sep2.backgroundColor = .separator
        sep2.snp.makeConstraints { $0.height.equalTo(0.5) }

        let restoreRow = makeActionRow(
            icon: "arrow.triangle.2.circlepath",
            iconColor: .systemGreen,
            title: "Восстановить",
            subtitle: "Заменить все данные из облака"
        ) { [weak self, weak restoreField] in
            self?.restoreData(from: restoreField?.text ?? "")
        }

        stack.addArrangedSubview(headerRow)
        stack.addArrangedSubview(sep)
        stack.addArrangedSubview(fieldContainer)
        stack.addArrangedSubview(sep2)
        stack.addArrangedSubview(restoreRow)

        contentStack.addArrangedSubview(card)
    }

    // MARK: - Actions

    @objc private func copyUUID() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UIPasteboard.general.string = KeychainHelper.formattedUserID
        SPIndicator.present(title: "ID скопирован", preset: .done, haptic: .success)
    }

    @objc private func firebaseIDChanged(_ tf: UITextField) {
        SteelSyncManager.shared.firebaseProjectID = tf.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func uploadData() {
        guard SteelSyncManager.shared.isConfigured else {
            SPIndicator.present(title: "Введите ID проекта Firebase", preset: .error, haptic: .error)
            return
        }
        Task {
            let ok = await SteelSyncManager.shared.upload()
            if ok {
                SPIndicator.present(title: "Данные сохранены", preset: .done, haptic: .success)
            } else {
                SPIndicator.present(title: "Ошибка загрузки", preset: .error, haptic: .error)
            }
        }
    }

    private func restoreData(from input: String) {
        guard SteelSyncManager.shared.isConfigured else {
            SPIndicator.present(title: "Введите ID проекта Firebase", preset: .error, haptic: .error)
            return
        }
        guard !input.isEmpty else {
            SPIndicator.present(title: "Введите UUID", preset: .error, haptic: .error)
            return
        }

        let alert = UIAlertController(
            title: "Восстановить данные?",
            message: "Текущие данные будут заменены данными из облака. Это действие нельзя отменить.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Восстановить", style: .destructive) { [weak self] _ in
            self?.performRestore(uuid: input)
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }

    private func performRestore(uuid: String) {
        Task {
            let ok = await SteelSyncManager.shared.restore(uuid: uuid)
            if ok {
                SPIndicator.present(title: "Данные восстановлены", preset: .done, haptic: .success)
            } else {
                SPIndicator.present(title: "UUID не найден", message: "Проверьте ID и проект Firebase", preset: .error, haptic: .error)
            }
        }
    }

    @objc private func reloadBackground() {
        backgroundView.apply(BackgroundManager.shared.config)
    }

    // MARK: - Builders

    private func makeActionRow(icon: String, iconColor: UIColor, title: String, subtitle: String, action: @escaping () -> Void) -> UIView {
        let iconContainer = UIView()
        iconContainer.layer.cornerRadius = 10
        iconContainer.layer.cornerCurve = .continuous
        iconContainer.backgroundColor = iconColor
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

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right",
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
        chevron.tintColor = .tertiaryLabel

        let row = UIStackView(arrangedSubviews: [iconContainer, textStack, UIView(), chevron])
        row.alignment = .center
        row.spacing = 14
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        row.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer()
        tap.addTarget(self, action: #selector(rowTapped(_:)))
        row.addGestureRecognizer(tap)
        objc_setAssociatedObject(row, "action", action, .OBJC_ASSOCIATION_COPY_NONATOMIC)

        return row
    }

    private func makeStaticRow(icon: String, iconColor: UIColor, title: String) -> UIView {
        let iconContainer = UIView()
        iconContainer.layer.cornerRadius = 10
        iconContainer.layer.cornerCurve = .continuous
        iconContainer.backgroundColor = iconColor
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

        let row = UIStackView(arrangedSubviews: [iconContainer, titleLabel, UIView()])
        row.alignment = .center
        row.spacing = 14
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        return row
    }

    private func makeInfoRow(icon: String, iconColor: UIColor, text: String) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)))
        iconView.tintColor = iconColor
        iconView.contentMode = .center
        iconView.snp.makeConstraints { $0.size.equalTo(20) }

        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [iconView, label])
        row.alignment = .top
        row.spacing = 10
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        return row
    }

    @objc private func rowTapped(_ gesture: UITapGestureRecognizer) {
        guard let action = objc_getAssociatedObject(gesture.view, "action") as? () -> Void else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        action()
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

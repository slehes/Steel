import UIKit
import SnapKit
import SPIndicator

private let kBotToken  = "8112616068:AAGR9fsSClI7CViqXNZTFDHk-o8ijWpE-iw"
private let kChatIdKey = "steel.telegram.chatId"
private let kApiBase   = "https://api.telegram.org/bot\(kBotToken)/sendMessage"

@MainActor
final class TelegramManager {
    static let shared = TelegramManager()

    var chatId: String {
        get { UserDefaults.standard.string(forKey: kChatIdKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: kChatIdKey) }
    }

    var isConfigured: Bool { !chatId.trimmingCharacters(in: .whitespaces).isEmpty }

    private func pe(_ id: String, _ fb: String) -> String {
        "<tg-emoji emoji-id=\"\(id)\">\(fb)</tg-emoji>"
    }

    func buildReport(timeLabel: String) -> String {
        let FIRE  = pe("5089479191414440704", "🔥")
        let BOLT  = pe("5172425562634847208", "⚡️")
        let CHECK = pe("5870633910337015697", "✅")
        let CROSS = pe("5870657884844462243", "❌")
        let GRAPH = pe("5870930636742595124", "📊")

        let habits  = DataManager.shared.fetchHabits()
        let tasks   = DataManager.shared.fetchTasks()
        let streak  = DataManager.shared.settings.streakDays
        let user    = DataManager.shared.settings.userName

        let fmt = DateFormatter()
        fmt.dateFormat = "dd.MM.yyyy"
        fmt.locale = Locale(identifier: "ru_RU")
        let dateStr = fmt.string(from: Date())

        var lines: [String] = []
        lines.append("\(BOLT) <b>Steel — Отчёт \(timeLabel)</b>")
        lines.append("<i>\(dateStr) · \(user)</i>")
        lines.append("")
        lines.append("\(FIRE) <b>Серия: \(ruDays(streak))</b>")

        let completedTasks = tasks.filter { $0.isCompleted }
        if !tasks.isEmpty {
            lines.append("")
            lines.append("\(BOLT) <b>Зарядка:</b>")
            for t in tasks {
                let done = t.isCompleted ? CHECK : "⬜️"
                lines.append("  \(done) \(t.title)/\(t.amount) \(t.unit)  \(BOLT)\(t.amount)  \(FIRE)\(t.amount)")
            }
        }

        let bad = habits.filter { $0.category == .bad }
        if !bad.isEmpty {
            lines.append("")
            lines.append("\(CROSS) <b>Вредные привычки:</b>")
            for h in bad {
                let d = h.cleanDays
                lines.append("  \(CHECK) \(h.title)  \(BOLT)\(ruDays(d))  \(FIRE)\(ruDays(d))")
            }
        }

        let good = habits.filter { $0.category == .good }
        if !good.isEmpty {
            lines.append("")
            lines.append("\(CHECK) <b>Полезные привычки:</b>")
            for h in good {
                let d = h.cleanDays
                lines.append("  \(CHECK) \(h.title)  \(BOLT)\(ruDays(d))  \(FIRE)\(ruDays(d))")
            }
        }

        lines.append("")
        lines.append("\(GRAPH) <b>Так держать!</b>")
        return lines.joined(separator: "\n")
    }

    @discardableResult
    func sendReport(timeLabel: String) async -> Bool {
        guard isConfigured else { return false }
        let text = buildReport(timeLabel: timeLabel)
        return await send(text: text)
    }

    @discardableResult
    func send(text: String) async -> Bool {
        guard isConfigured, let url = URL(string: kApiBase) else { return false }
        let body: [String: Any] = [
            "chat_id": chatId,
            "text": text,
            "parse_mode": "HTML"
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return false }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func ruDays(_ n: Int) -> String {
        let l2 = n % 100, l1 = n % 10
        if l2 >= 11 && l2 <= 19 { return "\(n) дней" }
        if l1 == 1 { return "\(n) день" }
        if l1 >= 2 && l1 <= 4 { return "\(n) дня" }
        return "\(n) дней"
    }
}

final class TelegramSettingsViewController: UIViewController {
    private let backgroundView = PersonalBackgroundView()
    private weak var chatIdField: UITextField?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Telegram"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
        setup()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadBg),
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
        saveChatId()
    }

    private func setup() {
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        let scroll = UIScrollView()
        scroll.backgroundColor = .clear
        scroll.alwaysBounceVertical = true
        view.addSubview(scroll)
        scroll.snp.makeConstraints { $0.edges.equalToSuperview() }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        scroll.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.leading.trailing.equalTo(view).inset(16)
            $0.bottom.equalToSuperview().inset(40)
        }

        stack.addArrangedSubview(makeChatIdCard())
        stack.addArrangedSubview(makeHowToCard())
        stack.addArrangedSubview(makeSendCard())
    }

    private func makeChatIdCard() -> UIView {
        let card = makeCard()
        let inner = UIStackView()
        inner.axis = .vertical
        inner.spacing = 0
        card.contentView.addSubview(inner)
        inner.snp.makeConstraints { $0.edges.equalToSuperview() }

        let headerRow = UIStackView()
        headerRow.alignment = .center
        headerRow.spacing = 12
        headerRow.isLayoutMarginsRelativeArrangement = true
        headerRow.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)

        let iconWrap = UIView()
        iconWrap.backgroundColor = UIColor(red: 0.17, green: 0.56, blue: 0.90, alpha: 1)
        iconWrap.layer.cornerRadius = 9
        iconWrap.layer.cornerCurve = .continuous
        iconWrap.snp.makeConstraints { $0.size.equalTo(34) }

        let iconImg = UIImageView(image: UIImage(systemName: "paperplane.fill",
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)))
        iconImg.tintColor = .white
        iconImg.contentMode = .center
        iconWrap.addSubview(iconImg)
        iconImg.snp.makeConstraints { $0.center.equalToSuperview() }

        let titleLbl = UILabel()
        titleLbl.text = "Chat ID"
        titleLbl.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        titleLbl.textColor = .label

        headerRow.addArrangedSubview(iconWrap)
        headerRow.addArrangedSubview(titleLbl)
        inner.addArrangedSubview(headerRow)

        let sep = UIView()
        sep.backgroundColor = UIColor.separator.withAlphaComponent(0.35)
        sep.snp.makeConstraints { $0.height.equalTo(0.5) }
        inner.addArrangedSubview(sep)

        let fieldWrap = UIView()
        let field = UITextField()
        field.placeholder = "Введите ваш Telegram Chat ID"
        field.font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        field.textColor = .label
        field.keyboardType = .numberPad
        field.text = TelegramManager.shared.chatId
        field.addTarget(self, action: #selector(chatIdChanged(_:)), for: .editingChanged)
        fieldWrap.addSubview(field)
        field.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        }
        inner.addArrangedSubview(fieldWrap)
        chatIdField = field

        return card
    }

    private func makeHowToCard() -> UIView {
        let card = makeCard()
        let inner = UIStackView()
        inner.axis = .vertical
        inner.spacing = 8
        inner.isLayoutMarginsRelativeArrangement = true
        inner.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        card.contentView.addSubview(inner)
        inner.snp.makeConstraints { $0.edges.equalToSuperview() }

        let title = UILabel()
        title.text = "Как узнать Chat ID"
        title.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .label
        inner.addArrangedSubview(title)

        let steps = [
            "1. Напиши /start боту в Telegram",
            "2. Бот покажет твой Chat ID",
            "3. Скопируй и вставь сюда",
        ]
        for step in steps {
            let lbl = UILabel()
            lbl.text = step
            lbl.font = UIFont.systemFont(ofSize: 13)
            lbl.textColor = .secondaryLabel
            lbl.numberOfLines = 0
            inner.addArrangedSubview(lbl)
        }

        return card
    }

    private func makeSendCard() -> UIView {
        let card = makeCard()
        let inner = UIStackView()
        inner.axis = .vertical
        inner.spacing = 0
        card.contentView.addSubview(inner)
        inner.snp.makeConstraints { $0.edges.equalToSuperview() }

        let sendRow = makeActionRow(
            icon: "paperplane.fill",
            color: UIColor(red: 0.17, green: 0.56, blue: 0.90, alpha: 1),
            title: "Отправить отчёт сейчас"
        ) { [weak self] in self?.sendNow() }
        inner.addArrangedSubview(sendRow)

        return card
    }

    @objc private func chatIdChanged(_ tf: UITextField) {
        TelegramManager.shared.chatId = tf.text ?? ""
    }

    private func saveChatId() {
        TelegramManager.shared.chatId = chatIdField?.text ?? ""
    }

    private func sendNow() {
        guard TelegramManager.shared.isConfigured else {
            SPIndicator.present(title: "Введите Chat ID", preset: .error, haptic: .error)
            return
        }
        Task {
            let now = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
            let ok = await TelegramManager.shared.sendReport(timeLabel: now)
            if ok {
                SPIndicator.present(title: "Отправлено в Telegram", preset: .done, haptic: .success)
            } else {
                SPIndicator.present(title: "Ошибка отправки", preset: .error, haptic: .error)
            }
        }
    }

    @objc private func reloadBg() { backgroundView.apply(BackgroundManager.shared.config) }

    private func makeActionRow(icon: String, color: UIColor, title: String, action: @escaping () -> Void) -> UIView {
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

        let lbl = UILabel()
        lbl.text = title
        lbl.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        lbl.textColor = UIColor(red: 0.17, green: 0.56, blue: 0.90, alpha: 1)

        let row = UIStackView(arrangedSubviews: [iconWrap, lbl, UIView()])
        row.alignment = .center
        row.spacing = 12
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        row.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(actionTap(_:)))
        row.addGestureRecognizer(tap)
        objc_setAssociatedObject(row, "action", action, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        return row
    }

    @objc private func actionTap(_ g: UITapGestureRecognizer) {
        guard let action = objc_getAssociatedObject(g.view, "action") as? () -> Void else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        action()
    }

    private func makeCard() -> UIVisualEffectView {
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        card.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.5)
        card.layer.cornerRadius = 16
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        return card
    }
}

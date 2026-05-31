import UIKit
import SnapKit
import SPIndicator

final class AIChatViewController: UIViewController {
    private let tableView = UITableView()
    private let inputBar = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
    private let textField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let typingLabel = UILabel()

    private var messages: [ChatMessageModel] = []
    private var isThinking = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "ИИ Тренер"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))
        setupTable()
        setupInputBar()
        loadMessages()
        registerKeyboard()
    }

    private func setupTable() {
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ChatBubbleCell.self, forCellReuseIdentifier: ChatBubbleCell.reuseID)
        tableView.keyboardDismissMode = .interactive
        tableView.allowsSelection = false
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
        }

        typingLabel.text = "печатает…"
        typingLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        typingLabel.textColor = .secondaryLabel
        typingLabel.isHidden = true
        view.addSubview(typingLabel)
        typingLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(24)
        }
    }

    private func setupInputBar() {
        inputBar.layer.borderWidth = 0.5
        inputBar.layer.borderColor = UIColor.separator.cgColor
        view.addSubview(inputBar)
        inputBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(tableView.snp.bottom)
            $0.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
        }
        typingLabel.snp.makeConstraints {
            $0.bottom.equalTo(inputBar.snp.top).offset(-6)
        }

        textField.placeholder = "Чего хочешь?"
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.backgroundColor = .secondarySystemBackground
        textField.layer.cornerRadius = 20
        textField.layer.cornerCurve = .continuous
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        textField.leftViewMode = .always
        textField.returnKeyType = .send
        textField.delegate = self

        let sendConfig = UIImage.SymbolConfiguration(pointSize: 32)
        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill", withConfiguration: sendConfig), for: .normal)
        sendButton.tintColor = .label
        sendButton.addTarget(self, action: #selector(send), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [textField, sendButton])
        stack.spacing = 10
        stack.alignment = .center
        inputBar.contentView.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().inset(10)
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.bottom.equalTo(inputBar.safeAreaLayoutGuide).inset(10)
        }
        textField.snp.makeConstraints { $0.height.equalTo(40) }
    }

    private func loadMessages() {
        messages = DataManager.shared.fetchMessages()
        if messages.isEmpty {
            let greeting = "Готов меняться? Скажи, что хочешь добавить или изменить."
            DataManager.shared.addMessage(greeting, isUser: false)
            messages = DataManager.shared.fetchMessages()
        }
        tableView.reloadData()
        scrollToBottom(animated: false)
    }

    private func registerKeyboard() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }
    @objc private func close() { dismiss(animated: true) }

    @objc private func send() {
        let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty, !isThinking else { return }
        textField.text = ""
        appendMessage(text, isUser: true)
        UIImpactFeedbackGenerator.tap(.light)
        Task { await handleConversation(userText: text) }
    }

    private func appendMessage(_ text: String, isUser: Bool) {
        DataManager.shared.addMessage(text, isUser: isUser)
        messages = DataManager.shared.fetchMessages()
        tableView.reloadData()
        scrollToBottom(animated: true)
    }

    private func setThinking(_ thinking: Bool) {
        isThinking = thinking
        typingLabel.isHidden = !thinking
    }

    private func history() -> [GroqTurn] {
        messages.suffix(16).map { GroqTurn(role: $0.isUser ? "user" : "assistant", content: $0.text) }
    }

    private func handleConversation(userText: String) async {
        setThinking(true)
        defer { setThinking(false) }
        do {
            let result = try await GroqAI.send(history: history())
            if !result.message.isEmpty {
                appendMessage(result.message, isUser: false)
            }
            await process(commands: result.commands)
        } catch {
            appendMessage("Связь с тренером оборвалась. Попробуй ещё раз.", isUser: false)
        }
    }

    private func process(commands: [AICommand]) async {
        var scrapeCommand: (url: String, query: String)?
        for command in commands {
            if case let .scrapeSite(url, query) = command {
                scrapeCommand = (url, query)
            } else if let feedback = CommandExecutor.execute(command) {
                showFeedback(feedback)
            }
        }
        if let scrape = scrapeCommand {
            await runScrape(url: scrape.url, query: scrape.query)
        }
    }

    private func runScrape(url: String, query: String) async {
        setThinking(true)
        defer { setThinking(false) }
        do {
            let result: ScrapeResult
            if PlaywrightServerClient.shared.isConfigured {
                let response = try await PlaywrightServerClient.shared.run(PlaywrightCommand(url: url))
                result = ScrapeResult(text: response.text ?? "", tables: [], lists: [])
            } else {
                result = try await WebAgent.shared.scrape(urlString: url)
            }

            let digest = buildDigest(result)
            let followup = "Я прочитал сайт \(url). Запрос пользователя: \"\(query)\". Вот извлечённые данные:\n\(digest)\n\nНа основе этих данных дай краткий ответ и при необходимости команды (ADD_TASK и т.д.). Формат JSON как обычно."
            var turns = history()
            turns.append(GroqTurn(role: "user", content: followup))
            let result2 = try await GroqAI.send(history: turns)
            if !result2.message.isEmpty {
                appendMessage(result2.message, isUser: false)
            }
            for command in result2.commands {
                if case .scrapeSite = command { continue }
                if let feedback = CommandExecutor.execute(command) {
                    showFeedback(feedback)
                }
            }
        } catch {
            appendMessage("Не смог прочитать сайт. Дай другую ссылку.", isUser: false)
        }
    }

    private func buildDigest(_ result: ScrapeResult) -> String {
        var parts: [String] = []
        if !result.lists.isEmpty {
            parts.append("Списки:\n" + result.lists.prefix(40).joined(separator: "\n"))
        }
        if !result.tables.isEmpty {
            let rows = result.tables.prefix(30).map { $0.joined(separator: " | ") }
            parts.append("Таблицы:\n" + rows.joined(separator: "\n"))
        }
        if parts.isEmpty {
            parts.append(String(result.text.prefix(2500)))
        }
        return parts.joined(separator: "\n\n").prefix(3500).description
    }

    private func showFeedback(_ feedback: CommandFeedback) {
        UIImpactFeedbackGenerator.tap(.medium)
        SPIndicator.present(title: feedback.title, preset: .done, haptic: .success)
        if feedback.opensBackgroundPicker {
            BackgroundPicker.shared.present(from: self)
        }
    }

    private func scrollToBottom(animated: Bool) {
        guard !messages.isEmpty else { return }
        let index = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: index, at: .bottom, animated: animated)
    }
}

extension AIChatViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { messages.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatBubbleCell.reuseID, for: indexPath) as! ChatBubbleCell
        let message = messages[indexPath.row]
        cell.configure(text: message.text, isUser: message.isUser)
        return cell
    }
}

extension AIChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        send()
        return true
    }
}

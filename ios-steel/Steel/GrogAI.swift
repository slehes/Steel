import Foundation

enum AICommand: Sendable {
    case addTask(title: String, amount: Int, unit: String, icon: String)
    case removeTask(title: String)
    case addHabit(title: String, icon: String)
    case removeHabit(title: String)
    case setReminder(hours: [Int])
    case buildPlan(plan: String)
    case changeBackground(action: String)
    case scrapeSite(url: String, query: String)
}

struct GroqTurn: Sendable {
    let role: String
    let content: String
}

struct GroqResult: Sendable {
    let message: String
    let commands: [AICommand]
}

enum GroqError: Error {
    case badResponse
    case decoding
}

enum GroqAI {
    static let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    static let model = "llama-3.3-70b-versatile"

    static let systemPrompt = """
    Ты AI-тренер в Steel. Помогаешь меняться. Будь жёстким, с чёрным юмором. Отвечай кратко, до трёх предложений.

    ВАЖНО: НИКОГДА не добавляй тренировки или привычки без обсуждения! Сначала задай вопросы: что предпочитает пользователь, какие цели, какой уровень подготовки, сколько времени готов тратить. Обсуди план, предложи варианты. Только ПОСЛЕ обсуждения и согласия пользователя используй команды ADD_TASK или ADD_HABIT.

    Если пользователь просит найти информацию на сайте, сразу отвечай "Читаю сайт..." и выполняй команду SCRAPE_SITE, не показывая технических деталей. Формат ответа строго JSON: {"message":"...","commands":[...]}. Если команд нет – commands:[].

    Доступные команды (поле type):
    ADD_TASK {"type":"ADD_TASK","title":"Отжимания","amount":50,"unit":"раз","icon":"figure.strengthtraining.traditional"}
    REMOVE_TASK {"type":"REMOVE_TASK","title":"Отжимания"}
    ADD_HABIT {"type":"ADD_HABIT","title":"Сахар","icon":"cube"}
    REMOVE_HABIT {"type":"REMOVE_HABIT","title":"Сахар"}
    SET_REMINDER {"type":"SET_REMINDER","hours":[9,19,22]}
    BUILD_PLAN {"type":"BUILD_PLAN","plan":"текст плана тренировок"}
    CHANGE_BACKGROUND {"type":"CHANGE_BACKGROUND","action":"open"} (action: open или disable)
    SCRAPE_SITE {"type":"SCRAPE_SITE","url":"https://example.com","query":"что искать"}

    icon — это валидное имя SF Symbol. Используй осмысленные иконки.
    """

    static func send(history: [GroqTurn]) async throws -> GroqResult {
        var turns: [[String: String]] = [["role": "system", "content": systemPrompt]]
        for turn in history {
            turns.append(["role": turn.role, "content": turn.content])
        }

        let body: [String: Any] = [
            "model": model,
            "messages": turns,
            "temperature": 0.8,
            "max_tokens": 800,
            "response_format": ["type": "json_object"],
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(KeychainHelper.groqAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GroqError.badResponse
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let messageObj = first["message"] as? [String: Any],
            let content = messageObj["content"] as? String
        else {
            throw GroqError.decoding
        }

        return parse(content: content)
    }

    static func parse(content: String) -> GroqResult {
        guard
            let data = content.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return GroqResult(message: content, commands: [])
        }

        let message = (json["message"] as? String) ?? ""
        let rawCommands = (json["commands"] as? [[String: Any]]) ?? []
        let commands = rawCommands.compactMap(parseCommand)
        return GroqResult(message: message, commands: commands)
    }

    private static func parseCommand(_ dict: [String: Any]) -> AICommand? {
        guard let type = (dict["type"] as? String)?.uppercased() else { return nil }
        switch type {
        case "ADD_TASK":
            let title = (dict["title"] as? String) ?? "Задание"
            let amount = intValue(dict["amount"]) ?? 1
            let unit = (dict["unit"] as? String) ?? ""
            let icon = (dict["icon"] as? String) ?? "checkmark.circle"
            return .addTask(title: title, amount: amount, unit: unit, icon: icon)
        case "REMOVE_TASK":
            guard let title = dict["title"] as? String else { return nil }
            return .removeTask(title: title)
        case "ADD_HABIT":
            let title = (dict["title"] as? String) ?? "Привычка"
            let icon = (dict["icon"] as? String) ?? "xmark.circle"
            return .addHabit(title: title, icon: icon)
        case "REMOVE_HABIT":
            guard let title = dict["title"] as? String else { return nil }
            return .removeHabit(title: title)
        case "SET_REMINDER":
            let hours = (dict["hours"] as? [Any])?.compactMap(intValue) ?? []
            return .setReminder(hours: hours)
        case "BUILD_PLAN":
            let plan = (dict["plan"] as? String) ?? ""
            return .buildPlan(plan: plan)
        case "CHANGE_BACKGROUND":
            let action = (dict["action"] as? String) ?? "open"
            return .changeBackground(action: action)
        case "SCRAPE_SITE":
            guard let url = dict["url"] as? String else { return nil }
            let query = (dict["query"] as? String) ?? ""
            return .scrapeSite(url: url, query: query)
        default:
            return nil
        }
    }

    private static func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d) }
        if let s = any as? String { return Int(s) }
        return nil
    }
}

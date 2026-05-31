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
    Ты AI-тренер в приложении Steel. Ты помогаешь пользователю стать дисциплинированнее. Будь жёстким, с чёрным юмором, но полезным.

    АБСОЛЮТНОЕ ПРАВИЛО ЯЗЫКА: Ты ДОЛЖЕН писать ТОЛЬКО на русском языке. ЗАПРЕЩЕНО использовать английские слова. Все названия мышц, упражнений, терминов — ТОЛЬКО на русском. Примеры обязательных переводов: triceps→трицепс, biceps→бицепс, pushups→отжимания, squats→приседания, planks→планка, deadlift→становая тяга, bench press→жим лёжа, lunges→выпады, burpees→бёрпи, crunches→скручивания, dips→отжимания на брусьях, pullups→подтягивания, shoulders→плечи, chest→грудь, back→спина, legs→ноги, abs→пресс, core→кор, glutes→ягодицы, hamstrings→задняя поверхность бедра, calves→икры, forearms→предплечья, cardio→кардио, stretching→растяжка. Если сомневаешься — переведи на русский.

    КРИТИЧЕСКИЕ ПРАВИЛА:
    1. ОБСУЖДЕНИЕ ПЕРЕД ДЕЙСТВИЕМ: Когда пользователь просит добавить тренировку или привычку, НЕ добавляй сразу. Сначала задай вопросы: какие цели? какой уровень? сколько времени? Предложи варианты. Только после ЯВНОГО согласия («да», «давай», «ок») используй ADD_TASK/ADD_HABIT.
    2. МЕСТО ТРЕНИРОВКИ: В первый раз обязательно спроси: «Ты занимаешься дома или в спортзале?» и запомни ответ. Адаптируй рекомендации: для дома — упражнения без оборудования (отжимания, приседания, планка, бёрпи), для зала — с оборудованием (жим лёжа, тяга, подтягивания, гантели).
    3. Отвечай КРАТКО — максимум 2-3 коротких предложения. Не пиши длинные тексты.
    4. ВСЁ НА РУССКОМ — названия мышц, упражнений, единиц измерения — строго по-русски. Никаких английских слов.

    Формат ответа строго JSON: {"message":"...","commands":[...]}. Если команд нет — commands:[].

    Доступные команды:
    ADD_TASK {"type":"ADD_TASK","title":"Отжимания","amount":50,"unit":"раз","icon":"figure.strengthtraining.traditional"}
    REMOVE_TASK {"type":"REMOVE_TASK","title":"Отжимания"}
    ADD_HABIT {"type":"ADD_HABIT","title":"Сахар","icon":"cube"}
    REMOVE_HABIT {"type":"REMOVE_HABIT","title":"Сахар"}
    SET_REMINDER {"type":"SET_REMINDER","hours":[9,19,22]}
    BUILD_PLAN {"type":"BUILD_PLAN","plan":"текст плана"}
    CHANGE_BACKGROUND {"type":"CHANGE_BACKGROUND","action":"open"}
    SCRAPE_SITE {"type":"SCRAPE_SITE","url":"https://example.com","query":"что искать"}

    icon — валидное имя SF Symbol. unit — по-русски (раз, минут, км и т.д.). title — по-русски.
    """

    static func send(history: [GroqTurn]) async throws -> GroqResult {
        var turns: [[String: String]] = [["role": "system", "content": systemPrompt]]
        for turn in history {
            turns.append(["role": turn.role, "content": turn.content])
        }

        let body: [String: Any] = [
            "model": model,
            "messages": turns,
            "temperature": 0.7,
            "max_tokens": 500,
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

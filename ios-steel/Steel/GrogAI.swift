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
    Ты — ИИ-тренер в приложении Steel. Ты СТРОГИЙ, ЖЁСТКИЙ и БЕСПОЩАДНЫЙ тренер-дисциплинатор. Ты НЕ нянчишься с пользователем. Ты следишь за ним, контролируешь его, и заставляешь работать.

    ТВОЯ РОЛЬ:
    - Ты СЛЕДИШЬ за пользователем. Ты знаешь сколько у него задач, привычек, какая серия. Используй эту информацию.
    - Ты НЕ принимаешь отговорки. «Устал» — тренируйся. «Нет времени» — 5 минут найди. «Болит» — значит растёт.
    - Ты ДАЁШЬ конкретные тренировки с точными цифрами. Не «сделай отжимания», а «50 отжиманий, прямо сейчас».
    - Ты СОЗДАЁШЬ привычки когда видишь слабость. Если жалуется — добавляй привычку от этого.
    - Ты ПРОВЕРЯЕШЬ прогресс. Если задачи не выполнены — орешь. Если выполнены — даёшь новые, сложнее.
    - Ты МОТИВИРУЕШЬ через жёсткость. «Слабак сдаётся. Ты слабак или воин?»
    - Ты НАЗНАЧАЕШЬ наказания. Пропустил тренировку? Двойная нагрузка завтра.

    АБСОЛЮТНОЕ ПРАВИЛО ЯЗЫКА: ТОЛЬКО русский язык. Все упражнения, мышцы, термины — по-русски. triceps→трицепс, pushups→отжимания, squats→приседания, planks→планка, burpees→бёрпи, lunges→выпады, crunches→скручивания, pullups→подтягивания, deadlift→становая тяга, bench press→жим лёжа.

    ПРАВИЛА ПОВЕДЕНИЯ:
    1. СРАЗУ ДЕЙСТВУЙ: Когда просишь тренировку — НЕ спрашивай уточнения. СРАЗУ добавляй задачи через ADD_TASK. Ты тренер, ты решаешь.
    2. ДОМА ИЛИ ЗАЛ: Спроси один раз. Запомни. Больше не спрашивай.
    3. СОЗДАВАЙ ПРИВЫЧКИ: Видишь слабое место? Добавь привычку через ADD_HABIT. Без спроса. Ты знаешь лучше.
    4. КОНТРОЛИРУЙ: Проверяй что выполнено. Ругай за лень. Хвали коротко — и даёшь новую нагрузку.
    5. ОТВЕЧАЙ КОРОТКО: 1-3 предложения. Жёстко. По делу. Без воды.
    6. УВЕЛИЧИВАЙ НАГРУЗКУ: Каждая новая тренировка сложнее предыдущей. Не позволяй расслабляться.
    7. ВЫЗЫВАЙ: Бросай вызов. «Думаешь, это сложно? Добавлю ещё.»

    СТИЛЬ ОТВЕТОВ:
    - «50 отжиманий. Сейчас. Не хочешь — добавлю ещё 20.»
    - «Пропустил день? Слабак. Завтра двойная нагрузка.»
    - «Неплохо. Но этого мало. Добавляю привычку — отказ от сладкого.»
    - «Жалуешься? Значит тренируешься. Боль — признак роста.»
    - «Ты здесь не отдыхать пришёл. Давай, добавляю тренировку.»

    Формат ответа строго JSON: {"message":"...","commands":[...]}. Если команд нет — commands:[]. ВСЕГДА старайся добавить хотя бы одну команду (ADD_TASK, ADD_HABIT, или BUILD_PLAN). Ты тренер — ты назначаешь, пользователь выполняет.

    Доступные команды:
    ADD_TASK {"type":"ADD_TASK","title":"Отжимания","amount":50,"unit":"раз","icon":"figure.strengthtraining.traditional"}
    REMOVE_TASK {"type":"REMOVE_TASK","title":"Отжимания"}
    ADD_HABIT {"type":"ADD_HABIT","title":"Сахар","icon":"cube"}
    REMOVE_HABIT {"type":"REMOVE_HABIT","title":"Сахар"}
    SET_REMINDER {"type":"SET_REMINDER","hours":[9,19,22]}
    BUILD_PLAN {"type":"BUILD_PLAN","plan":"текст плана"}
    CHANGE_BACKGROUND {"type":"CHANGE_BACKGROUND","action":"open"}
    SCRAPE_SITE {"type":"SCRAPE_SITE","url":"https://example.com","query":"что искать"}

    icon — валидное имя SF Symbol. unit — по-русски (раз, минут, км). title — по-русски. amount — реалистичное число, но жёсткое.
    """

    static func send(history: [GroqTurn]) async throws -> GroqResult {
        // Inject user's current data as context
        let contextMessage = buildContextMessage()
        var turns: [[String: String]] = [["role": "system", "content": systemPrompt + "\n\nТЕКУЩИЕ ДАННЫЕ ПОЛЬЗОВАТЕЛЯ:\n" + contextMessage]]
        for turn in history {
            turns.append(["role": turn.role, "content": turn.content])
        }

        let body: [String: Any] = [
            "model": model,
            "messages": turns,
            "temperature": 0.8,
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

    /// Build context message with user's current data so AI can monitor them
    private static func buildContextMessage() -> String {
        let settings = DataManager.shared.settings
        let tasks = DataManager.shared.fetchTasks()
        let habits = DataManager.shared.fetchHabits()
        let done = tasks.filter(\.isCompleted).count
        let total = tasks.count
        let pct = total > 0 ? Int(Double(done) / Double(total) * 100) : 0

        var context = "- Серия: \(settings.streakDays) дней\n"
        context += "- Выполнено сегодня: \(done)/\(total) (\(pct)%)\n"
        context += "- Всего выполнено за всё время: \(settings.totalCompletedTasks)\n"
        context += "- Уровень: \(DataManager.shared.level), XP: \(DataManager.shared.xp)\n"
        context += "- Место тренировок: \(settings.userTrainingLocation.isEmpty ? "не указано" : (settings.userTrainingLocation == "home" ? "дома" : "зал"))\n"

        if !tasks.isEmpty {
            context += "- Задачи на сегодня: " + tasks.map { t in
                "\(t.title) \(t.amount)\(t.unit.isEmpty ? "" : " \(t.unit)")" + (t.isCompleted ? " ✅" : " ⬜")
            }.joined(separator: ", ") + "\n"
        }

        if !habits.isEmpty {
            context += "- Привычки: " + habits.map { "\($0.title) — \($0.cleanDays) дн. чисто" }.joined(separator: ", ") + "\n"
        }

        return context
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

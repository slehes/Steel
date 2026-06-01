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

    ═══════════════════════════════════════════
    ОНБОРДИНГ: ПЕРВЫЙ ЗАПУСК
    ═══════════════════════════════════════════
    Если пользователь новичок (нет истории тренировок, streakDays=0, totalCompletedTasks=0):
    1. СПРОСИ УРОВЕНЬ: «Ты новичок, средняк или опытный?»
    2. СПРОСИ СТАЖ: «Сколько занимаешься спортом?» (месяцы/годы)
    3. СПРОСИ ЦЕЛЬ: «Что хочешь: похудеть / набрать массу / выносливость / дисциплину?»
    4. СПРОСИ МЕСТО: «Дома или в зале?»
    5. Запомни ответы. Дальше НЕ спрашивай.

    ═══════════════════════════════════════════
    ШКАЛА СЛОЖНОСТИ
    ═══════════════════════════════════════════
    НОВИЧОК (0-3 мес):
    - Отжимания: 10-20, приседания: 15-20, планка: 20-30 сек
    - Базовые упражнения, простые комбинации
    - Никаких сложных вариаций
    - Минимум 1 минута отдыха между подходами
    - Темп: спокойный, контролируемый
    - ТИПЫ ТРЕНИРОВОК: базовая зарядка, утренняя разминка, лёгкий фитнес, прогулка+упражнения

    СРЕДНЯК (3-12 мес):
    - Отжимания: 30-50, приседания: 30-50, планка: 45-60 сек
    - Добавляй variation: узкая/широкая постановка, с паузой внизу
    - Дополнительные упражнения: скручивания, выпады, бёрпи (fewer reps)
    - ТИПЫ ТРЕНИРОВОК: HIIT, силовая, кардио-день, круговая,Upper/Lower body split

    ОПЫТНЫЙ (1+ год):
    - Отжимания: 50-100+, приседания: 50-100+, планка: 60-120 сек
    - Сложные вариации: бёрпи, отжимания на одной руке (если дома), выпады с прыжком
    - Большие объёмы, короткий отдых
    - ТИПЫ ТРЕНИРОВОК: кроссфит-стиль,EMOM, AMRAP, Tabata, circuit training, functional training

    ═══════════════════════════════════════════
    РАЗНООБРАЗИЕ ТИПОВ ТРЕНИРОВОК
    ═══════════════════════════════════════════
    Всегда ЧЕРЕДУЙ типы. Не повторяй один и тот же дважды подряд.

    БАЗОВАЯ ЗАРЯДКА (новчики): лёгкие упражнения, 10-15 мин, утро
    HIIT (все уровни): 20 сек работа / 10 сек отдых, 8-15 раундов
    СИЛОВАЯ: 4-5 упражнений, 3-4 подхода, 60-90 сек отдых
    КАРДИО: бег/прыжки/скакалка, 15-25 мин
    КРУГОВАЯ: 5-7 упражнений, 3 круга, минимальный отдых
    EMOM (опытные): каждую минуту новое задание, 10-15 мин
    TABATA: 20 сек / 10 сек × 8, максимальная интенсивность
    FLEXIBILITY: растяжка, йога- позы, 15-20 мин
    ФУНКЦИОНАЛЬНАЯ: movements patterns, burpees, mountain climbers
    CORE DAY: только пресс, side plank, лежачие подъёмы ног

    ═══════════════════════════════════════════
    ЖЁСТКОСТЬ ПО ВРЕМЕНИ
    ═══════════════════════════════════════════
    - Всегда называй ВРЕМЯ выполнения: «сделай за 3 минуты»
    - Ставь таймер в голове: не успел — добавляй наказание
    - Если пользователь жалуется на время — напомни: «Время не ждёт. Это дисциплина.»
    - Если задача не выполнена за день — наказывай: «Пропустил? Завтра двойная порция.»

    ═══════════════════════════════════════════
    ПРАВИЛА ПОВЕДЕНИЯ
    ═══════════════════════════════════════════
    1. СРАЗУ ДЕЙСТВУЙ: Когда просишь тренировку — НЕ спрашивай уточнения. СРАЗУ добавляй задачи.
    2. ДОМА ИЛИ ЗАЛ: Спроси один раз при онбординге. Запомни. Больше не спрашивай.
    3. СОЗДАВАЙ ПРИВЫЧКИ: Видишь слабое место? Добавь привычку. Без спроса.
    4. КОНТРОЛИРУЙ: Проверяй что выполнено. Ругай за лень. Хвали коротко — и давай новую нагрузку.
    5. ОТВЕЧАЙ КОРОТКО: 1-3 предложения. Жёстко. По делу. Без воды.
    6. УВЕЛИЧИВАЙ НАГРУЗКУ: Каждая новая тренировка сложнее предыдущей.
    7. ВЫЗЫВАЙ: Бросай вызов. «Думаешь, это сложно? Добавлю ещё.»
    8. СПРАШИВАЙ ОПЫТ: Если новичок — начинай с лёгкого. Если опытный — требуй максимум.

    СТИЛЬ ОТВЕТОВ:
    - «50 отжиманий. Сделай за 3 минуты. Не успеешь — добавлю ещё 20.»
    - «Пропустил день? Слабак. Завтра двойная нагрузка.»
    - «Неплохо. Но этого мало. Добавляю привычку — отказ от сладкого.»
    - «Ты здесь не отдыхать пришёл. Давай, добавляю тренировку.»
    - «Круговая: 5 упражнений, 3 круга, 2 минуты отдыха. Поехали.»

    Формат ответа строго JSON: {"message":"...","commands":[...]}. Если команд нет — commands:[]. ВСЕГДА старайся добавить хотя бы одну команду (ADD_TASK, ADD_HABIT, или BUILD_PLAN). Ты тренер — ты назначаешь, пользователь выполняет.

    ═══════════════════════════════════════════
    ПЛАН ТРЕНИРОВОК (BUILD_PLAN) — ОБЯЗАТЕЛЬНАЯ СТРУКТУРА
    ═══════════════════════════════════════════
    Когда пользователь просит «составь план», «программа», «распиши тренировки»,
    «сделай план на N недель» — ты ОБЯЗАН вернуть команду BUILD_PLAN с ДЕТАЛЬНЫМ
    многонедельным планом. Структура плана строго такая (используй эти заголовки
    дословно, на русском, заглавными буквами для распознавания):

    ПРОГРАММА: <название программы, ёмкое>
    ЦЕЛЬ: <одна строка — что получим через N недель>
    ДЛИТЕЛЬНОСТЬ: <количество недель, например 8>
    УРОВЕНЬ: <новичок / средняк / опытный>

    НЕДЕЛЯ 1
    - ДЕНЬ 1 (ПН): <тип тренировки> — <упражнения через запятую с подходами и повторами, например: 50 отжиманий, 30 приседаний, планка 60 секунд>
    - ДЕНЬ 2 (ВТ): <тип> — <упражнения>
    - ДЕНЬ 3 (СР): ОТДЫХ / <тип> — <упражнения>
    - ДЕНЬ 4 (ЧТ): <тип> — <упражнения>
    - ДЕНЬ 5 (ПТ): <тип> — <упражнения>
    - ДЕНЬ 6 (СБ): <тип> — <упражнения>
    - ДЕНЬ 7 (ВС): ОТДЫХ

    НЕДЕЛЯ 2
    - ДЕНЬ 1 (ПН): <тип> — <упражнения>
    ... (тот же шаблон, нагрузка +10–20%)

    ... повторяй структуру для КАЖДОЙ недели до конечной.

    ПИТАНИЕ
    - ЗАВТРАК (7:00–8:00): <что есть, БЖУ и калории если возможно>
    - ПЕРЕКУС 1 (10:30): <перекус>
    - ОБЕД (13:00–14:00): <полноценный обед>
    - ПЕРЕКУС 2 (16:30): <перекус>
    - УЖИН (19:00–20:00): <ужин, лёгкий>
    - ПЕРЕД СНОМ (по желанию): <творог / кефир / казеин>
    - ВОДА: минимум <X> литров в день
    - ЧЕГО ИЗБЕГАТЬ: <короткий список — сахар, фастфуд, алкоголь, сладкие напитки>

    РЕЖИМ ДНЯ
    - ПОДЪЁМ: <время>
    - ОТБОЙ: <время>
    - СОН: минимум 7–8 часов
    - ЭКРАНЫ: выключить за час до сна
    - КАРДИО В ФОНОВЫЕ ДНИ: 20 минут прогулка / лёгкое кардио

    ВОССТАНОВЛЕНИЕ
    - Растяжка 10 мин после каждой тренировки
    - Баня / сауна 1 раз в 2 недели
    - Массаж / фоам-роллер по самочувствию
    - Дневник тренировок — записывать что сделал

    ПРАВИЛА ПЛАНА:
    1. Минимум 4 недели, оптимально 6–8. Если пользователь не сказал сколько — делай 6.
    2. Нагрузка растёт каждую неделю на 10–20%.
    3. Чередуй типы тренировок (силовая / кардио / HIIT / восстановление).
    4. ОБЯЗАТЕЛЬНО укажи ДНИ ОТДЫХА.
    5. План должен быть РЕАЛИСТИЧНЫМ: тренировка — 30–60 мин, не больше.
    6. Питание — на 1500–2500 ккал в зависимости от цели.
    7. В message кратко: «Готово, программа на N недель. Открой «Мой план» — там подробности.»

    ПРИМЕР КОМАНДЫ BUILD_PLAN (план помещается в поле plan одной строкой JSON,
    переводы строк заменены на \\n):
    {"type":"BUILD_PLAN","plan":"ПРОГРАММА: Стальной старт\\nЦЕЛЬ: ...\\n..."}

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
        context += "- Дисциплина: \(settings.totalCompletedTasks) выполнено, серия \(settings.streakDays) дн.\n"
        context += "- Место тренировок: \(settings.userTrainingLocation.isEmpty ? "не указано" : (settings.userTrainingLocation == "home" ? "дома" : "зал"))\n"

        // Include year goals so AI can tailor training
        if !settings.yearGoals.isEmpty {
            context += "\n🎯 ЦЕЛИ НА ГОД:\n"
            for goal in settings.yearGoals {
                let pct = Int(goal.progress * 100)
                context += "- \(goal.title): \(goal.currentValue)/\(goal.targetValue) (\(pct)%)\n"
            }
            context += "Учитывай эти цели! Если цель «\(settings.yearGoals[0].title)», создавай упражнения которые приближают к ней.\n"
        }

        if !tasks.isEmpty {
            context += "\n- Задачи на сегодня: " + tasks.map { t in
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

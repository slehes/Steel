import Foundation

/// Парсер плана тренировок, который превращает плоский текст от ИИ-тренера
/// в структурированную модель `ParsedPlan`.
///
/// Ожидаемый формат (заголовки заглавными, маркеры `-` или `•`):
///
///     ПРОГРАММА: <название>
///     ЦЕЛЬ: <цель>
///     ДЛИТЕЛЬНОСТЬ: 6 недель
///     УРОВЕНЬ: средняк
///
///     НЕДЕЛЯ 1
///     - ДЕНЬ 1 (ПН): силовая — 50 отжиманий, 30 приседаний
///     - ДЕНЬ 2 (ВТ): кардио — 20 минут бег
///     ...
///
///     НЕДЕЛЯ 2
///     ...
///
///     ПИТАНИЕ
///     - ЗАВТРАК (7:00–8:00): овсянка + яйца
///     - ОБЕД (13:00): курица + гречка + овощи
///     ...
///
///     РЕЖИМ ДНЯ
///     - ПОДЪЁМ: 6:30
///     - ОТБОЙ: 23:00
///     ...
///
///     ВОССТАНОВЛЕНИЕ
///     - ...
struct ParsedPlan {
    struct Program {
        let title: String
        let goal: String
        let duration: String
        let level: String
    }

    /// День недели с типом и упражнениями/нагрузкой
    struct Day {
        let index: Int      // 1..7
        let weekday: String // "ПН" / "ВТ" / ...
        let type: String    // "СИЛОВАЯ" / "КАРДИО" / "ОТДЫХ" / ...
        let body: String    // описание упражнений или содержимое дня
    }

    struct Week {
        let index: Int       // 1..N
        var days: [Day]
    }

    struct Meal {
        let name: String   // "ЗАВТРАК" / "ОБЕД" / ...
        let time: String   // "7:00–8:00" / ""
        let body: String   // описание еды
    }

    struct Tip {
        let title: String  // "ПОДЪЁМ" / "СОН" / ...
        let body: String
    }

    let program: Program
    let weeks: [Week]
    let meals: [Meal]
    let schedule: [Tip]
    let recovery: [Tip]
}

enum PlanParser {
    static func parse(_ body: String) -> ParsedPlan {
        let lines = body.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }

        var title = ""
        var goal = ""
        var duration = ""
        var level = ""

        var weeks: [ParsedPlan.Week] = []
        var meals: [ParsedPlan.Meal] = []
        var schedule: [ParsedPlan.Tip] = []
        var recovery: [ParsedPlan.Tip] = []

        var currentWeek: ParsedPlan.Week? = nil
        var currentSection: Section = .program

        enum Section {
            case program, week, meals, schedule, recovery
        }

        for raw in lines {
            let line = raw
            guard !line.isEmpty else { continue }
            let upper = line.uppercased()

            // Заголовки секций
            if upper.hasPrefix("ПРОГРАММА") { currentSection = .program; continue }
            if upper.hasPrefix("НЕДЕЛЯ") {
                currentSection = .week
                // НЕДЕЛЯ 1 → 1
                let num = upper
                    .replacingOccurrences(of: "НЕДЕЛЯ", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: " ")
                    .first ?? "0"
                let idx = Int(num) ?? (weeks.count + 1)
                if let finished = currentWeek { weeks.append(finished) }
                currentWeek = ParsedPlan.Week(index: idx, days: [])
                continue
            }
            if upper.hasPrefix("ПИТАНИЕ") { currentSection = .meals; continue }
            if upper.hasPrefix("РЕЖИМ ДНЯ") { currentSection = .schedule; continue }
            if upper.hasPrefix("ВОССТАНОВЛЕНИЕ") { currentSection = .recovery; continue }

            // Ключ: значение в шапке (ПРОГРАММА:, ЦЕЛЬ:, ДЛИТЕЛЬНОСТЬ:, УРОВЕНЬ:)
            if currentSection == .program, line.contains(":") {
                let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
                guard parts.count == 2 else { continue }
                let key = parts[0].trimmingCharacters(in: .whitespaces).uppercased()
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "ПРОГРАММА":    title = value
                case "ЦЕЛЬ":         goal = value
                case "ДЛИТЕЛЬНОСТЬ": duration = value
                case "УРОВЕНЬ":      level = value
                default: break
                }
                continue
            }

            // Маркированные строки
            guard line.hasPrefix("-") || line.hasPrefix("•") else { continue }
            let content = line.dropFirst().trimmingCharacters(in: .whitespaces)
            guard !content.isEmpty else { continue }

            switch currentSection {
            case .program:
                continue
            case .week:
                if var week = currentWeek {
                    let day = parseDay(content)
                    week.days.append(day)
                    currentWeek = week
                }
            case .meals:
                meals.append(parseMeal(content))
            case .schedule:
                schedule.append(parseTip(content))
            case .recovery:
                recovery.append(parseTip(content))
            }
        }
        if let finished = currentWeek { weeks.append(finished) }

        return ParsedPlan(
            program: .init(title: title, goal: goal, duration: duration, level: level),
            weeks: weeks,
            meals: meals,
            schedule: schedule,
            recovery: recovery
        )
    }

    // MARK: - Парсинг отдельных строк

    /// "ДЕНЬ 1 (ПН): силовая — 50 отжиманий, 30 приседаний"
    private static func parseDay(_ raw: String) -> ParsedPlan.Day {
        let upper = raw.uppercased()
        // Номер дня — ищем первую цифру после слова ДЕНЬ
        var index = 0
        if let dayRange = upper.range(of: "ДЕНЬ") {
            let after = upper[dayRange.upperBound...]
            for ch in after {
                if ch.isNumber {
                    index = ch.wholeNumberValue ?? 0
                    break
                }
            }
        }
        // День недели в скобках: (ПН) / (ВТ) / ...
        var weekday = ""
        if let paren = raw.range(of: #"\([А-Яа-я]{2}\)"#, options: .regularExpression) {
            weekday = String(raw[paren])
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .uppercased()
        }
        // Тело — после первого двоеточия
        var body = raw
        if let colon = raw.firstIndex(of: ":") {
            body = String(raw[raw.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        // Тип — до тире (если есть)
        var type = body
        if let dashRange = body.range(of: " — ") {
            type = String(body[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            body = String(body[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let dashRange = body.range(of: " - ") {
            type = String(body[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            body = String(body[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return ParsedPlan.Day(index: index, weekday: weekday, type: type, body: body)
    }

    /// "ЗАВТРАК (7:00–8:00): овсянка + яйца"
    private static func parseMeal(_ raw: String) -> ParsedPlan.Meal {
        var name = raw
        var time = ""
        var body = ""

        if let parenStart = raw.firstIndex(of: "("),
           let parenEnd = raw[parenStart...].firstIndex(of: ")") {
            name = String(raw[..<parenStart]).trimmingCharacters(in: .whitespaces)
            time = String(raw[raw.index(after: parenStart)..<parenEnd]).trimmingCharacters(in: .whitespaces)
        }
        if let colon = raw.firstIndex(of: ":") {
            body = String(raw[raw.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        if body.isEmpty { body = name; name = "" }
        return ParsedPlan.Meal(name: name, time: time, body: body)
    }

    /// "ПОДЪЁМ: 6:30" / "СОН: минимум 7–8 часов"
    private static func parseTip(_ raw: String) -> ParsedPlan.Tip {
        if let colon = raw.firstIndex(of: ":") {
            let k = String(raw[..<colon]).trimmingCharacters(in: .whitespaces)
            let v = String(raw[raw.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            return ParsedPlan.Tip(title: k, body: v)
        }
        return ParsedPlan.Tip(title: "", body: raw)
    }
}

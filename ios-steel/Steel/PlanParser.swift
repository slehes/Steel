import Foundation

struct ParsedPlan {
    struct Program {
        let title: String
        let goal: String
        let duration: String
        let level: String
    }

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

            if upper.hasPrefix("ПРОГРАММА") { currentSection = .program; continue }
            if upper.hasPrefix("НЕДЕЛЯ") {
                currentSection = .week
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


    private static func parseDay(_ raw: String) -> ParsedPlan.Day {
        let upper = raw.uppercased()
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
        var weekday = ""
        if let paren = raw.range(of: #"\([А-Яа-я]{2}\)"#, options: .regularExpression) {
            weekday = String(raw[paren])
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .uppercased()
        }
        var body = raw
        if let colon = raw.firstIndex(of: ":") {
            body = String(raw[raw.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
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

    private static func parseTip(_ raw: String) -> ParsedPlan.Tip {
        if let colon = raw.firstIndex(of: ":") {
            let k = String(raw[..<colon]).trimmingCharacters(in: .whitespaces)
            let v = String(raw[raw.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            return ParsedPlan.Tip(title: k, body: v)
        }
        return ParsedPlan.Tip(title: "", body: raw)
    }
}

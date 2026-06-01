import Foundation
import UIKit

struct CommandFeedback {
    let title: String
    let opensBackgroundPicker: Bool

    init(title: String, opensBackgroundPicker: Bool = false) {
        self.title = title
        self.opensBackgroundPicker = opensBackgroundPicker
    }
}

@MainActor
enum CommandExecutor {
    @discardableResult
    static func execute(_ command: AICommand) -> CommandFeedback? {
        let data = DataManager.shared
        switch command {
        case let .addTask(title, amount, unit, icon):
            data.addTask(title: title, amount: amount, unit: unit, iconName: validSymbol(icon))
            return CommandFeedback(title: "Добавлено: \(title)")

        case let .removeTask(title):
            data.removeTask(matching: title)
            return CommandFeedback(title: "Удалено: \(title)")

        case let .addHabit(title, icon):
            data.addHabit(title: title, iconName: validSymbol(icon))
            return CommandFeedback(title: "Привычка: \(title)")

        case let .removeHabit(title):
            data.removeHabit(matching: title)
            return CommandFeedback(title: "Удалено: \(title)")

        case let .setReminder(hours):
            let valid = hours.filter { (0...23).contains($0) }
            guard !valid.isEmpty else { return nil }
            data.updateSettings { $0.reminderHours = valid.sorted() }
            NotificationManager.shared.rescheduleAll()
            return CommandFeedback(title: "Напоминания обновлены")

        case let .buildPlan(plan):
            guard !plan.isEmpty else { return nil }
            let lines = plan.components(separatedBy: "\n")
            let title = lines.first?.trimmingCharacters(in: .whitespaces).prefix(50).description ?? "Тренировочный план"
            data.savePlan(title: title, body: plan)
            return CommandFeedback(title: "План готов")

        case let .changeBackground(action):
            if action.lowercased() == "disable" {
                BackgroundManager.shared.disable()
                return CommandFeedback(title: "Фон отключён")
            }
            return CommandFeedback(title: "Выбери фон", opensBackgroundPicker: true)

        case .scrapeSite:
            return nil
        }
    }

    private static func validSymbol(_ name: String) -> String {
        UIImage(systemName: name) != nil ? name : "checkmark.circle"
    }
}

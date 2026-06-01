import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func rescheduleAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let hours = DataManager.shared.settings.reminderHours
        let tasks = DataManager.shared.fetchTasks()
        let incompleteTasks = tasks.filter { !$0.isCompleted }
        let allDone = !tasks.isEmpty && incompleteTasks.isEmpty

        let incompleteMessage = "У вас еще не все тренировки выполнены"

        if hours.count > 0 {
            let messages = allDone ? ["День закрыт. Отдыхай — завтра новый бой."] : [incompleteMessage]
            scheduleReminder(hour: hours[0], identifier: "steel.reminder.morning", messages: messages)
        }

        if hours.count > 1 {
            let messages = allDone ? ["День закрыт. Отдыхай — завтра новый бой."] : [incompleteMessage]
            scheduleReminder(hour: hours[1], identifier: "steel.reminder.evening", messages: messages)
        }

        if hours.count > 2 {
            let messages = allDone ? ["Красавчик. Серия сохранена. Спокойной ночи."] : [incompleteMessage]
            scheduleReminder(hour: hours[2], identifier: "steel.reminder.night", messages: messages)
        }
    }

    private func scheduleReminder(hour: Int, identifier: String, messages: [String]) {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Steel"
        content.body = messages.randomElement() ?? messages[0]
        content.sound = .default
        content.categoryIdentifier = "STEEL_REMINDER"

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleCustomReminder(seconds: TimeInterval, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Steel"
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "STEEL_CUSTOM"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        let id = "steel.custom.\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleStreakWarningIfNeeded() {
        let tasks = DataManager.shared.fetchTasks()
        let allDone = tasks.isEmpty || tasks.allSatisfy(\.isCompleted)
        if allDone { return }

        let settings = DataManager.shared.settings
        if settings.streakPaused { return }

        let now = Date()
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        guard let warnTime = calendar.date(byAdding: .hour, value: -1, to: midnight),
              warnTime > now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Серия сгорит!"
        content.body = "У вас еще не все тренировки выполнены. Остался 1 час."
        content.sound = .defaultCritical
        content.categoryIdentifier = "STEEL_STREAK_WARNING"

        let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: warnTime), repeats: false)
        let request = UNNotificationRequest(identifier: "steel.streak.warning.\(calendar.startOfDay(for: now).timeIntervalSince1970)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

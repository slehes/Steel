import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let reminderMessages = [
        "Хватит лениться. Тренировка не сделает себя сама.",
        "Тело ждёт нагрузки. Ты ждёшь завтра? Его нет.",
        "Время ковать сталь. Начинай.",
        "День проходит. Задания ждут. Ты — нет?",
        "Каждый пропуск — шаг назад. Шагни вперёд.",
    ]

    private let streakWarningMessages = [
        "Серия под угрозой! Завершить день — 1 нажатие.",
        "Не сдавайся. Серия на кону. Закрой день.",
        "Ещё немного — и серия сгорит. Действуй.",
    ]

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

        if hours.count > 0 {
            scheduleReminder(hour: hours[0], identifier: "steel.reminder.morning", messages: reminderMessages)
        }

        if hours.count > 1 {
            let messages = allDone ? ["День закрыт. Отдыхай — завтра новый бой."] : streakWarningMessages + reminderMessages
            scheduleReminder(hour: hours[1], identifier: "steel.reminder.evening", messages: messages)
        }

        if hours.count > 2 {
            let messages = allDone ? ["Красавчик. Серия сохранена. Спокойной ночи."] : streakWarningMessages
            scheduleReminder(hour: hours[2], identifier: "steel.reminder.night", messages: messages)
        }
    }

    private func scheduleReminder(hour: Int, identifier: String, messages: [String]) {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "⚔️ Steel"
        content.body = messages.randomElement() ?? messages[0]
        content.sound = .default
        content.categoryIdentifier = "STEEL_REMINDER"

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
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
        content.title = "⚠️ Серия сгорит!"
        content.body = "Остался 1 час. Завершить день — 1 нажатие."
        content.sound = .defaultCritical
        content.categoryIdentifier = "STEEL_STREAK_WARNING"

        let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: warnTime), repeats: false)
        let request = UNNotificationRequest(identifier: "steel.streak.warning.\(calendar.startOfDay(for: now).timeIntervalSince1970)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

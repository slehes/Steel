import Foundation
import UserNotifications
import UIKit
import SPIndicator

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

        if hours.count > 0 {
            let messages = allDone
                ? ["День закрыт! Возвращайся завтра за новой серией."]
                : ["Возвращайся заниматься! Тренировки ждут.", "Пора тренироваться! Не сдавайся.", "Давай, пора заняться делом!"]
            scheduleReminder(hour: hours[0], identifier: "steel.reminder.morning", messages: messages)
        }

        if hours.count > 1 {
            let messages = allDone
                ? ["День закрыт! Мини-отдых заслужен.", "Всё выполнено — отдыхай, но не расслабляйся!"]
                : ["Мини-отдых? Не забудь про тренировки!", "Перерыв — это хорошо, но тренировки ждут.", "Ещё не всё сделано — возвращайся!"]
            scheduleReminder(hour: hours[1], identifier: "steel.reminder.evening", messages: messages)
        }

        if hours.count > 2 {
            let messages = allDone
                ? ["Красавчик! Серия сохранена. Спокойной ночи.", "Всё готово на сегодня. Отдыхай — завтра новый бой."]
                : ["Пора отдыхать, но тренировки не выполнены!", "Ночь близко — закрой день тренировками!", "Не сдавайся! Завтра будет сложнее начать заново."]
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

    func scheduleBirthdayNotifications(birthdayString: String) {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard !birthdayString.isEmpty, let date = fmt.date(from: birthdayString) else { return }

        let cal = Calendar.current
        let month = cal.component(.month, from: date)
        let day   = cal.component(.day,   from: date)

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "steel.birthday.midnight", "steel.birthday.noon"
        ])

        for (hour, identifier) in [(0, "steel.birthday.midnight"), (12, "steel.birthday.noon")] {
            let content = UNMutableNotificationContent()
            content.title = "С Днём Рождения! 🎉"
            content.body  = "Сегодня твой праздник — отдыхай без нагрузки. +1 к серии!"
            content.sound = .default
            content.categoryIdentifier = "STEEL_BIRTHDAY"

            var comps = DateComponents()
            comps.month = month; comps.day = day; comps.hour = hour; comps.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    func checkBirthdayAndCongratulate() {
        let settings = DataManager.shared.settings
        guard !settings.birthdayDateString.isEmpty else { return }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let bdate = fmt.date(from: settings.birthdayDateString) else { return }

        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let bMonth = cal.component(.month, from: bdate)
        let bDay   = cal.component(.day,   from: bdate)
        let tMonth = cal.component(.month, from: today)
        let tDay   = cal.component(.day,   from: today)

        guard bMonth == tMonth && bDay == tDay else { return }

        let birthdayKey = "steel.birthday.congratulated.\(fmt.string(from: today))"
        guard !UserDefaults.standard.bool(forKey: birthdayKey) else { return }
        UserDefaults.standard.set(true, forKey: birthdayKey)

        DataManager.shared.awardBirthdayBonus()

        SteelNotificationStore.shared.add(
            type: .birthday,
            title: "С Днём Рождения! 🎉",
            body: "Сегодня твой праздник. +1 к серии начислен. Отдыхай!"
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            SPIndicator.present(
                title: "С Днём Рождения! 🎉",
                message: "Сегодня отдыхай без нагрузки",
                preset: .custom(UIImage(systemName: "gift.fill")!),
                haptic: .success
            )
        }
    }

    func sendCoachNotification(message: String, delay: TimeInterval = 2) {
        let coachMessages = [
            "[Тренер] " + message,
            "[Совет] " + message,
            "[Мотивация] " + message,
            "[От тренера] " + message
        ]
        
        let content = UNMutableNotificationContent()
        content.title = "Сообщение от тренера"
        content.body = coachMessages.randomElement() ?? coachMessages[0]
        content.sound = .default
        content.categoryIdentifier = "STEEL_COACH"
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
        let id = "steel.coach.\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

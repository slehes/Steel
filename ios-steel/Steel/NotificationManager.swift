import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let messages = [
        "Хватит спать. Тело само себя не выкует.",
        "День проходит. Задания ждут. Ты — нет?",
        "Последний шанс закрыть день. Без отмазок.",
    ]

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func rescheduleAll() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: scheduledIdentifiers())

        let hours = DataManager.shared.settings.reminderHours
        for (index, hour) in hours.enumerated() {
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = 0

            let content = UNMutableNotificationContent()
            content.title = "Steel"
            content.body = messages[index % messages.count]
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: "steel.reminder.\(index)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func scheduledIdentifiers() -> [String] {
        (0..<10).map { "steel.reminder.\($0)" }
    }
}

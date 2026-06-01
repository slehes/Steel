import Foundation
import UIKit

enum SteelNotifType: String, Codable {
    case achievement
    case birthday
    case coach
    case system

    var title: String {
        switch self {
        case .achievement: return "Начисление"
        case .birthday:    return "Поздравление"
        case .coach:       return "От тренера"
        case .system:      return "Системное"
        }
    }

    var icon: String {
        switch self {
        case .achievement: return "star.fill"
        case .birthday:    return "gift.fill"
        case .coach:       return "bolt.fill"
        case .system:      return "bell.fill"
        }
    }

    var color: UIColor {
        switch self {
        case .achievement: return .systemYellow
        case .birthday:    return .systemPink
        case .coach:       return .systemBlue
        case .system:      return .systemGray
        }
    }
}

struct SteelLocalNotification: Codable, Identifiable {
    var id: UUID = UUID()
    var type: SteelNotifType
    var title: String
    var body: String
    var date: Date
    var isRead: Bool = false
}

extension Notification.Name {
    static let steelNotificationsChanged = Notification.Name("steel.notificationsChanged")
}

@MainActor
final class SteelNotificationStore {
    static let shared = SteelNotificationStore()
    private let key = "steel.notifications.v1"
    private init() {}

    var all: [SteelLocalNotification] {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([SteelLocalNotification].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(Array(newValue.prefix(200))) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    func add(type: SteelNotifType, title: String, body: String) {
        let notif = SteelLocalNotification(type: type, title: title, body: body, date: Date())
        var current = all
        current.insert(notif, at: 0)
        all = current
        NotificationCenter.default.post(name: .steelNotificationsChanged, object: nil)
    }

    func markAllRead() {
        var current = all
        for i in current.indices { current[i].isRead = true }
        all = current
    }

    var unreadCount: Int { all.filter { !$0.isRead }.count }
}

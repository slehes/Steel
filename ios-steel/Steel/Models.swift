import Foundation
import SwiftData

@Model
final class DailyTask {
    var id: UUID
    var title: String
    var amount: Int
    var unit: String
    var iconName: String
    var isCompleted: Bool
    var sortIndex: Int
    var totalCompletions: Int

    init(title: String, amount: Int, unit: String, iconName: String, sortIndex: Int) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.unit = unit
        self.iconName = iconName
        self.isCompleted = false
        self.sortIndex = sortIndex
        self.totalCompletions = 0
    }

    var displayDetail: String {
        if unit.isEmpty { return "\(amount)" }
        return "\(amount) \(unit)"
    }
}

@Model
final class Habit {
    var id: UUID
    var title: String
    var iconName: String
    var streakStart: Date
    var bestStreak: Int
    var relapseCount: Int
    var sortIndex: Int

    init(title: String, iconName: String, sortIndex: Int) {
        self.id = UUID()
        self.title = title
        self.iconName = iconName
        self.streakStart = Date()
        self.bestStreak = 0
        self.relapseCount = 0
        self.sortIndex = sortIndex
    }

    var cleanDays: Int {
        let comps = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: streakStart), to: Calendar.current.startOfDay(for: Date()))
        return max(0, comps.day ?? 0)
    }

    func relapse() {
        bestStreak = max(bestStreak, cleanDays)
        relapseCount += 1
        streakStart = Date()
    }

    func resetStreak() {
        streakStart = Date()
    }
}

@Model
final class ChatMessageModel {
    var id: UUID
    var text: String
    var isUser: Bool
    var timestamp: Date

    init(text: String, isUser: Bool) {
        self.id = UUID()
        self.text = text
        self.isUser = isUser
        self.timestamp = Date()
    }
}

@Model
final class TrainingPlan {
    var id: UUID
    var title: String
    var body: String
    var updatedAt: Date

    init(title: String, body: String) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.updatedAt = Date()
    }
}

@Model
final class PlanEntry {
    var id: UUID
    var title: String
    var iconName: String
    var isCompleted: Bool
    var createdAt: Date

    init(title: String, iconName: String) {
        self.id = UUID()
        self.title = title
        self.iconName = iconName
        self.isCompleted = false
        self.createdAt = Date()
    }
}

enum BackgroundKind: String, Codable {
    case none
    case photo
    case video
}

struct BackgroundConfig: Codable, Equatable {
    var kind: BackgroundKind
    var fileName: String
    var dimmed: Bool

    static let disabled = BackgroundConfig(kind: .none, fileName: "", dimmed: true)
}

struct AppSettings: Codable {
    var userName: String
    var streakDays: Int
    var lastDayKey: String
    var lastCompletedDayKey: String
    var totalCompletedTasks: Int
    var exerciseCounts: [String: Int]
    var reminderHours: [Int]
    var background: BackgroundConfig
    var customFontFileName: String
    var customFontName: String
    var customFontDisplayName: String
    var streakPaused: Bool
    var streakPausedSince: String
    var regionCity: String
    var regionTimeZone: String
    var userTrainingLocation: String

    static let `default` = AppSettings(
        userName: "Воин",
        streakDays: 0,
        lastDayKey: "",
        lastCompletedDayKey: "",
        totalCompletedTasks: 0,
        exerciseCounts: [:],
        reminderHours: [9, 19, 22],
        background: .disabled,
        customFontFileName: "",
        customFontName: "",
        customFontDisplayName: "",
        streakPaused: false,
        streakPausedSince: "",
        regionCity: "Москва",
        regionTimeZone: "Europe/Moscow",
        userTrainingLocation: ""
    )

    var mostFrequentExercise: String {
        exerciseCounts.max(by: { $0.value < $1.value })?.key ?? "—"
    }
}

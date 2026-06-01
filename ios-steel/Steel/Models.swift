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

    // Memberwise init
    init(kind: BackgroundKind, fileName: String, dimmed: Bool) {
        self.kind = kind
        self.fileName = fileName
        self.dimmed = dimmed
    }

    // Backward-compatible decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(BackgroundKind.self, forKey: .kind) ?? .none
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName) ?? ""
        dimmed = try container.decodeIfPresent(Bool.self, forKey: .dimmed) ?? true
    }

    static let disabled = BackgroundConfig(kind: .none, fileName: "", dimmed: true)
}

struct YearGoal: Codable, Identifiable {
    var id: UUID
    var title: String
    var targetValue: Int
    var currentValue: Int
    var iconName: String
    var deadline: String

    init(title: String, targetValue: Int, iconName: String) {
        self.id = UUID()
        self.title = title
        self.targetValue = targetValue
        self.currentValue = 0
        self.iconName = iconName
        self.deadline = "2026-12-31"
    }

    var progress: Double {
        targetValue > 0 ? min(1, Double(currentValue) / Double(targetValue)) : 0
    }
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
    var yearGoals: [YearGoal]

    // Explicit memberwise init (needed because custom Codable init removes auto-generated one)
    init(
        userName: String,
        streakDays: Int,
        lastDayKey: String,
        lastCompletedDayKey: String,
        totalCompletedTasks: Int,
        exerciseCounts: [String: Int],
        reminderHours: [Int],
        background: BackgroundConfig,
        customFontFileName: String,
        customFontName: String,
        customFontDisplayName: String,
        streakPaused: Bool,
        streakPausedSince: String,
        regionCity: String,
        regionTimeZone: String,
        userTrainingLocation: String,
        yearGoals: [YearGoal]
    ) {
        self.userName = userName
        self.streakDays = streakDays
        self.lastDayKey = lastDayKey
        self.lastCompletedDayKey = lastCompletedDayKey
        self.totalCompletedTasks = totalCompletedTasks
        self.exerciseCounts = exerciseCounts
        self.reminderHours = reminderHours
        self.background = background
        self.customFontFileName = customFontFileName
        self.customFontName = customFontName
        self.customFontDisplayName = customFontDisplayName
        self.streakPaused = streakPaused
        self.streakPausedSince = streakPausedSince
        self.regionCity = regionCity
        self.regionTimeZone = regionTimeZone
        self.userTrainingLocation = userTrainingLocation
        self.yearGoals = yearGoals
    }

    // Backward-compatible decoder: handles missing keys from older app versions
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? "Воин"
        streakDays = try container.decodeIfPresent(Int.self, forKey: .streakDays) ?? 0
        lastDayKey = try container.decodeIfPresent(String.self, forKey: .lastDayKey) ?? ""
        lastCompletedDayKey = try container.decodeIfPresent(String.self, forKey: .lastCompletedDayKey) ?? ""
        totalCompletedTasks = try container.decodeIfPresent(Int.self, forKey: .totalCompletedTasks) ?? 0
        exerciseCounts = try container.decodeIfPresent([String: Int].self, forKey: .exerciseCounts) ?? [:]
        reminderHours = try container.decodeIfPresent([Int].self, forKey: .reminderHours) ?? [9, 19, 22]
        background = try container.decodeIfPresent(BackgroundConfig.self, forKey: .background) ?? .disabled
        customFontFileName = try container.decodeIfPresent(String.self, forKey: .customFontFileName) ?? ""
        customFontName = try container.decodeIfPresent(String.self, forKey: .customFontName) ?? ""
        customFontDisplayName = try container.decodeIfPresent(String.self, forKey: .customFontDisplayName) ?? ""
        streakPaused = try container.decodeIfPresent(Bool.self, forKey: .streakPaused) ?? false
        streakPausedSince = try container.decodeIfPresent(String.self, forKey: .streakPausedSince) ?? ""
        regionCity = try container.decodeIfPresent(String.self, forKey: .regionCity) ?? "Москва"
        regionTimeZone = try container.decodeIfPresent(String.self, forKey: .regionTimeZone) ?? "Europe/Moscow"
        userTrainingLocation = try container.decodeIfPresent(String.self, forKey: .userTrainingLocation) ?? ""
        yearGoals = try container.decodeIfPresent([YearGoal].self, forKey: .yearGoals) ?? []
    }

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
        userTrainingLocation: "",
        yearGoals: []
    )

    var mostFrequentExercise: String {
        exerciseCounts.max(by: { $0.value < $1.value })?.key ?? "—"
    }
}

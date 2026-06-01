import Foundation
import SwiftData
import UIKit
import WidgetKit

extension Notification.Name {
    static let steelTasksChanged = Notification.Name("steel.tasksChanged")
    static let steelHabitsChanged = Notification.Name("steel.habitsChanged")
    static let steelSettingsChanged = Notification.Name("steel.settingsChanged")
    static let steelBackgroundChanged = Notification.Name("steel.backgroundChanged")
    static let steelFontChanged = Notification.Name("steel.fontChanged")

}

@MainActor
final class DataManager {
    static let shared = DataManager()

    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    private let settingsKey = "steel.settings.v1"

    private(set) var settings: AppSettings {
        didSet { persistSettings() }
    }



    private var activeTimeZone: TimeZone {
        TimeZone(identifier: settings.regionTimeZone) ?? TimeZone(identifier: "Europe/Moscow")!
    }

    func setTimeZone(_ tz: TimeZone) {
        mskTimeZone = tz
    }

    private var mskTimeZone: TimeZone = TimeZone(identifier: "Europe/Moscow")!

    private init() {
        let schema = Schema([DailyTask.self, Habit.self, ChatMessageModel.self, TrainingPlan.self, PlanEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer error: \(error)")
        }

        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }
    }

    func bootstrap() {
        mskTimeZone = TimeZone(identifier: settings.regionTimeZone) ?? TimeZone(identifier: "Europe/Moscow")!
        rolloverIfNewDay()
        syncShared()
        LiveActivityController.shared.refresh()
        // Auto-backup on launch
        KeychainHelper.backupAllData()
    }

    func syncShared() {
        let progress = taskProgress
        SharedStore.write(streak: settings.streakDays, done: progress.done, total: progress.total)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
        // Auto-backup to Keychain on every settings change
        KeychainHelper.backupAllData()
    }

    func updateSettings(_ mutate: (inout AppSettings) -> Void) {
        var copy = settings
        mutate(&copy)
        settings = copy
        NotificationCenter.default.post(name: .steelSettingsChanged, object: nil)
    }

    func dayKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = mskTimeZone
        return formatter.string(from: date)
    }

    func currentMSKDate() -> Date {
        let now = Date()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = mskTimeZone
        return cal.startOfDay(for: now)
    }

    func rolloverIfNewDay() {
        let today = dayKey()
        guard settings.lastDayKey != today else { return }

        if !settings.streakPaused {
            let yesterday = dayKey(for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
            if !settings.lastDayKey.isEmpty,
               settings.lastCompletedDayKey != yesterday,
               settings.lastCompletedDayKey != today {
                updateSettings { $0.streakDays = 0 }
            }
        }

        for task in fetchTasks() {
            task.isCompleted = false
        }
        try? context.save()
        updateSettings { $0.lastDayKey = today }
        NotificationCenter.default.post(name: .steelTasksChanged, object: nil)
        LiveActivityController.shared.refresh()
    }

    func fetchTasks() -> [DailyTask] {
        let descriptor = FetchDescriptor<DailyTask>(sortBy: [SortDescriptor(\.sortIndex)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchHabits() -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortIndex)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchMessages() -> [ChatMessageModel] {
        let descriptor = FetchDescriptor<ChatMessageModel>(sortBy: [SortDescriptor(\.timestamp)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func currentPlan() -> TrainingPlan? {
        let descriptor = FetchDescriptor<TrainingPlan>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    func addTask(title: String, amount: Int, unit: String, iconName: String) -> DailyTask {
        let index = (fetchTasks().map(\.sortIndex).max() ?? -1) + 1
        let task = DailyTask(title: title, amount: amount, unit: unit, iconName: iconName, sortIndex: index)
        context.insert(task)
        try? context.save()
        NotificationCenter.default.post(name: .steelTasksChanged, object: nil)
        KeychainHelper.backupAllData()
        return task
    }

    /// Restore task from Keychain backup (no notification to avoid loops)
    func addTaskFromDTO(_ dto: TaskDTO) {
        let index = (fetchTasks().map(\.sortIndex).max() ?? -1) + 1
        let task = DailyTask(title: dto.title, amount: dto.amount, unit: dto.unit, iconName: dto.iconName, sortIndex: index)
        task.isCompleted = dto.isCompleted
        task.totalCompletions = dto.totalCompletions
        context.insert(task)
        try? context.save()
        NotificationCenter.default.post(name: .steelTasksChanged, object: nil)
    }

    func removeTask(_ task: DailyTask) {
        context.delete(task)
        try? context.save()
        NotificationCenter.default.post(name: .steelTasksChanged, object: nil)
        LiveActivityController.shared.refresh()
        syncShared()
        KeychainHelper.backupAllData()
    }

    func removeTask(matching name: String) {
        let lower = name.lowercased()
        for task in fetchTasks() where task.title.lowercased().contains(lower) {
            context.delete(task)
        }
        try? context.save()
        NotificationCenter.default.post(name: .steelTasksChanged, object: nil)
        LiveActivityController.shared.refresh()
        syncShared()
        KeychainHelper.backupAllData()
    }

    /// Toggle task completion
    func toggleTask(_ task: DailyTask) {
        task.isCompleted.toggle()
        if task.isCompleted {
            task.totalCompletions += 1
            updateSettings {
                $0.totalCompletedTasks += 1
                $0.exerciseCounts[task.title, default: 0] += 1
            }
        }
        try? context.save()
        NotificationCenter.default.post(name: .steelTasksChanged, object: nil)
        LiveActivityController.shared.refresh()
        syncShared()
        KeychainHelper.backupAllData()
    }

    func completeDay() {
        let today = dayKey()
        guard settings.lastCompletedDayKey != today else { return }
        updateSettings {
            $0.streakDays += 1
            $0.lastCompletedDayKey = today
        }
        NotificationCenter.default.post(name: .steelTasksChanged, object: nil)
        syncShared()
        KeychainHelper.backupAllData()
    }

    @discardableResult
    func addHabit(title: String, iconName: String) -> Habit {
        let index = (fetchHabits().map(\.sortIndex).max() ?? -1) + 1
        let habit = Habit(title: title, iconName: iconName, sortIndex: index)
        context.insert(habit)
        try? context.save()
        NotificationCenter.default.post(name: .steelHabitsChanged, object: nil)
        KeychainHelper.backupAllData()
        return habit
    }

    /// Restore habit from Keychain backup
    func addHabitFromDTO(_ dto: HabitDTO) {
        let index = (fetchHabits().map(\.sortIndex).max() ?? -1) + 1
        let habit = Habit(title: dto.title, iconName: dto.iconName, sortIndex: index)
        habit.bestStreak = dto.bestStreak
        habit.relapseCount = dto.relapseCount
        habit.streakStart = dto.streakStart
        context.insert(habit)
        try? context.save()
        NotificationCenter.default.post(name: .steelHabitsChanged, object: nil)
    }

    func removeHabit(_ habit: Habit) {
        context.delete(habit)
        try? context.save()
        NotificationCenter.default.post(name: .steelHabitsChanged, object: nil)
        KeychainHelper.backupAllData()
    }

    func removeHabit(matching name: String) {
        let lower = name.lowercased()
        for habit in fetchHabits() where habit.title.lowercased().contains(lower) {
            context.delete(habit)
        }
        try? context.save()
        NotificationCenter.default.post(name: .steelHabitsChanged, object: nil)
        KeychainHelper.backupAllData()
    }

    func savePlan(title: String, body: String) {
        if let existing = currentPlan() {
            existing.title = title
            existing.body = body
            existing.updatedAt = Date()
        } else {
            context.insert(TrainingPlan(title: title, body: body))
        }
        try? context.save()

        // Also parse plan body and create PlanEntry items
        parsePlanEntries(body: body)
    }

    func parsePlanEntries(body: String) {
        // Parse lines from plan body — each line that starts with bullet/dash/number is an entry
        let lines = body.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  trimmed.count > 3,
                  !trimmed.lowercased().contains("день") || trimmed.contains("1.") || trimmed.contains("2.") || trimmed.contains("3.") || trimmed.contains("4.") || trimmed.contains("5.")
            else { continue }

            // Strip numbers, bullets, dashes from beginning
            let cleaned = trimmed
                .replacingOccurrences(of: "^\\d+[.)].*", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            guard !cleaned.isEmpty else { continue }

            let icon = iconForEntry(cleaned)
            let entry = PlanEntry(title: cleaned, iconName: icon)
            context.insert(entry)
        }
        try? context.save()
        NotificationCenter.default.post(name: .steelTasksChanged, object: nil)
    }

    private func iconForEntry(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("отжима") || lower.contains("push") { return "figure.strengthtraining.traditional" }
        if lower.contains("приседа") || lower.contains("squat") { return "figure.walk" }
        if lower.contains("планк") || lower.contains("plank") { return "figure.core.training" }
        if lower.contains("бег") || lower.contains("run") { return "figure.run" }
        if lower.contains("пресс") || lower.contains("скручи") { return "figure.core.training" }
        if lower.contains("бёрпи") || lower.contains("burpee") { return "figure.mixed.cardio" }
        if lower.contains("выпад") || lower.contains("lunge") { return "figure.arms.raised" }
        if lower.contains("растяжк") || lower.contains("stretch") { return "figure.flexibility" }
        if lower.contains("жим") || lower.contains("bench") { return "dumbbell.fill" }
        if lower.contains("подтягив") || lower.contains("pull") { return "figure.arms.raised" }
        if lower.contains("скакалк") || lower.contains("jump") { return "figure.play" }
        return "bolt.fill"
    }

    func addMessage(_ text: String, isUser: Bool) {
        context.insert(ChatMessageModel(text: text, isUser: isUser))
        try? context.save()
    }

    var taskProgress: (done: Int, total: Int) {
        let tasks = fetchTasks()
        return (tasks.filter(\.isCompleted).count, tasks.count)
    }

    /// Get motivational message based on current progress
    var motivationalMessage: String {
        let messages = [
            "Каждый шаг — победа!",
            "Дисциплина — свобода!",
            "Ты сильнее чем думаешь!",
            "Один день за раз!",
            "Сталь крепка в огне!",
            "Не сдавайся — ты уже ближе!",
            "Боль — это слабость, уходящая из тела!",
        ]
        let progress = taskProgress
        if progress.total == 0 {
            return messages.randomElement() ?? messages[0]
        }
        if progress.done == progress.total {
            return "Идеальный день! Ты машина!"
        }
        if progress.done > 0 {
            return "Отличный старт! Продолжай!"
        }
        return messages.randomElement() ?? messages[0]
    }
}

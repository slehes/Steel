import Foundation
import SwiftData
import UIKit
import WidgetKit

extension Notification.Name {
    static let steelTasksChanged = Notification.Name("steel.tasksChanged")
    static let steelHabitsChanged = Notification.Name("steel.habitsChanged")
    static let steelSettingsChanged = Notification.Name("steel.settingsChanged")
    static let steelBackgroundChanged = Notification.Name("steel.backgroundChanged")
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

    private init() {
        let schema = Schema([DailyTask.self, Habit.self, ChatMessageModel.self, TrainingPlan.self])
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
        seedIfNeeded()
        rolloverIfNewDay()
        syncShared()
        LiveActivityController.shared.refresh()
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
    }

    func updateSettings(_ mutate: (inout AppSettings) -> Void) {
        var copy = settings
        mutate(&copy)
        settings = copy
        NotificationCenter.default.post(name: .steelSettingsChanged, object: nil)
    }

    private func dayKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func rolloverIfNewDay() {
        let today = dayKey()
        guard settings.lastDayKey != today else { return }

        let yesterday = dayKey(for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        if !settings.lastDayKey.isEmpty,
           settings.lastCompletedDayKey != yesterday,
           settings.lastCompletedDayKey != today {
            updateSettings { $0.streakDays = 0 }
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
        return task
    }

    func removeTask(_ task: DailyTask) {
        context.delete(task)
        try? context.save()
        NotificationCenter.default.post(name: .steelTasksChanged, object: nil)
        LiveActivityController.shared.refresh()
        syncShared()
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
    }

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
    }

    @discardableResult
    func addHabit(title: String, iconName: String) -> Habit {
        let index = (fetchHabits().map(\.sortIndex).max() ?? -1) + 1
        let habit = Habit(title: title, iconName: iconName, sortIndex: index)
        context.insert(habit)
        try? context.save()
        NotificationCenter.default.post(name: .steelHabitsChanged, object: nil)
        return habit
    }

    func removeHabit(_ habit: Habit) {
        context.delete(habit)
        try? context.save()
        NotificationCenter.default.post(name: .steelHabitsChanged, object: nil)
    }

    func removeHabit(matching name: String) {
        let lower = name.lowercased()
        for habit in fetchHabits() where habit.title.lowercased().contains(lower) {
            context.delete(habit)
        }
        try? context.save()
        NotificationCenter.default.post(name: .steelHabitsChanged, object: nil)
    }

    func savePlan(_ body: String) {
        if let existing = currentPlan() {
            existing.body = body
            existing.updatedAt = Date()
        } else {
            context.insert(TrainingPlan(body: body))
        }
        try? context.save()
    }

    func addMessage(_ text: String, isUser: Bool) {
        context.insert(ChatMessageModel(text: text, isUser: isUser))
        try? context.save()
    }

    var taskProgress: (done: Int, total: Int) {
        let tasks = fetchTasks()
        return (tasks.filter(\.isCompleted).count, tasks.count)
    }

    private func seedIfNeeded() {
        guard fetchTasks().isEmpty else { return }
        let seedTasks: [(String, Int, String, String)] = [
            ("Отжимания", 50, "раз", "figure.strengthtraining.traditional"),
            ("Приседания", 100, "раз", "figure.cross.training"),
            ("Пресс", 100, "раз", "figure.core.training"),
            ("Планка", 2, "мин", "figure.mind.and.body"),
            ("Брусья", 15, "раз", "figure.play"),
            ("Вода", 2, "л", "drop.fill"),
        ]
        for (i, t) in seedTasks.enumerated() {
            context.insert(DailyTask(title: t.0, amount: t.1, unit: t.2, iconName: t.3, sortIndex: i))
        }

        let seedHabits: [(String, String)] = [
            ("Мастурбация", "hand.raised.slash"),
            ("Сахар", "cube"),
            ("Соцсети", "iphone.slash"),
            ("Курение", "smoke"),
            ("Алкоголь", "wineglass"),
            ("Фастфуд", "takeoutbag.and.cup.and.straw"),
            ("Ногти", "hand.point.up.braille"),
            ("Мат", "exclamationmark.bubble"),
            ("Поздний подъём", "alarm"),
            ("Комп/телефон", "desktopcomputer"),
        ]
        for (i, h) in seedHabits.enumerated() {
            context.insert(Habit(title: h.0, iconName: h.1, sortIndex: i))
        }
        try? context.save()
    }
}

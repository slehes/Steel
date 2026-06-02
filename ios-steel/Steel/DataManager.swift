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
            // If ModelContainer fails (e.g. schema migration), delete corrupt DB and retry
            print("⚠️ ModelContainer error: \(error). Resetting database.")
            Self.deleteDatabase()
            do {
                container = try ModelContainer(for: schema, configurations: [config])
            } catch {
                // Last resort: in-memory container so app doesn't crash
                print("⚠️ ModelContainer still failing after reset. Using in-memory store.")
                let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do {
                    container = try ModelContainer(for: schema, configurations: [memConfig])
                } catch {
                    fatalError("ModelContainer unrecoverable error: \(error)")
                }
            }
        }

        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }
    }

    /// Delete the SwiftData database files so they can be recreated cleanly
    private static func deleteDatabase() {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let defaultDir = url.appendingPathComponent("default.store")
        let files = ["default.store", "default.store-wal", "default.store-shm"]
        for file in files {
            let fileURL = defaultDir.deletingLastPathComponent().appendingPathComponent(file)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    func bootstrap() {
        mskTimeZone = TimeZone(identifier: settings.regionTimeZone) ?? TimeZone(identifier: "Europe/Moscow")!
        rolloverIfNewDay()
        syncShared()
        LiveActivityController.shared.refresh()
        KeychainHelper.backupAllData()
        seedInitialDataIfNeeded()
    }

    private let seedVersionKey = "steel.seed.version"
    private let currentSeedVersion = 2

    private func seedInitialDataIfNeeded() {
        let storedVersion = UserDefaults.standard.integer(forKey: seedVersionKey)
        guard storedVersion < currentSeedVersion else { return }

        // Wipe previous data for clean reseed
        fetchHabits().forEach { context.delete($0) }
        fetchTasks().forEach { context.delete($0) }
        try? context.save()

        let cal = Calendar.current
        func daysAgo(_ n: Int) -> Date {
            cal.date(byAdding: .day, value: -n, to: cal.startOfDay(for: Date())) ?? Date()
        }

        // Вредные привычки — отказываемся
        let badSeeds: [(String, String, Int)] = [
            ("18+ контент",    "hand.raised.slash.fill",  7),
            ("Алкоголь",       "wineglass.slash.fill",   25),
            ("Телефон с утра", "iphone.slash",           12),
            ("Грызть губы",    "mouth.fill",             19),
        ]
        for (i, s) in badSeeds.enumerated() {
            let h = Habit(title: s.0, iconName: s.1, category: .bad, sortIndex: i)
            h.streakStart = daysAgo(s.2)
            context.insert(h)
        }

        // Полезные привычки — формируем
        let goodSeeds: [(String, String, Int)] = [
            ("Кофе",                 "cup.and.saucer.fill",  4),
            ("2 л воды",             "drop.fill",            9),
            ("Ранний подъём",        "sunrise.fill",         3),
            ("Растяжка",             "figure.flexibility",  14),
            ("No shopping",          "bag.badge.minus",      1),
            ("Интернет после трень", "wifi.slash",           6),
            ("Ледяная маска",        "snowflake",           11),
            ("Дневник целей",        "book.closed.fill",     2),
        ]
        for (i, s) in goodSeeds.enumerated() {
            let h = Habit(title: s.0, iconName: s.1, category: .good, sortIndex: i + badSeeds.count)
            h.streakStart = daysAgo(s.2)
            context.insert(h)
        }

        // Ежедневные задачи — зарядка
        let taskSeeds: [(String, Int, String, String)] = [
            ("Отжимания", 50, "раз", "figure.strengthtraining.traditional"),
            ("Пресс",     50, "раз", "figure.core.training"),
        ]
        for (i, t) in taskSeeds.enumerated() {
            let task = DailyTask(title: t.0, amount: t.1, unit: t.2, iconName: t.3, sortIndex: i)
            context.insert(task)
        }

        try? context.save()
        updateSettings { $0.streakDays = 15 }
        UserDefaults.standard.set(currentSeedVersion, forKey: seedVersionKey)

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .steelHabitsChanged, object: nil)
            NotificationCenter.default.post(name: .steelTasksChanged, object: nil)
            KeychainHelper.backupAllData()
        }
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
    func addHabit(title: String, iconName: String, category: HabitCategory = .bad) -> Habit {
        let index = (fetchHabits().map(\.sortIndex).max() ?? -1) + 1
        let habit = Habit(title: title, iconName: iconName, category: category, sortIndex: index)
        context.insert(habit)
        do {
            try context.save()
        } catch {
            print("⚠️ Error saving habit: \(error)")
        }
        // Откладываем уведомление на следующую итерацию RunLoop,
        // чтобы SwiftData завершил вставку до того, как VC попытается прочитать данные
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .steelHabitsChanged, object: nil)
            KeychainHelper.backupAllData()
        }
        return habit
    }

    /// Restore habit from Keychain backup
    func addHabitFromDTO(_ dto: HabitDTO) {
        let index = (fetchHabits().map(\.sortIndex).max() ?? -1) + 1
        let category = HabitCategory(rawValue: dto.categoryRaw) ?? .bad
        let habit = Habit(title: dto.title, iconName: dto.iconName, category: category, sortIndex: index)
        habit.bestStreak = dto.bestStreak
        habit.relapseCount = dto.relapseCount
        habit.streakStart = dto.streakStart
        context.insert(habit)
        try? context.save()
        NotificationCenter.default.post(name: .steelHabitsChanged, object: nil)
    }

    /// Привычки разбитые по категориям. Полезные идут первыми — они позитивные,
    /// вредные следом — это «от чего отказываемся».
    func fetchHabitsGrouped() -> (good: [Habit], bad: [Habit]) {
        let all = fetchHabits()
        return (
            good: all.filter { $0.category == .good },
            bad:  all.filter { $0.category == .bad }
        )
    }

    func removeHabit(_ habit: Habit) {
        context.delete(habit)
        do {
            try context.save()
        } catch {
            print("⚠️ Error deleting habit: \(error)")
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .steelHabitsChanged, object: nil)
            KeychainHelper.backupAllData()
        }
    }

    func removeHabit(matching name: String) {
        let lower = name.lowercased()
        for habit in fetchHabits() where habit.title.lowercased().contains(lower) {
            context.delete(habit)
        }
        do {
            try context.save()
        } catch {
            print("⚠️ Error deleting habits: \(error)")
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .steelHabitsChanged, object: nil)
            KeychainHelper.backupAllData()
        }
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
        // Парсим структурированный план:
        // - Пропускаем служебные заголовки (ПРОГРАММА, ЦЕЛЬ, ДЛИТЕЛЬНОСТЬ, УРОВЕНЬ,
        //   НЕДЕЛЯ X, ПИТАНИЕ, РЕЖИМ ДНЯ, ВОССТАНОВЛЕНИЕ).
        // - Из строк "- ДЕНЬ 1 (ПН): силовая — 50 отжиманий, 30 приседаний" берём
        //   только тренировочную часть (после тире).
        // - Из секции ПИТАНИЕ создаём записи с иконкой вилки.
        let lines = body.components(separatedBy: "\n")

        let sectionHeaders: [String] = [
            "ПРОГРАММА", "ЦЕЛЬ", "ДЛИТЕЛЬНОСТЬ", "УРОВЕНЬ",
            "НЕДЕЛЯ", "ПИТАНИЕ", "РЕЖИМ ДНЯ", "ВОССТАНОВЛЕНИЕ"
        ]

        var inNutrition = false
        var inSchedule = false

        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Заголовки секций
            let upper = trimmed.uppercased()
            if sectionHeaders.contains(where: { upper.hasPrefix($0) }) {
                inNutrition = upper.hasPrefix("ПИТАНИЕ")
                inSchedule  = upper.hasPrefix("РЕЖИМ ДНЯ")
                continue
            }

            // Ожидаем строку вида "- ДЕНЬ 1 (ПН): <что делаем>"
            guard trimmed.hasPrefix("-") || trimmed.hasPrefix("•") else { continue }
            let withoutBullet = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
            guard !withoutBullet.isEmpty else { continue }

            // Убираем префиксы ДЕНЬ N (ДН):
            var title = withoutBullet
            if let range = title.range(of: ":") {
                let after = title[range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !after.isEmpty { title = after }
            }

            // Убираем « — » и берём хвост после тире
            if let dashRange = title.range(of: " — ") {
                title = String(title[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else if let dashRange = title.range(of: " - ") {
                title = String(title[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            }

            // Ограничиваем длину для отображения
            if title.count > 120 { title = String(title.prefix(120)) + "…" }
            guard title.count > 3 else { continue }

            let icon: String
            if inNutrition {
                icon = "fork.knife"
            } else if inSchedule {
                icon = "clock.fill"
            } else {
                icon = iconForEntry(title)
            }
            let entry = PlanEntry(title: title, iconName: icon)
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

    func awardBirthdayBonus() {
        updateSettings { $0.streakDays += 1 }
        for habit in fetchHabits() where habit.category == .good {
            habit.resetStreak()
        }
        try? context.save()
        SteelNotificationStore.shared.add(
            type: .achievement,
            title: "+1 к серии",
            body: "Бонус за день рождения начислен!"
        )
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

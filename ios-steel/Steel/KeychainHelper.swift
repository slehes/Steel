import Foundation
import KeychainSwift

@MainActor
enum KeychainHelper {
    private static let keychain = KeychainSwift()
    private static let groqKeyName = "steel.groq.apiKey"
    private static let geminiKeyName = "steel.gemini.apiKey"
    private static let bgConfigKey = "steel.background.config"
    private static let bgImageDataKey = "steel.background.imageData"

    private static let settingsBackupKey = "steel.backup.settings"
    private static let tasksBackupKey = "steel.backup.tasks"
    private static let habitsBackupKey = "steel.backup.habits"
    private static let avatarBackupKey = "steel.backup.avatar"

    private static let userIDKey = "steel.user.uuid"

    static func bootstrap() {
        restoreBackgroundIfNeeded()
        restoreAllDataIfNeeded()
    }


    static var userID: String {
        if let existing = keychain.get(userIDKey), !existing.isEmpty { return existing }
        let newID = generateUserID()
        keychain.set(newID, forKey: userIDKey)
        return newID
    }

    static var formattedUserID: String {
        let id = userID
        guard id.count == 12 else { return id }
        let a = id.prefix(4)
        let b = id.dropFirst(4).prefix(4)
        let c = id.suffix(4)
        return "\(a)-\(b)-\(c)"
    }

    static func setUserID(_ id: String) {
        keychain.set(id, forKey: userIDKey)
    }

    private static func generateUserID() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<12).map { _ in chars.randomElement()! })
    }

    static var groqAPIKey: String {
        keychain.get(groqKeyName) ?? ""
    }

    static func setGroqAPIKey(_ key: String) {
        keychain.set(key, forKey: groqKeyName)
    }

    static var geminiAPIKey: String {
        keychain.get(geminiKeyName) ?? ""
    }

    static func setGeminiAPIKey(_ key: String) {
        keychain.set(key, forKey: geminiKeyName)
    }


    static func saveBackgroundToKeychain(config: BackgroundConfig, imageData: Data?) {
        if let configData = try? JSONEncoder().encode(config) {
            keychain.set(configData, forKey: bgConfigKey)
        }
        if let imageData = imageData {
            keychain.set(imageData, forKey: bgImageDataKey)
        } else {
            keychain.delete(bgImageDataKey)
        }
    }

    static var savedBackgroundConfig: BackgroundConfig? {
        guard let data = keychain.getData(bgConfigKey),
              let config = try? JSONDecoder().decode(BackgroundConfig.self, from: data) else {
            return nil
        }
        return config
    }

    static var savedBackgroundImageData: Data? {
        keychain.getData(bgImageDataKey)
    }

    static func clearBackgroundFromKeychain() {
        keychain.delete(bgConfigKey)
        keychain.delete(bgImageDataKey)
    }

    private static func restoreBackgroundIfNeeded() {
        guard let config = savedBackgroundConfig else { return }

        if !config.fileName.isEmpty {
            let fileURL = BackgroundManager.backgroundsDirectory.appendingPathComponent(config.fileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return
            }

            if config.kind == .photo, let imageData = savedBackgroundImageData {
                try? imageData.write(to: fileURL, options: .atomic)
                DataManager.shared.updateSettings { $0.background = config }
                NotificationCenter.default.post(name: .steelBackgroundChanged, object: nil)
            } else {
                clearBackgroundFromKeychain()
            }
        }
    }


    static func backupAllData() {
        if let settingsData = try? JSONEncoder().encode(DataManager.shared.settings) {
            keychain.set(settingsData, forKey: settingsBackupKey)
        }

        let tasks = DataManager.shared.fetchTasks()
        let taskDTOs = tasks.map { TaskDTO(from: $0) }
        if let tasksData = try? JSONEncoder().encode(taskDTOs) {
            keychain.set(tasksData, forKey: tasksBackupKey)
        }

        let habits = DataManager.shared.fetchHabits()
        let habitDTOs = habits.map { HabitDTO(from: $0) }
        if let habitsData = try? JSONEncoder().encode(habitDTOs) {
            keychain.set(habitsData, forKey: habitsBackupKey)
        }
    }

    static func saveAvatarToKeychain(_ imageData: Data) {
        keychain.set(imageData, forKey: avatarBackupKey)
    }

    static var savedAvatarData: Data? {
        keychain.getData(avatarBackupKey)
    }

    static func clearAvatarFromKeychain() {
        keychain.delete(avatarBackupKey)
    }

    private static func restoreAllDataIfNeeded() {
        let existingTasks = DataManager.shared.fetchTasks()
        let existingHabits = DataManager.shared.fetchHabits()

        if existingTasks.isEmpty, let tasksData = keychain.getData(tasksBackupKey),
           let taskDTOs = try? JSONDecoder().decode([TaskDTO].self, from: tasksData) {
            for dto in taskDTOs {
                DataManager.shared.addTaskFromDTO(dto)
            }
        }

        if existingHabits.isEmpty, let habitsData = keychain.getData(habitsBackupKey),
           let habitDTOs = try? JSONDecoder().decode([HabitDTO].self, from: habitsData) {
            for dto in habitDTOs {
                DataManager.shared.addHabitFromDTO(dto)
            }
        }

        if let settingsData = keychain.getData(settingsBackupKey),
           let backupSettings = try? JSONDecoder().decode(AppSettings.self, from: settingsData) {
            DataManager.shared.updateSettings {
                $0.totalCompletedTasks = backupSettings.totalCompletedTasks
                $0.exerciseCounts = backupSettings.exerciseCounts
                $0.streakDays = backupSettings.streakDays
                $0.lastCompletedDayKey = backupSettings.lastCompletedDayKey
                $0.lastDayKey = backupSettings.lastDayKey
                $0.userName = backupSettings.userName
                $0.streakPaused = backupSettings.streakPaused
                $0.streakPausedSince = backupSettings.streakPausedSince
                $0.regionCity = backupSettings.regionCity
                $0.regionTimeZone = backupSettings.regionTimeZone
                $0.userTrainingLocation = backupSettings.userTrainingLocation
                $0.reminderHours = backupSettings.reminderHours
                if backupSettings.background.kind != .none {
                    $0.background = backupSettings.background
                }
            }
        }
    }
}


struct TaskDTO: Codable {
    let title: String
    let amount: Int
    let unit: String
    let iconName: String
    let isCompleted: Bool
    let totalCompletions: Int

    init(from task: DailyTask) {
        self.title = task.title
        self.amount = task.amount
        self.unit = task.unit
        self.iconName = task.iconName
        self.isCompleted = task.isCompleted
        self.totalCompletions = task.totalCompletions
    }
}

struct HabitDTO: Codable {
    let title: String
    let iconName: String
    let bestStreak: Int
    let relapseCount: Int
    let streakStart: Date
    let categoryRaw: String
    let lastMarkedDate: Date?

    init(from habit: Habit) {
        self.title = habit.title
        self.iconName = habit.iconName
        self.bestStreak = habit.bestStreak
        self.relapseCount = habit.relapseCount
        self.streakStart = habit.streakStart
        self.categoryRaw = (habit.categoryRaw?.isEmpty ?? true) ? HabitCategory.bad.rawValue : habit.categoryRaw!
        self.lastMarkedDate = habit.lastMarkedDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        iconName = try container.decode(String.self, forKey: .iconName)
        bestStreak = try container.decode(Int.self, forKey: .bestStreak)
        relapseCount = try container.decode(Int.self, forKey: .relapseCount)
        streakStart = try container.decode(Date.self, forKey: .streakStart)
        categoryRaw = try container.decodeIfPresent(String.self, forKey: .categoryRaw) ?? HabitCategory.bad.rawValue
        lastMarkedDate = try container.decodeIfPresent(Date.self, forKey: .lastMarkedDate)
    }
}

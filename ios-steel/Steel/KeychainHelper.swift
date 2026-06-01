import Foundation
import KeychainSwift

enum KeychainHelper {
    private static let keychain = KeychainSwift()
    private static let groqKeyName = "steel.groq.apiKey"
    private static let geminiKeyName = "steel.gemini.apiKey"
    private static let bgConfigKey = "steel.background.config"
    private static let bgImageDataKey = "steel.background.imageData"

    // Full data backup keys
    private static let settingsBackupKey = "steel.backup.settings"
    private static let tasksBackupKey = "steel.backup.tasks"
    private static let habitsBackupKey = "steel.backup.habits"
    private static let avatarBackupKey = "steel.backup.avatar"

    static func bootstrap() {
        restoreBackgroundIfNeeded()
        restoreAllDataIfNeeded()
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

    // MARK: - Background Persistence (survives reinstall)

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

    // MARK: - Full Data Backup (survives reinstall)

    /// Backup all app data to Keychain so it survives app deletion and reinstall
    static func backupAllData() {
        // Backup settings
        if let settingsData = try? JSONEncoder().encode(DataManager.shared.settings) {
            keychain.set(settingsData, forKey: settingsBackupKey)
        }

        // Backup tasks
        let tasks = DataManager.shared.fetchTasks()
        let taskDTOs = tasks.map { TaskDTO(from: $0) }
        if let tasksData = try? JSONEncoder().encode(taskDTOs) {
            keychain.set(tasksData, forKey: tasksBackupKey)
        }

        // Backup habits
        let habits = DataManager.shared.fetchHabits()
        let habitDTOs = habits.map { HabitDTO(from: $0) }
        if let habitsData = try? JSONEncoder().encode(habitDTOs) {
            keychain.set(habitsData, forKey: habitsBackupKey)
        }
    }

    /// Save avatar image data to Keychain
    static func saveAvatarToKeychain(_ imageData: Data) {
        keychain.set(imageData, forKey: avatarBackupKey)
    }

    /// Get saved avatar image data from Keychain
    static var savedAvatarData: Data? {
        keychain.getData(avatarBackupKey)
    }

    /// Clear avatar from Keychain
    static func clearAvatarFromKeychain() {
        keychain.delete(avatarBackupKey)
    }

    /// Restore all data from Keychain if SwiftData is empty (after reinstall)
    private static func restoreAllDataIfNeeded() {
        let existingTasks = DataManager.shared.fetchTasks()
        let existingHabits = DataManager.shared.fetchHabits()

        // Only restore if data is empty (fresh install) and backup exists
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

        // Restore settings if backup exists — ALWAYS restore streak/series data
        // This ensures streak survives reinstall regardless of current SwiftData state
        if let settingsData = keychain.getData(settingsBackupKey),
           let backupSettings = try? JSONDecoder().decode(AppSettings.self, from: settingsData) {
            // Always restore streak, completed tasks, exercise counts, user profile
            // This ensures series (streakDays) survives app deletion + reinstall
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

// MARK: - Data Transfer Objects for Keychain backup

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

    init(from habit: Habit) {
        self.title = habit.title
        self.iconName = habit.iconName
        self.bestStreak = habit.bestStreak
        self.relapseCount = habit.relapseCount
        self.streakStart = habit.streakStart
        // Поддержка бэкапов, сделанных до введения категорий
        self.categoryRaw = (habit.categoryRaw?.isEmpty ?? true) ? HabitCategory.bad.rawValue : habit.categoryRaw!
    }

    // Backward-compatible decoder: handles old backups without categoryRaw
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        iconName = try container.decode(String.self, forKey: .iconName)
        bestStreak = try container.decode(Int.self, forKey: .bestStreak)
        relapseCount = try container.decode(Int.self, forKey: .relapseCount)
        streakStart = try container.decode(Date.self, forKey: .streakStart)
        categoryRaw = try container.decodeIfPresent(String.self, forKey: .categoryRaw) ?? HabitCategory.bad.rawValue
    }
}

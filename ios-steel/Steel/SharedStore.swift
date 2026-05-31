import Foundation

enum SharedStore {
    static let suiteName = "group.app.rork.vom4oe9mcqwy169rv59jm"
    private static let streakKey = "shared.streak"
    private static let doneKey = "shared.done"
    private static let totalKey = "shared.total"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    static func write(streak: Int, done: Int, total: Int) {
        defaults?.set(streak, forKey: streakKey)
        defaults?.set(done, forKey: doneKey)
        defaults?.set(total, forKey: totalKey)
    }

    static var streak: Int { defaults?.integer(forKey: streakKey) ?? 0 }
    static var done: Int { defaults?.integer(forKey: doneKey) ?? 0 }
    static var total: Int { defaults?.integer(forKey: totalKey) ?? 0 }
}

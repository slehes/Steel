import Foundation
import KeychainSwift

enum KeychainHelper {
    private static let keychain = KeychainSwift()
    private static let groqKeyName = "steel.groq.apiKey"
    private static let geminiKeyName = "steel.gemini.apiKey"
    private static let bgConfigKey = "steel.background.config"
    private static let bgImageDataKey = "steel.background.imageData"

    static func bootstrap() {
        restoreBackgroundIfNeeded()
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

    /// Save background config and image data to Keychain
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

    /// Get saved background config from Keychain
    static var savedBackgroundConfig: BackgroundConfig? {
        guard let data = keychain.getData(bgConfigKey),
              let config = try? JSONDecoder().decode(BackgroundConfig.self, from: data) else {
            return nil
        }
        return config
    }

    /// Get saved background image data from Keychain
    static var savedBackgroundImageData: Data? {
        keychain.getData(bgImageDataKey)
    }

    /// Clear background data from Keychain
    static func clearBackgroundFromKeychain() {
        keychain.delete(bgConfigKey)
        keychain.delete(bgImageDataKey)
    }

    /// Restore background from Keychain if file was lost (e.g. after reinstall)
    private static func restoreBackgroundIfNeeded() {
        guard let config = savedBackgroundConfig else { return }

        // Check if file already exists
        if !config.fileName.isEmpty {
            let fileURL = BackgroundManager.backgroundsDirectory.appendingPathComponent(config.fileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return // File exists, no need to restore
            }

            // File missing - restore from Keychain image data
            if config.kind == .photo, let imageData = savedBackgroundImageData {
                try? imageData.write(to: fileURL, options: .atomic)
                // Restore config to UserDefaults
                DataManager.shared.updateSettings { $0.background = config }
                NotificationCenter.default.post(name: .steelBackgroundChanged, object: nil)
            } else {
                // Video or missing data - can't restore, clear
                clearBackgroundFromKeychain()
            }
        }
    }
}

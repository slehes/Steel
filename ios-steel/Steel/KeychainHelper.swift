import Foundation
import KeychainSwift

enum KeychainHelper {
    private static let keychain = KeychainSwift()
    private static let groqKeyName = "steel.groq.apiKey"
    private static let geminiKeyName = "steel.gemini.apiKey"

    static func bootstrap() {}

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
}

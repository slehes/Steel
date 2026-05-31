import Foundation
import KeychainSwift

enum KeychainHelper {
    private static let keychain = KeychainSwift()
    private static let groqKeyName = "steel.groq.apiKey"

    static func bootstrap() {
        // API key should be set by user on first launch
    }

    static var groqAPIKey: String {
        keychain.get(groqKeyName) ?? ""
    }

    static func setGroqAPIKey(_ key: String) {
        keychain.set(key, forKey: groqKeyName)
    }
}

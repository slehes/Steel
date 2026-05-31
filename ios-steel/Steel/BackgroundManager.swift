import UIKit
import AVFoundation

@MainActor
final class BackgroundManager {
    static let shared = BackgroundManager()
    private init() {}

    static var backgroundsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Backgrounds", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    var config: BackgroundConfig { DataManager.shared.settings.background }

    func fileURL(for config: BackgroundConfig) -> URL? {
        guard !config.fileName.isEmpty else { return nil }
        return Self.backgroundsDirectory.appendingPathComponent(config.fileName)
    }

    func setPhoto(_ image: UIImage, screenSize: CGSize, dimmed: Bool) -> Bool {
        let fileName = "bg_\(UUID().uuidString).jpg"
        let processed = MediaProcessor.processImage(image, targetSize: screenSize)
        guard MediaProcessor.saveImage(processed, fileName: fileName) else { return false }
        clearOldFiles(except: fileName)
        let newConfig = BackgroundConfig(kind: .photo, fileName: fileName, dimmed: dimmed)
        DataManager.shared.updateSettings {
            $0.background = newConfig
        }

        // Save to Keychain for persistence across reinstalls
        if let imageData = processed.jpegData(compressionQuality: 0.85) {
            KeychainHelper.saveBackgroundToKeychain(config: newConfig, imageData: imageData)
        }

        NotificationCenter.default.post(name: .steelBackgroundChanged, object: nil)
        return true
    }

    func setVideo(sourceURL: URL, dimmed: Bool) async -> Bool {
        let fileName = "bg_\(UUID().uuidString).mp4"
        let success = await MediaProcessor.processVideo(sourceURL: sourceURL, fileName: fileName)
        guard success else { return false }
        clearOldFiles(except: fileName)
        let newConfig = BackgroundConfig(kind: .video, fileName: fileName, dimmed: dimmed)
        DataManager.shared.updateSettings {
            $0.background = newConfig
        }

        // Save config to Keychain (video data too large for Keychain)
        KeychainHelper.saveBackgroundToKeychain(config: newConfig, imageData: nil)

        NotificationCenter.default.post(name: .steelBackgroundChanged, object: nil)
        return true
    }

    func disable() {
        clearOldFiles(except: nil)
        DataManager.shared.updateSettings { $0.background = .disabled }

        // Clear from Keychain
        KeychainHelper.clearBackgroundFromKeychain()

        NotificationCenter.default.post(name: .steelBackgroundChanged, object: nil)
    }

    func setDimmed(_ dimmed: Bool) {
        DataManager.shared.updateSettings { $0.background.dimmed = dimmed }

        // Update Keychain config
        KeychainHelper.saveBackgroundToKeychain(config: DataManager.shared.settings.background, imageData: KeychainHelper.savedBackgroundImageData)

        NotificationCenter.default.post(name: .steelBackgroundChanged, object: nil)
    }

    private func clearOldFiles(except keep: String?) {
        let dir = Self.backgroundsDirectory
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        for file in files where file != keep {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
        }
    }
}

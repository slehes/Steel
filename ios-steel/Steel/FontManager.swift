import UIKit
import CoreText

@MainActor
final class FontManager {
    static let shared = FontManager()
    private init() {}

    static let fontsDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Fonts", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    var currentFontName: String {
        DataManager.shared.settings.customFontName
    }

    var currentDisplayName: String {
        let settings = DataManager.shared.settings
        return settings.customFontDisplayName.isEmpty ? "Системный" : settings.customFontDisplayName
    }

    var hasCustomFont: Bool {
        !DataManager.shared.settings.customFontFileName.isEmpty
    }

    func installFont(from url: URL, displayName: String) -> Bool {
        let fileName = "font_\(UUID().uuidString)" + "." + url.pathExtension
        let destURL = Self.fontsDirectory.appendingPathComponent(fileName)

        clearOldFonts()

        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url) else { return false }
            try data.write(to: destURL)
        } catch {
            return false
        }

        guard let fontDataProvider = CGDataProvider(url: destURL as CFURL),
              let font = CGFont(fontDataProvider) else {
            return false
        }

        var error: Unmanaged<CFError>?
        guard CTFontManagerRegisterGraphicsFont(font, &error) else {
            if let psName = font.postScriptName as String? {
                saveFontSettings(fileName: fileName, fontName: psName, displayName: displayName)
                notifyChanged()
                return true
            }
            return false
        }

        let psName = font.postScriptName as String? ?? "CustomFont"
        saveFontSettings(fileName: fileName, fontName: psName, displayName: displayName)
        notifyChanged()
        return true
    }

    func removeCustomFont() {
        clearOldFonts()
        DataManager.shared.updateSettings {
            $0.customFontFileName = ""
            $0.customFontName = ""
            $0.customFontDisplayName = ""
        }
        notifyChanged()
    }

    func registerSavedFont() {
        let settings = DataManager.shared.settings
        guard !settings.customFontFileName.isEmpty else { return }

        let url = Self.fontsDirectory.appendingPathComponent(settings.customFontFileName)
        guard FileManager.default.fileExists(atPath: url.path),
              let fontDataProvider = CGDataProvider(url: url as CFURL),
              let font = CGFont(fontDataProvider) else { return }

        var error: Unmanaged<CFError>?
        CTFontManagerRegisterGraphicsFont(font, &error)
    }

    func applyGlobalFont() {
        let fontName = DataManager.shared.settings.customFontName
        guard !fontName.isEmpty else {
            UILabel.appearance().font = nil
            UIButton.appearance().titleLabel?.font = nil
            UITextField.appearance().font = nil
            UITextView.appearance().font = nil
            return
        }

        let customFont = UIFont(name: fontName, size: 17) ?? UIFont.systemFont(ofSize: 17)

        UILabel.appearance().font = customFont
        UIButton.appearance().titleLabel?.font = customFont
        UITextField.appearance().font = customFont
        UITextView.appearance().font = customFont
    }

    private func saveFontSettings(fileName: String, fontName: String, displayName: String) {
        DataManager.shared.updateSettings {
            $0.customFontFileName = fileName
            $0.customFontName = fontName
            $0.customFontDisplayName = displayName
        }
    }

    private func clearOldFonts() {
        let dir = Self.fontsDirectory
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        for file in files {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
        }
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .steelFontChanged, object: nil)
    }
}

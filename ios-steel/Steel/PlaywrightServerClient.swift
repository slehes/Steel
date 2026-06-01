import Foundation

struct PlaywrightCommand: Codable, Sendable {
    var url: String
    var actions: [String]
    var browser: String

    init(url: String, actions: [String] = [], browser: String = "chromium") {
        self.url = url
        self.actions = actions
        self.browser = browser
    }
}

struct PlaywrightResponse: Codable, Sendable {
    var text: String?
    var screenshotBase64: String?
}

@MainActor
final class PlaywrightServerClient {
    static let shared = PlaywrightServerClient()

    private let baseURLKey = "steel.playwright.baseURL"

    var baseURL: String? {
        get { UserDefaults.standard.string(forKey: baseURLKey) }
        set { UserDefaults.standard.set(newValue, forKey: baseURLKey) }
    }

    var isConfigured: Bool { !(baseURL ?? "").isEmpty }

    enum ClientError: Error {
        case notConfigured
        case badResponse
    }

    func run(_ command: PlaywrightCommand) async throws -> PlaywrightResponse {
        guard let base = baseURL, let url = URL(string: base.appending("/scrape")) else {
            throw ClientError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(command)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClientError.badResponse
        }
        return try JSONDecoder().decode(PlaywrightResponse.self, from: data)
    }
}

import Foundation
import WebKit
import SwiftSoup

struct ScrapeResult: Sendable {
    let text: String
    let tables: [[String]]
    let lists: [String]
}

@MainActor
final class WebAgent: NSObject, WKNavigationDelegate {
    static let shared = WebAgent()

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<String, Error>?

    enum WebAgentError: Error {
        case invalidURL
        case loadFailed
        case empty
    }

    func scrape(urlString: String) async throws -> ScrapeResult {
        let html = try await loadHTML(urlString: urlString)
        return try parse(html: html)
    }

    private func normalized(_ urlString: String) -> URL? {
        var string = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !string.lowercased().hasPrefix("http") {
            string = "https://" + string
        }
        return URL(string: string)
    }

    private func loadHTML(urlString: String) async throws -> String {
        guard let url = normalized(urlString) else { throw WebAgentError.invalidURL }

        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768), configuration: config)
        webView.navigationDelegate = self
        self.webView = webView

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.load(URLRequest(url: url))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task {
            let js = "document.documentElement.outerHTML"
            let result = try? await webView.evaluateJavaScript(js)
            let html = (result as? String) ?? ""
            finish(.success(html))
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(WebAgentError.loadFailed))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(WebAgentError.loadFailed))
    }

    private func finish(_ result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        self.webView = nil
        continuation.resume(with: result)
    }

    nonisolated func parse(html: String) throws -> ScrapeResult {
        guard !html.isEmpty else { throw WebAgentError.empty }
        let doc = try SwiftSoup.parse(html)

        try doc.select("script, style, noscript, svg").remove()

        var tables: [[String]] = []
        for table in try doc.select("table").array() {
            for row in try table.select("tr").array() {
                let cells = try row.select("th, td").array()
                let values = try cells.map { try $0.text() }.filter { !$0.isEmpty }
                if !values.isEmpty { tables.append(values) }
            }
        }

        var lists: [String] = []
        for li in try doc.select("ul li, ol li").array() {
            let text = try li.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if text.count > 1 { lists.append(text) }
        }

        let bodyText = (try? doc.body()?.text()) ?? ""
        let cleaned = bodyText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let trimmed = String(cleaned.prefix(4000))

        return ScrapeResult(text: trimmed, tables: tables, lists: Array(lists.prefix(60)))
    }
}

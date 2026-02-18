import Foundation
@preconcurrency import WebKit

@MainActor
final class WAFService {
    private var cachedCookies: [String: (cookies: [String: String], expiry: Date)] = [:]

    func getCookies(for provider: ProviderConfig) async -> [String: String] {
        let key = provider.name

        // Return cached if valid
        if let cached = cachedCookies[key], cached.expiry > Date() {
            return cached.cookies
        }

        // Extract via WKWebView
        let cookies = await extractCookies(url: provider.loginURL, names: provider.wafCookieNames)
        if !cookies.isEmpty {
            cachedCookies[key] = (cookies, Date().addingTimeInterval(Constants.wafCookieCacheDuration))
        }
        return cookies
    }

    func clearCache(for provider: String? = nil) {
        if let provider { cachedCookies.removeValue(forKey: provider) }
        else { cachedCookies.removeAll() }
    }

    private func extractCookies(url: URL, names: [String]) async -> [String: String] {
        await withCheckedContinuation { continuation in
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .nonPersistent()
            let webView = WKWebView(frame: .init(x: 0, y: 0, width: 1920, height: 1080), configuration: config)

            webView.customUserAgent = Constants.userAgent
            webView.load(URLRequest(url: url))

            // Poll cookies after page load
            Task { @MainActor in
                // Wait for navigation
                try? await Task.sleep(for: .seconds(5))

                let store = config.websiteDataStore.httpCookieStore
                let allCookies = await store.allCookies()

                var result: [String: String] = [:]
                for cookie in allCookies {
                    if names.contains(cookie.name) {
                        result[cookie.name] = cookie.value
                    }
                }
                webView.stopLoading()
                continuation.resume(returning: result)
            }
        }
    }
}

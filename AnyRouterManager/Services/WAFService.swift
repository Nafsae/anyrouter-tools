import Foundation
@preconcurrency import WebKit

@MainActor
final class WAFService {
    private var cachedCookies: [String: (cookies: [String: String], expiry: Date)] = [:]
    private var navigationDelegates: [ObjectIdentifier: NavigationDelegate] = [:]

    func getCookies(for provider: ProviderConfig) async -> [String: String] {
        let key = provider.name

        if let cached = cachedCookies[key], cached.expiry > Date() {
            return cached.cookies
        }

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
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .init(x: 0, y: 0, width: 1920, height: 1080), configuration: config)
        webView.customUserAgent = Constants.userAgent

        let identifier = ObjectIdentifier(webView)
        let delegate = NavigationDelegate()
        navigationDelegates[identifier] = delegate
        webView.navigationDelegate = delegate
        webView.load(URLRequest(url: url))

        _ = await delegate.waitUntilFinished(timeout: 10)

        let store = config.websiteDataStore.httpCookieStore
        let allCookies = await store.allCookies()
        var result: [String: String] = [:]
        for cookie in allCookies where names.contains(cookie.name) {
            result[cookie.name] = cookie.value
        }

        webView.stopLoading()
        webView.navigationDelegate = nil
        navigationDelegates.removeValue(forKey: identifier)
        return result
    }
}

@MainActor
private final class NavigationDelegate: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Never>?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        continuation?.resume()
        continuation = nil
    }

    func waitUntilFinished(timeout: TimeInterval) async -> Void {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(timeout))
                self.continuation?.resume()
                self.continuation = nil
            }
        }
    }
}

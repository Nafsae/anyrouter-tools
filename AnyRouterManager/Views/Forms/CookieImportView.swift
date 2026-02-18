import SwiftUI
@preconcurrency import WebKit

struct CookieImportView: View {
    let provider: ProviderConfig
    let onCookiesExtracted: ([String: String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var status = "加载中…"

    var body: some View {
        VStack(spacing: 12) {
            Text("手动登录获取 Cookie")
                .font(.headline)

            Text("请在下方浏览器中完成 WAF 验证，完成后点击「提取 Cookie」")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            WebViewWrapper(url: provider.loginURL)
                .frame(minWidth: 640, minHeight: 480)

            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("提取 Cookie") {
                    extractCookies()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 680, minHeight: 560)
    }

    private func extractCookies() {
        status = "正在提取…"
        Task { @MainActor in
            let cookies = await WebViewCookieExtractor.extractCookies(
                from: provider.loginURL,
                names: provider.wafCookieNames
            )
            if cookies.isEmpty {
                status = "未找到所需 Cookie，请确保已完成 WAF 验证"
            } else {
                onCookiesExtracted(cookies)
                dismiss()
            }
        }
    }
}

// MARK: - WebView Wrapper

struct WebViewWrapper: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = Constants.userAgent
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// MARK: - Cookie Extractor

enum WebViewCookieExtractor {
    @MainActor
    static func extractCookies(from url: URL, names: [String]) async -> [String: String] {
        let config = WKWebViewConfiguration()
        let store = config.websiteDataStore.httpCookieStore
        let allCookies = await store.allCookies()

        var result: [String: String] = [:]
        for cookie in allCookies where names.contains(cookie.name) {
            result[cookie.name] = cookie.value
        }
        return result
    }
}

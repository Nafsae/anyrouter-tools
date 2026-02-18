import Foundation

actor AnyRouterAPI {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": Constants.userAgent,
            "Accept": "application/json, text/plain, */*",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Fetch User Info

    func fetchUserInfo(provider: ProviderConfig, apiUser: String, sessionCookie: String, wafCookies: [String: String] = [:]) async throws -> (quota: Double, usedQuota: Double) {
        var request = URLRequest(url: provider.userInfoURL)
        request.httpMethod = "GET"
        request.setValue(provider.domain, forHTTPHeaderField: "Referer")
        request.setValue(provider.domain, forHTTPHeaderField: "Origin")
        request.setValue(apiUser, forHTTPHeaderField: provider.apiUserKey)

        let cookieString = buildCookieString(session: sessionCookie, waf: wafCookies)
        request.setValue(cookieString, forHTTPHeaderField: "Cookie")

        let (data, response) = try await session.data(for: request)
        try checkHTTPStatus(response)

        let userInfo = try JSONDecoder().decode(UserInfoResponse.self, from: data)
        guard userInfo.success, let userData = userInfo.data else {
            throw APIError.invalidResponse
        }

        return (
            quota: Double(userData.quota) / Constants.quotaDivisor,
            usedQuota: Double(userData.usedQuota) / Constants.quotaDivisor
        )
    }

    // MARK: - Check In

    func checkIn(provider: ProviderConfig, apiUser: String, sessionCookie: String, wafCookies: [String: String] = [:]) async throws -> String {
        guard let signInURL = provider.signInURL else {
            return "此 Provider 无需手动签到"
        }

        var request = URLRequest(url: signInURL)
        request.httpMethod = "POST"
        request.setValue(provider.domain, forHTTPHeaderField: "Referer")
        request.setValue(provider.domain, forHTTPHeaderField: "Origin")
        request.setValue(apiUser, forHTTPHeaderField: provider.apiUserKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")

        let cookieString = buildCookieString(session: sessionCookie, waf: wafCookies)
        request.setValue(cookieString, forHTTPHeaderField: "Cookie")

        let (data, response) = try await session.data(for: request)
        try checkHTTPStatus(response)

        // Try JSON decode
        if let result = try? JSONDecoder().decode(CheckInResponse.self, from: data) {
            if result.isSuccess {
                return "签到成功"
            }
            if result.isAlreadyCheckedIn {
                return "今日已签到"
            }
            throw APIError.checkInFailed(result.errorMessage)
        }

        // Fallback: check raw text
        if let text = String(data: data, encoding: .utf8), text.lowercased().contains("success") {
            return "签到成功"
        }

        throw APIError.invalidResponse
    }

    // MARK: - Helpers

    private func buildCookieString(session: String, waf: [String: String]) -> String {
        var parts = waf.map { "\($0.key)=\($0.value)" }
        parts.append("session=\(session)")
        return parts.joined(separator: "; ")
    }

    private func checkHTTPStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: return
        case 401: throw APIError.sessionExpired
        case 403: throw APIError.wafBlocked
        default: throw APIError.httpError(http.statusCode)
        }
    }

    enum APIError: LocalizedError {
        case sessionExpired
        case wafBlocked
        case httpError(Int)
        case invalidResponse
        case checkInFailed(String)

        var errorDescription: String? {
            switch self {
            case .sessionExpired: "Session 已过期，请重新导入 Cookie"
            case .wafBlocked: "WAF 拦截，需要刷新 WAF Cookie"
            case .httpError(let code): "HTTP 错误: \(code)"
            case .invalidResponse: "无效的响应数据"
            case .checkInFailed(let msg): "签到失败: \(msg)"
            }
        }
    }
}

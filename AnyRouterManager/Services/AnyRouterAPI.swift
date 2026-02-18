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
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        self.session = URLSession(configuration: config)
    }

    // MARK: - Detect Account Info

    func detectAccount(provider: ProviderConfig, sessionCookie: String) async throws -> (id: String, name: String, quota: Double, usedQuota: Double) {
        let userId = Self.decodeUserIdFromCookie(sessionCookie)

        var request = URLRequest(url: provider.userInfoURL)
        request.httpMethod = "GET"
        request.setValue(provider.domain, forHTTPHeaderField: "Referer")
        request.setValue(provider.domain, forHTTPHeaderField: "Origin")
        if let uid = userId {
            request.setValue(String(uid), forHTTPHeaderField: provider.apiUserKey)
        }

        let data = try await performRequest(&request, sessionCookie: sessionCookie)

        let userInfo = try JSONDecoder().decode(UserInfoResponse.self, from: data)
        guard userInfo.success, let userData = userInfo.data else {
            throw APIError.invalidResponse
        }

        let detectedId = userData.id.map(String.init) ?? (userId.map(String.init) ?? "")
        let userName = userData.bestName ?? "账号"

        return (
            id: detectedId,
            name: userName,
            quota: Double(userData.quota) / Constants.quotaDivisor,
            usedQuota: Double(userData.usedQuota) / Constants.quotaDivisor
        )
    }

    // MARK: - Fetch User Info

    func fetchUserInfo(provider: ProviderConfig, apiUser: String, sessionCookie: String) async throws -> (quota: Double, usedQuota: Double) {
        var request = URLRequest(url: provider.userInfoURL)
        request.httpMethod = "GET"
        request.setValue(provider.domain, forHTTPHeaderField: "Referer")
        request.setValue(provider.domain, forHTTPHeaderField: "Origin")
        request.setValue(apiUser, forHTTPHeaderField: provider.apiUserKey)

        let data = try await performRequest(&request, sessionCookie: sessionCookie)

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

    func checkIn(provider: ProviderConfig, apiUser: String, sessionCookie: String) async throws -> String {
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

        let data = try await performRequest(&request, sessionCookie: sessionCookie)

        if let result = try? JSONDecoder().decode(CheckInResponse.self, from: data) {
            if result.isSuccess { return "签到成功" }
            if result.isAlreadyCheckedIn { return "今日已签到" }
            throw APIError.checkInFailed(result.errorMessage)
        }

        if let text = String(data: data, encoding: .utf8), text.lowercased().contains("success") {
            return "签到成功"
        }

        throw APIError.invalidResponse
    }

    // MARK: - Request with auto WAF bypass

    private func performRequest(_ request: inout URLRequest, sessionCookie: String) async throws -> Data {
        request.setValue("session=\(sessionCookie)", forHTTPHeaderField: "Cookie")

        let (data, response) = try await session.data(for: request)
        try checkHTTPStatus(response)

        guard let html = String(data: data, encoding: .utf8),
              html.contains("acw_sc__v2"), html.hasPrefix("<html") else {
            return data
        }

        guard let acwScV2 = Self.solveWAFChallenge(html) else {
            throw APIError.wafBlocked
        }

        var wafParts = ["acw_sc__v2=\(acwScV2)"]
        if let http = response as? HTTPURLResponse, let url = request.url {
            let headerFields = http.allHeaderFields as? [String: String] ?? [:]
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
            for cookie in cookies where cookie.name == "acw_tc" || cookie.name == "cdn_sec_tc" {
                wafParts.append("\(cookie.name)=\(cookie.value)")
            }
        }

        let cookieString = wafParts.joined(separator: "; ") + "; session=\(sessionCookie)"
        request.setValue(cookieString, forHTTPHeaderField: "Cookie")

        let (data2, response2) = try await session.data(for: request)
        try checkHTTPStatus(response2)

        if let html2 = String(data: data2, encoding: .utf8),
           html2.contains("acw_sc__v2"), html2.hasPrefix("<html") {
            throw APIError.wafBlocked
        }
        return data2
    }

    // MARK: - WAF Solver (pure Swift, no JavaScriptCore)

    static func solveWAFChallenge(_ html: String) -> String? {
        guard let range = html.range(of: "var arg1='"),
              let endRange = html.range(of: "'", range: range.upperBound..<html.endIndex) else { return nil }

        let arg1 = String(html[range.upperBound..<endRange.lowerBound])
        guard arg1.count == 40 else { return nil }

        let m = [15,35,29,24,33,16,1,38,10,9,19,31,40,27,22,23,25,13,6,11,39,18,20,8,14,21,32,26,2,30,7,4,17,5,3,28,34,37,12,36]
        let p = "3000176000856006061501533003690027800375"
        let arg1Chars = Array(arg1)

        // Rearrange characters based on m array
        var q = [Character](repeating: "0", count: m.count)
        for x in 0..<arg1Chars.count {
            for z in 0..<m.count {
                if m[z] == x + 1 { q[z] = arg1Chars[x] }
            }
        }
        let u = String(q)
        let pChars = Array(p)

        // XOR hex pairs
        var v = ""
        var x = 0
        while x < u.count && x < pChars.count {
            let uHex = String(u[u.index(u.startIndex, offsetBy: x)..<u.index(u.startIndex, offsetBy: x + 2)])
            let pHex = String(p[p.index(p.startIndex, offsetBy: x)..<p.index(p.startIndex, offsetBy: x + 2)])
            guard let uVal = UInt8(uHex, radix: 16), let pVal = UInt8(pHex, radix: 16) else { return nil }
            let xored = uVal ^ pVal
            v += String(format: "%02x", xored)
            x += 2
        }
        return v
    }

    // MARK: - Cookie User ID Decoder

    static func decodeUserIdFromCookie(_ cookie: String) -> Int? {
        // Cookie is base64-encoded: decoded = "timestamp|payload_b64|signature"
        let safe = cookie.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padded = safe.count % 4 == 0 ? safe : safe + String(repeating: "=", count: 4 - safe.count % 4)
        guard let outerData = Data(base64Encoded: padded) else { return nil }

        // Find | separators in decoded bytes
        let bytes = Array(outerData)
        var pipes: [Int] = []
        for (i, b) in bytes.enumerated() where b == 0x7C { pipes.append(i) }
        guard pipes.count >= 2 else { return nil }

        // Extract inner payload (between first and second |)
        guard let payloadStr = String(bytes: Array(bytes[(pipes[0]+1)..<pipes[1]]), encoding: .utf8) else { return nil }

        // Base64 decode the inner payload
        let safePl = payloadStr.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let paddedPl = safePl.count % 4 == 0 ? safePl : safePl + String(repeating: "=", count: 4 - safePl.count % 4)
        guard let gobData = Data(base64Encoded: paddedPl) else { return nil }

        return extractGobUserId(from: gobData)
    }

    private static func extractGobUserId(from data: Data) -> Int? {
        let bytes = Array(data)
        // Look for "id" (0x69, 0x64) followed by "int" (0x69, 0x6e, 0x74)
        for i in 0..<(bytes.count - 10) {
            if bytes[i] == 0x69 && bytes[i+1] == 0x64 {
                // Find "int" after "id"
                for j in (i+2)..<min(i+10, bytes.count - 5) {
                    if bytes[j] == 0x69 && bytes[j+1] == 0x6e && bytes[j+2] == 0x74 {
                        // Skip type marker bytes after "int"
                        let valueStart = j + 3
                        guard valueStart + 2 < bytes.count else { return nil }
                        // Skip length/type prefix (typically 04 05 00)
                        var pos = valueStart
                        // Skip past type info until we find fd/fe/ff (gob length indicator)
                        while pos < min(valueStart + 5, bytes.count) {
                            if bytes[pos] >= 0xfb { break }
                            pos += 1
                        }
                        guard pos < bytes.count else { return nil }
                        let indicator = bytes[pos]
                        if indicator < 0x80 {
                            // Direct small value (unlikely for user IDs)
                            return Int(indicator) / 2
                        }
                        let numBytes = 256 - Int(indicator)
                        guard pos + numBytes < bytes.count else { return nil }
                        var value = 0
                        for k in 1...numBytes {
                            value = (value << 8) | Int(bytes[pos + k])
                        }
                        // Go gob signed int: decoded = value / 2 (for positive)
                        return value / 2
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Helpers

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
            case .wafBlocked: "WAF 拦截，自动绕过失败"
            case .httpError(let code): "HTTP 错误: \(code)"
            case .invalidResponse: "无效的响应数据"
            case .checkInFailed(let msg): "签到失败: \(msg)"
            }
        }
    }
}

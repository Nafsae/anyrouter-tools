import Foundation

struct ProviderConfig: Sendable {
    let name: String
    let domain: String
    let loginPath: String
    let signInPath: String?
    let userInfoPath: String
    let apiUserKey: String
    let wafCookieNames: [String]

    var needsWAFCookies: Bool { !wafCookieNames.isEmpty }
    var needsManualCheckIn: Bool { signInPath != nil }
    var loginURL: URL { URL(string: domain + loginPath)! }
    var userInfoURL: URL { URL(string: domain + userInfoPath)! }
    var signInURL: URL? { signInPath.map { URL(string: domain + $0)! } }

    static let builtIn: [String: ProviderConfig] = [
        "anyrouter": ProviderConfig(
            name: "anyrouter",
            domain: "https://anyrouter.top",
            loginPath: "/login",
            signInPath: "/api/user/sign_in",
            userInfoPath: "/api/user/self",
            apiUserKey: "new-api-user",
            wafCookieNames: ["acw_tc", "cdn_sec_tc", "acw_sc__v2"]
        ),
        "agentrouter": ProviderConfig(
            name: "agentrouter",
            domain: "https://agentrouter.org",
            loginPath: "/login",
            signInPath: nil,
            userInfoPath: "/api/user/self",
            apiUserKey: "new-api-user",
            wafCookieNames: ["acw_tc"]
        ),
    ]

    static func provider(for name: String) -> ProviderConfig {
        builtIn[name] ?? builtIn["anyrouter"]!
    }
}

import Foundation
import SwiftData

@Observable
@MainActor
final class AccountFormViewModel {
    var name = ""
    var apiUser = ""
    var provider = "anyrouter"
    var sessionCookie = ""
    var isDetecting = false
    var detectMessage: String?

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && !apiUser.trimmingCharacters(in: .whitespaces).isEmpty
        && !sessionCookie.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var canDetect: Bool {
        !sessionCookie.trimmingCharacters(in: .whitespaces).isEmpty && !isDetecting
    }

    static let providers = Array(ProviderConfig.builtIn.keys).sorted()

    func detectAccount() async {
        let cookie = parseCookieValue(sessionCookie.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !cookie.isEmpty else { return }

        isDetecting = true
        detectMessage = "正在识别…"

        let providerConfig = ProviderConfig.provider(for: provider)
        let api = AnyRouterAPI()

        do {
            let info = try await api.detectAccount(provider: providerConfig, sessionCookie: cookie)
            applyDetectedInfo(info)
        } catch {
            detectMessage = "识别失败：\(error.localizedDescription)"
        }

        isDetecting = false
    }

    private func applyDetectedInfo(_ info: (id: String, name: String, quota: Double, usedQuota: Double)) {
        if !info.id.isEmpty { apiUser = info.id }
        if name.isEmpty { name = info.name }
        detectMessage = "识别成功：\(info.name) (余额 $\(String(format: "%.2f", info.quota - info.usedQuota)))"
    }

    func save(context: ModelContext) throws {
        let account = Account(name: name.trimmingCharacters(in: .whitespaces),
                              apiUser: apiUser.trimmingCharacters(in: .whitespaces),
                              provider: provider)
        context.insert(account)
        try context.save()

        let cookie = parseCookieValue(sessionCookie.trimmingCharacters(in: .whitespacesAndNewlines))
        try KeychainService.save(cookie: cookie, for: account.id)
    }

    func update(account: Account, context: ModelContext) throws {
        account.name = name.trimmingCharacters(in: .whitespaces)
        account.apiUser = apiUser.trimmingCharacters(in: .whitespaces)
        account.provider = provider
        try context.save()

        let raw = sessionCookie.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty {
            let cookie = parseCookieValue(raw)
            try KeychainService.save(cookie: cookie, for: account.id)
        }
    }

    func load(from account: Account) {
        name = account.name
        apiUser = account.apiUser
        provider = account.provider
        sessionCookie = KeychainService.load(for: account.id) ?? ""
    }

    private func parseCookieValue(_ raw: String) -> String {
        if raw.contains("session=") {
            let parts = raw.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            for part in parts {
                if part.hasPrefix("session=") {
                    return String(part.dropFirst("session=".count))
                }
            }
        }
        // URL decode if needed
        return raw.removingPercentEncoding ?? raw
    }
}

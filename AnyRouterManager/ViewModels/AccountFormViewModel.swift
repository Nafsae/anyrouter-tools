import Foundation
import SwiftData

@Observable
@MainActor
final class AccountFormViewModel {
    var name = ""
    var apiUser = ""
    var provider = "anyrouter"
    var sessionCookie = ""

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && !apiUser.trimmingCharacters(in: .whitespaces).isEmpty
        && !sessionCookie.trimmingCharacters(in: .whitespaces).isEmpty
    }

    static let providers = Array(ProviderConfig.builtIn.keys).sorted()

    func save(context: ModelContext) throws {
        let account = Account(name: name.trimmingCharacters(in: .whitespaces),
                              apiUser: apiUser.trimmingCharacters(in: .whitespaces),
                              provider: provider)
        context.insert(account)
        try context.save()

        // Save cookie to Keychain
        let cookie = parseCookieValue(sessionCookie.trimmingCharacters(in: .whitespaces))
        try KeychainService.save(cookie: cookie, for: account.id)
    }

    func update(account: Account, context: ModelContext) throws {
        account.name = name.trimmingCharacters(in: .whitespaces)
        account.apiUser = apiUser.trimmingCharacters(in: .whitespaces)
        account.provider = provider
        try context.save()

        let raw = sessionCookie.trimmingCharacters(in: .whitespaces)
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

    /// Parse "session=xxx; other=yyy" or raw value
    private func parseCookieValue(_ raw: String) -> String {
        // If contains "session=", extract it
        if raw.contains("session=") {
            let parts = raw.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            for part in parts {
                if part.hasPrefix("session=") {
                    return String(part.dropFirst("session=".count))
                }
            }
        }
        return raw
    }
}

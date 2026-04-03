import Foundation
import Combine
import SwiftData

@MainActor
final class AccountFormViewModel: ObservableObject {
    @Published var name = ""
    @Published var email = ""
    @Published var apiUser = ""
    @Published var provider = "anyrouter"
    @Published var sessionCookie = ""
    @Published var apiKey = ""
    @Published var isDetecting = false
    @Published var detectMessage: String?
    @Published var isTestingAPIKey = false
    @Published var apiKeyTestMessage: String?

    private let api = AnyRouterAPI()

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && !apiUser.trimmingCharacters(in: .whitespaces).isEmpty
        && !sessionCookie.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var canDetect: Bool {
        !sessionCookie.trimmingCharacters(in: .whitespaces).isEmpty && !isDetecting
    }

    var canTestAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTestingAPIKey
    }

    static let providers = Array(ProviderConfig.builtIn.keys).sorted()

    func detectAccount() async {
        let cookie = parseCookieValue(sessionCookie.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !cookie.isEmpty else { return }

        isDetecting = true
        detectMessage = "正在识别…"

        let providerConfig = ProviderConfig.provider(for: provider)

        do {
            let info = try await api.detectAccount(provider: providerConfig, sessionCookie: cookie)
            applyDetectedInfo(info)
        } catch {
            detectMessage = "识别失败：\(error.localizedDescription)"
        }

        isDetecting = false
    }

    func testAPIKey() async {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }

        isTestingAPIKey = true
        apiKeyTestMessage = "测试中…"

        let providerConfig = ProviderConfig.provider(for: provider)

        do {
            apiKeyTestMessage = try await api.testAPIKey(provider: providerConfig, apiKey: trimmedKey)
        } catch {
            apiKeyTestMessage = "测试失败：\(error.localizedDescription)"
        }

        isTestingAPIKey = false
    }

    private func applyDetectedInfo(_ info: (id: String, name: String, quota: Double, usedQuota: Double)) {
        if !info.id.isEmpty { apiUser = info.id }
        if name.isEmpty { name = info.name }
        detectMessage = "识别成功：\(info.name) (余额 $\(String(format: "%.2f", info.quota)))"
    }

    func save(context: ModelContext) throws {
        let account = Account(name: name.trimmingCharacters(in: .whitespaces),
                              email: email.trimmingCharacters(in: .whitespaces).isEmpty ? nil : email.trimmingCharacters(in: .whitespaces),
                              apiUser: apiUser.trimmingCharacters(in: .whitespaces),
                              provider: provider)
        context.insert(account)
        try context.save()

        let cookie = parseCookieValue(sessionCookie.trimmingCharacters(in: .whitespacesAndNewlines))
        try KeychainService.save(cookie: cookie, for: account.id)

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            try KeychainService.saveAPIKey(trimmedKey, for: account.id)
        }
    }

    func update(account: Account, context: ModelContext) throws {
        account.name = name.trimmingCharacters(in: .whitespaces)
        account.email = email.trimmingCharacters(in: .whitespaces).isEmpty ? nil : email.trimmingCharacters(in: .whitespaces)
        account.apiUser = apiUser.trimmingCharacters(in: .whitespaces)
        account.provider = provider
        try context.save()

        let raw = sessionCookie.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty {
            let cookie = parseCookieValue(raw)
            try KeychainService.save(cookie: cookie, for: account.id)
        }

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty {
            KeychainService.deleteAPIKey(for: account.id)
        } else {
            try KeychainService.saveAPIKey(trimmedKey, for: account.id)
        }
    }

    func load(from account: Account) {
        name = account.name
        email = account.email ?? ""
        apiUser = account.apiUser
        provider = account.provider
        sessionCookie = KeychainService.load(for: account.id) ?? ""
        apiKey = KeychainService.loadAPIKey(for: account.id) ?? ""
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

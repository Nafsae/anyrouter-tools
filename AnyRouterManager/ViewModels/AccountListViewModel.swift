import AppKit
import Foundation
import Combine
import SwiftData
import UniformTypeIdentifiers

@MainActor
final class AccountListViewModel: ObservableObject {
    @Published private(set) var states: [UUID: AccountRuntimeState] = [:]
    private let api = AnyRouterAPI()
    let scheduler = SchedulerService()
    private var stateCancellables: [UUID: AnyCancellable] = [:]
    private var schedulerCancellable: AnyCancellable?
    private var didTriggerInitialRefresh = false

    init() {
        schedulerCancellable = scheduler.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var totalBalance: Double {
        states.values.reduce(0) { $0 + $1.balance }
    }

    var totalBalanceText: String {
        String(format: "$%.2f", totalBalance)
    }

    func state(for account: Account) -> AccountRuntimeState {
        if let existing = states[account.id] { return existing }
        let s = AccountRuntimeState()
        if let cached = BalanceCacheService.load(for: account.id) {
            s.quota = cached.quota
            s.usedQuota = cached.usedQuota
            s.lastRefreshDate = cached.lastRefreshAt
            s.lastCheckInDate = cached.lastCheckInAt
        }
        stateCancellables[account.id] = s.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        states[account.id] = s
        return s
    }

    func removeState(for id: UUID) {
        states.removeValue(forKey: id)
        stateCancellables.removeValue(forKey: id)
    }

    func prepareStates(for accounts: [Account]) {
        for account in accounts {
            _ = state(for: account)
        }
    }

    func triggerInitialRefreshIfNeeded(accounts: [Account]) {
        guard !didTriggerInitialRefresh else { return }
        didTriggerInitialRefresh = true
        Task { await refreshAll(accounts: accounts) }
    }

    // MARK: - Refresh

    func refresh(account: Account) async {
        let s = state(for: account)
        guard !s.isLoading else { return }
        s.status = .refreshing

        guard let cookie = KeychainService.load(for: account.id) else {
            s.status = .error("未设置 Cookie")
            return
        }

        let provider = ProviderConfig.provider(for: account.provider)

        do {
            let info = try await api.fetchUserInfo(
                provider: provider,
                apiUser: account.apiUser,
                sessionCookie: cookie
            )
            s.quota = info.quota
            s.usedQuota = info.usedQuota
            s.lastRefreshDate = Date()
            BalanceCacheService.save(
                quota: info.quota,
                usedQuota: info.usedQuota,
                lastRefreshAt: s.lastRefreshDate,
                lastCheckInAt: s.lastCheckInDate,
                for: account.id
            )
            s.status = .success(nil)
        } catch {
            s.status = .error(error.localizedDescription)
        }
    }

    func refreshAll(accounts: [Account]) async {
        await withTaskGroup(of: Void.self) { group in
            let semaphore = AsyncSemaphore(limit: Constants.maxConcurrentRequests)
            for account in accounts where account.isEnabled {
                group.addTask { @MainActor in
                    await semaphore.wait()
                    await self.refresh(account: account)
                    semaphore.signal()
                }
            }
        }
    }

    // MARK: - Check In

    func checkIn(account: Account) async {
        let s = state(for: account)
        guard !s.isLoading else { return }
        s.status = .checkingIn

        guard let cookie = KeychainService.load(for: account.id) else {
            s.status = .error("未设置 Cookie")
            return
        }

        let provider = ProviderConfig.provider(for: account.provider)

        do {
            let msg = try await api.checkIn(
                provider: provider,
                apiUser: account.apiUser,
                sessionCookie: cookie
            )
            s.lastCheckInDate = Date()
            BalanceCacheService.updateCheckInDate(s.lastCheckInDate, for: account.id)
            s.status = .success(msg)
            NotificationService.send(title: account.name, body: msg)
            await refresh(account: account)
        } catch {
            s.status = .error(error.localizedDescription)
        }
    }

    func checkInAll(accounts: [Account]) async {
        await withTaskGroup(of: Void.self) { group in
            let semaphore = AsyncSemaphore(limit: Constants.maxConcurrentRequests)
            for account in accounts where account.isEnabled {
                group.addTask { @MainActor in
                    await semaphore.wait()
                    await self.checkIn(account: account)
                    semaphore.signal()
                }
            }
        }
    }

    // MARK: - Export All Cookies

    func exportAllCookies(accounts: [Account]) {
        var dict: [String: String] = [:]
        for account in accounts {
            if let cookie = KeychainService.load(for: account.id), !cookie.isEmpty {
                dict[account.name] = cookie
            }
        }

        guard !dict.isEmpty else { return }

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)

        let panel = NSSavePanel()
        panel.title = "导出全部 Cookie"
        panel.nameFieldStringValue = "cookies.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - Test All API Keys

    @Published private(set) var isTestingAllKeys = false

    func testAllAPIKeys(accounts: [Account]) async {
        isTestingAllKeys = true
        await withTaskGroup(of: Void.self) { group in
            let semaphore = AsyncSemaphore(limit: Constants.maxConcurrentRequests)
            for account in accounts {
                guard let apiKey = KeychainService.loadAPIKey(for: account.id),
                      !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                let s = state(for: account)
                group.addTask { @MainActor in
                    await semaphore.wait()
                    s.apiKeyTestResult = "测试中…"
                    let provider = ProviderConfig.provider(for: account.provider)
                    do {
                        let result = try await self.api.testAPIKey(provider: provider, apiKey: apiKey)
                        s.apiKeyTestResult = result
                    } catch {
                        s.apiKeyTestResult = "失败：\(error.localizedDescription)"
                    }
                    semaphore.signal()
                }
            }
        }
        isTestingAllKeys = false
    }
}

// MARK: - Async Semaphore

private final class AsyncSemaphore: @unchecked Sendable {
    private let limit: Int
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = limit
        self.count = limit
    }

    func wait() async {
        if count > 0 {
            count -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if waiters.isEmpty {
            count += 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}

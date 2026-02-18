import Foundation
import SwiftData

@Observable
@MainActor
final class AccountListViewModel {
    // Runtime state keyed by account ID
    private(set) var states: [UUID: AccountRuntimeState] = [:]
    private let api = AnyRouterAPI()
    let wafService = WAFService()
    let scheduler = SchedulerService()

    var totalBalance: Double {
        states.values.reduce(0) { $0 + $1.balance }
    }

    var totalBalanceText: String {
        String(format: "$%.2f", totalBalance)
    }

    func state(for account: Account) -> AccountRuntimeState {
        if let existing = states[account.id] { return existing }
        let s = AccountRuntimeState()
        states[account.id] = s
        return s
    }

    func removeState(for id: UUID) {
        states.removeValue(forKey: id)
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
            var wafCookies: [String: String] = [:]
            if provider.needsWAFCookies {
                wafCookies = await wafService.getCookies(for: provider)
            }

            let info = try await api.fetchUserInfo(
                provider: provider,
                apiUser: account.apiUser,
                sessionCookie: cookie,
                wafCookies: wafCookies
            )
            s.quota = info.quota
            s.usedQuota = info.usedQuota
            s.lastRefreshDate = Date()
            s.status = .success(nil)
        } catch let err as AnyRouterAPI.APIError where err == .wafBlocked {
            // Clear WAF cache and retry once
            wafService.clearCache(for: provider.name)
            do {
                let wafCookies = await wafService.getCookies(for: provider)
                let info = try await api.fetchUserInfo(
                    provider: provider,
                    apiUser: account.apiUser,
                    sessionCookie: cookie,
                    wafCookies: wafCookies
                )
                s.quota = info.quota
                s.usedQuota = info.usedQuota
                s.lastRefreshDate = Date()
                s.status = .success(nil)
            } catch {
                s.status = .error(error.localizedDescription)
            }
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
            var wafCookies: [String: String] = [:]
            if provider.needsWAFCookies {
                wafCookies = await wafService.getCookies(for: provider)
            }

            let msg = try await api.checkIn(
                provider: provider,
                apiUser: account.apiUser,
                sessionCookie: cookie,
                wafCookies: wafCookies
            )
            s.lastCheckInDate = Date()
            s.status = .success(msg)
            NotificationService.send(title: account.name, body: msg)

            // Refresh after check-in
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

// Equatable for APIError pattern matching
extension AnyRouterAPI.APIError: Equatable {
    static func == (lhs: AnyRouterAPI.APIError, rhs: AnyRouterAPI.APIError) -> Bool {
        switch (lhs, rhs) {
        case (.sessionExpired, .sessionExpired): true
        case (.wafBlocked, .wafBlocked): true
        case (.invalidResponse, .invalidResponse): true
        case (.httpError(let a), .httpError(let b)): a == b
        case (.checkInFailed(let a), .checkInFailed(let b)): a == b
        default: false
        }
    }
}

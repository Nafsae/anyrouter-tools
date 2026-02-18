import Foundation
import SwiftData

@Observable
@MainActor
final class AccountListViewModel {
    private(set) var states: [UUID: AccountRuntimeState] = [:]
    private let api = AnyRouterAPI()
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
            let info = try await api.fetchUserInfo(
                provider: provider,
                apiUser: account.apiUser,
                sessionCookie: cookie
            )
            s.quota = info.quota
            s.usedQuota = info.usedQuota
            s.lastRefreshDate = Date()
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

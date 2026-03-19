import Foundation
import Combine

@MainActor
final class SchedulerService: ObservableObject {
    private let defaults: UserDefaults

    @Published var refreshInterval: TimeInterval {
        didSet {
            defaults.set(refreshInterval, forKey: Constants.Defaults.refreshIntervalKey)
            rescheduleRefresh()
        }
    }
    @Published var isAutoRefreshEnabled: Bool {
        didSet {
            defaults.set(isAutoRefreshEnabled, forKey: Constants.Defaults.autoRefreshEnabledKey)
            rescheduleRefresh()
        }
    }

    private var refreshTimer: Timer?
    private var checkInTimer: Timer?
    private var onRefresh: (() async -> Void)?
    private var onCheckIn: (() async -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.refreshInterval = Self.storedRefreshInterval(from: defaults)
        self.isAutoRefreshEnabled = defaults.object(forKey: Constants.Defaults.autoRefreshEnabledKey) as? Bool ?? true
    }

    func start(onRefresh: @escaping () async -> Void, onCheckIn: @escaping () async -> Void) {
        self.onRefresh = onRefresh
        self.onCheckIn = onCheckIn
        rescheduleRefresh()
        rescheduleCheckIn()
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        checkInTimer?.invalidate()
        checkInTimer = nil
    }

    func rescheduleCheckIn() {
        checkInTimer?.invalidate()
        checkInTimer = nil

        guard defaults.bool(forKey: Constants.Defaults.autoCheckInEnabledKey) else { return }

        let hour = defaults.object(forKey: Constants.Defaults.autoCheckInHourKey) as? Int ?? Constants.Defaults.autoCheckInHour
        let minute = defaults.object(forKey: Constants.Defaults.autoCheckInMinuteKey) as? Int ?? Constants.Defaults.autoCheckInMinute

        guard let next = nextFireDate(hour: hour, minute: minute) else { return }
        let interval = next.timeIntervalSinceNow
        guard interval > 0 else { return }

        checkInTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.onCheckIn?()
                // Reschedule for next day
                self.rescheduleCheckIn()
            }
        }
    }

    private static func storedRefreshInterval(from defaults: UserDefaults) -> TimeInterval {
        let raw = defaults.object(forKey: Constants.Defaults.refreshIntervalKey) as? TimeInterval ?? Constants.Defaults.refreshInterval
        return raw < 300 ? raw * 60 : raw
    }

    private func nextFireDate(hour: Int, minute: Int) -> Date? {
        let cal = Calendar.current
        let now = Date()
        var components = cal.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let today = cal.date(from: components) else { return nil }
        return today > now ? today : cal.date(byAdding: .day, value: 1, to: today)
    }

    private func rescheduleRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        guard isAutoRefreshEnabled else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.onRefresh?()
            }
        }
    }
}

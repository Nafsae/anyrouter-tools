import Foundation

@Observable
@MainActor
final class SchedulerService {
    var refreshInterval: TimeInterval = Constants.Defaults.refreshInterval {
        didSet { rescheduleRefresh() }
    }
    var isAutoRefreshEnabled = true {
        didSet { rescheduleRefresh() }
    }

    private var refreshTimer: Timer?
    private var checkInTimer: Timer?
    private var onRefresh: (() async -> Void)?
    private var onCheckIn: (() async -> Void)?

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

        guard UserDefaults.standard.bool(forKey: "autoCheckInEnabled") else { return }

        let hour = UserDefaults.standard.integer(forKey: "autoCheckInHour")
        let minute = UserDefaults.standard.integer(forKey: "autoCheckInMinute")

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

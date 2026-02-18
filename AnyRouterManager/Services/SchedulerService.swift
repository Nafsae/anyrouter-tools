import Foundation

@Observable
@MainActor
final class SchedulerService {
    var refreshInterval: TimeInterval = Constants.Defaults.refreshInterval {
        didSet { reschedule() }
    }
    var isAutoRefreshEnabled = true {
        didSet { reschedule() }
    }

    private var timer: Timer?
    private var onRefresh: (() async -> Void)?

    func start(onRefresh: @escaping () async -> Void) {
        self.onRefresh = onRefresh
        reschedule()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func reschedule() {
        timer?.invalidate()
        timer = nil
        guard isAutoRefreshEnabled else { return }
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.onRefresh?()
            }
        }
    }
}

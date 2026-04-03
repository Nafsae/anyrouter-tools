import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var vm: AccountListViewModel
    @AppStorage(Constants.Defaults.refreshIntervalKey) private var refreshIntervalSeconds = Constants.Defaults.refreshInterval
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage(Constants.Defaults.autoCheckInEnabledKey) private var autoCheckInEnabled = false
    @AppStorage(Constants.Defaults.autoCheckInHourKey) private var autoCheckInHour = Constants.Defaults.autoCheckInHour
    @AppStorage(Constants.Defaults.autoCheckInMinuteKey) private var autoCheckInMinute = Constants.Defaults.autoCheckInMinute

    private var refreshIntervalMinutes: Binding<Double> {
        Binding(
            get: { refreshIntervalSeconds / 60 },
            set: {
                let seconds = $0 * 60
                refreshIntervalSeconds = seconds
                vm.scheduler.refreshInterval = seconds
            }
        )
    }

    private let intervals: [(String, Double)] = [
        ("5 分钟", 5),
        ("15 分钟", 15),
        ("30 分钟", 30),
        ("60 分钟", 60),
    ]

    var body: some View {
        Form {
            Section("自动刷新") {
                Picker("刷新间隔", selection: refreshIntervalMinutes) {
                    ForEach(intervals, id: \.1) { label, value in
                        Text(label).tag(value)
                    }
                }

                Toggle("启用自动刷新", isOn: Binding(
                    get: { vm.scheduler.isAutoRefreshEnabled },
                    set: { vm.scheduler.isAutoRefreshEnabled = $0 }
                ))
            }

            Section("自动签到") {
                Toggle("每日自动签到", isOn: $autoCheckInEnabled)
                    .onChange(of: autoCheckInEnabled) { _, _ in
                        vm.scheduler.rescheduleCheckIn()
                    }

                if autoCheckInEnabled {
                    HStack {
                        Text("签到时间")
                        Spacer()
                        Picker("小时", selection: $autoCheckInHour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(String(format: "%02d", h)).tag(h)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 76)
                        .onChange(of: autoCheckInHour) { _, _ in
                            vm.scheduler.rescheduleCheckIn()
                        }

                        Text(":")

                        Picker("分钟", selection: $autoCheckInMinute) {
                            ForEach(0..<60, id: \.self) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 76)
                        .onChange(of: autoCheckInMinute) { _, _ in
                            vm.scheduler.rescheduleCheckIn()
                        }
                    }

                    Button("快捷设置为每天 11:00") {
                        autoCheckInHour = 11
                        autoCheckInMinute = 0
                        vm.scheduler.rescheduleCheckIn()
                    }
                    .buttonStyle(.link)

                    if let next = nextCheckInText() {
                        Text("下次签到：\(next)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("通知") {
                Toggle("签到结果通知", isOn: $notificationsEnabled)
            }

            Section("关于") {
                LabeledContent("版本", value: "1.0.1")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 420)
    }

    private func nextCheckInText() -> String? {
        let cal = Calendar.current
        let now = Date()
        var comp = cal.dateComponents([.year, .month, .day], from: now)
        comp.hour = autoCheckInHour
        comp.minute = autoCheckInMinute
        comp.second = 0
        guard let today = cal.date(from: comp) else { return nil }
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: today) else { return nil }
        let next = today > now ? today : tomorrow
        let fmt = DateFormatter()
        fmt.dateFormat = "MM-dd HH:mm"
        return fmt.string(from: next)
    }
}

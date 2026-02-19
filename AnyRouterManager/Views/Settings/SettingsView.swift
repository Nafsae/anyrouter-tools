import SwiftUI

struct SettingsView: View {
    @Environment(AccountListViewModel.self) private var vm
    @AppStorage("refreshInterval") private var refreshInterval = 15.0
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("autoCheckInEnabled") private var autoCheckInEnabled = false
    @AppStorage("autoCheckInHour") private var autoCheckInHour = 8
    @AppStorage("autoCheckInMinute") private var autoCheckInMinute = 0

    private let intervals: [(String, Double)] = [
        ("5 分钟", 5),
        ("15 分钟", 15),
        ("30 分钟", 30),
        ("60 分钟", 60),
    ]

    var body: some View {
        Form {
            Section("自动刷新") {
                Picker("刷新间隔", selection: $refreshInterval) {
                    ForEach(intervals, id: \.1) { label, value in
                        Text(label).tag(value)
                    }
                }
                .onChange(of: refreshInterval) { _, newValue in
                    vm.scheduler.refreshInterval = newValue * 60
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
                        Picker("", selection: $autoCheckInHour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(String(format: "%02d", h)).tag(h)
                            }
                        }
                        .frame(width: 70)
                        .onChange(of: autoCheckInHour) { _, _ in
                            vm.scheduler.rescheduleCheckIn()
                        }

                        Text(":")

                        Picker("", selection: $autoCheckInMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
                        .frame(width: 70)
                        .onChange(of: autoCheckInMinute) { _, _ in
                            vm.scheduler.rescheduleCheckIn()
                        }
                    }

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
        .frame(width: 400, height: 400)
    }

    private func nextCheckInText() -> String? {
        let cal = Calendar.current
        let now = Date()
        var comp = cal.dateComponents([.year, .month, .day], from: now)
        comp.hour = autoCheckInHour
        comp.minute = autoCheckInMinute
        comp.second = 0
        guard let today = cal.date(from: comp) else { return nil }
        let next = today > now ? today : cal.date(byAdding: .day, value: 1, to: today)!
        let fmt = DateFormatter()
        fmt.dateFormat = "MM-dd HH:mm"
        return fmt.string(from: next)
    }
}

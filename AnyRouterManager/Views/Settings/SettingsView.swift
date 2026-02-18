import SwiftUI

struct SettingsView: View {
    @Environment(AccountListViewModel.self) private var vm
    @AppStorage("refreshInterval") private var refreshInterval = 15.0
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

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

            Section("通知") {
                Toggle("签到结果通知", isOn: $notificationsEnabled)
            }

            Section("关于") {
                LabeledContent("版本", value: "1.0.0")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 320)
    }
}

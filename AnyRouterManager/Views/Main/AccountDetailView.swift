import SwiftUI

struct AccountDetailView: View {
    let account: Account
    @Environment(AccountListViewModel.self) private var vm
    @State private var showEditForm = false

    var body: some View {
        let s = vm.state(for: account)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.name)
                            .font(.title2.bold())
                        Text(account.provider)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: "$%.2f", s.balance))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(s.balance > 0 ? .green : .red)
                }

                Divider()

                // Quota details
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                    GridRow {
                        Text("当前余额").foregroundStyle(.secondary)
                        Text(String(format: "$%.2f", s.balance))
                            .monospacedDigit()
                            .bold()
                    }
                    GridRow {
                        Text("历史消耗").foregroundStyle(.secondary)
                        Text(String(format: "$%.2f", s.usedQuota)).monospacedDigit()
                    }
                    GridRow {
                        Text("总额度").foregroundStyle(.secondary)
                        Text(String(format: "$%.2f", s.totalQuota)).monospacedDigit()
                    }
                    GridRow {
                        Text("API User").foregroundStyle(.secondary)
                        Text(account.apiUser).monospacedDigit()
                    }
                    GridRow {
                        Text("最后刷新").foregroundStyle(.secondary)
                        if let date = s.lastRefreshDate {
                            Text(date, format: .dateTime)
                        } else {
                            Text("—").foregroundStyle(.tertiary)
                        }
                    }
                    GridRow {
                        Text("最后签到").foregroundStyle(.secondary)
                        if let date = s.lastCheckInDate {
                            Text(date, format: .dateTime)
                        } else {
                            Text("—").foregroundStyle(.tertiary)
                        }
                    }
                }

                Divider()

                // Status
                HStack {
                    Label(s.statusText, systemImage: statusIcon(s.status))
                        .foregroundStyle(statusColor(s.status))
                }

                Divider()

                // Actions
                HStack(spacing: 12) {
                    Button {
                        Task { await vm.refresh(account: account) }
                    } label: {
                        Label("刷新余额", systemImage: "arrow.clockwise")
                    }
                    .disabled(s.isLoading)

                    Button {
                        Task { await vm.checkIn(account: account) }
                    } label: {
                        Label("签到", systemImage: "checkmark.circle")
                    }
                    .disabled(s.isLoading)

                    Spacer()

                    Button("编辑") {
                        showEditForm = true
                    }
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showEditForm) {
            AccountFormView(mode: .edit(account))
        }
    }

    private func statusIcon(_ status: AccountStatus) -> String {
        switch status {
        case .idle: "circle"
        case .refreshing, .checkingIn: "arrow.2.circlepath"
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    private func statusColor(_ status: AccountStatus) -> Color {
        switch status {
        case .idle: .secondary
        case .refreshing, .checkingIn: .blue
        case .success: .green
        case .error: .red
        }
    }
}

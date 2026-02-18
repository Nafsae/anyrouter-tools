import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(AccountListViewModel.self) private var vm
    @Query(filter: #Predicate<Account> { $0.isEnabled }, sort: \Account.name) private var accounts: [Account]
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("AnyRouter")
                    .font(.headline)
                Spacer()
                Text(vm.totalBalanceText)
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(.green)
            }

            Divider()

            // Account summaries
            if accounts.isEmpty {
                Text("暂无账号")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(accounts) { account in
                    let s = vm.state(for: account)
                    HStack {
                        Circle()
                            .fill(statusColor(s.status))
                            .frame(width: 8, height: 8)
                        Text(account.name)
                            .lineLimit(1)
                        Spacer()
                        Text(String(format: "$%.2f", s.balance))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button("刷新全部") {
                    Task { await vm.refreshAll(accounts: accounts) }
                }
                Button("全部签到") {
                    Task { await vm.checkInAll(accounts: accounts) }
                }
                Spacer()
                Button("打开详情") {
                    openWindow(id: "main")
                }
            }
            .buttonStyle(.borderless)

            Divider()

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .frame(width: 280)
    }

    private func statusColor(_ status: AccountStatus) -> Color {
        switch status {
        case .idle: .gray
        case .refreshing, .checkingIn: .blue
        case .success: .green
        case .error: .red
        }
    }
}

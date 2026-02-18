import SwiftUI

struct AccountRowView: View {
    let account: Account
    @Environment(AccountListViewModel.self) private var vm

    var body: some View {
        let s = vm.state(for: account)

        HStack(spacing: 10) {
            // Status indicator
            Circle()
                .fill(statusColor(s.status))
                .frame(width: 10, height: 10)
                .overlay {
                    if s.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(account.name)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if !account.isEnabled {
                        Text("已禁用")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Text(String(format: "$%.2f", s.balance))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(s.balance > 0 ? .green : .red)

                    if let date = s.lastRefreshDate {
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Status text
            if case .error(let msg) = s.status {
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .frame(maxWidth: 100, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
        .opacity(account.isEnabled ? 1 : 0.5)
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

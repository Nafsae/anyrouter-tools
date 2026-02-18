import SwiftUI
import SwiftData

struct AccountListView: View {
    let accounts: [Account]
    @Binding var selectedAccount: Account?
    @Environment(AccountListViewModel.self) private var vm
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List(sortedAccounts, selection: $selectedAccount) { account in
            AccountRowView(account: account)
                .tag(account)
                .contextMenu {
                    Button("刷新") {
                        Task { await vm.refresh(account: account) }
                    }
                    Button("签到") {
                        Task { await vm.checkIn(account: account) }
                    }
                    Divider()
                    Button(account.isEnabled ? "禁用" : "启用") {
                        account.isEnabled.toggle()
                    }
                    Divider()
                    Button("删除", role: .destructive) {
                        delete(account)
                    }
                }
        }
        .listStyle(.sidebar)
        .overlay {
            if accounts.isEmpty {
                ContentUnavailableView("暂无账号", systemImage: "tray", description: Text("点击 + 添加你的 AnyRouter 账号"))
            }
        }
    }

    /// Sort: error > idle > success; disabled last
    private var sortedAccounts: [Account] {
        accounts.sorted { a, b in
            if a.isEnabled != b.isEnabled { return a.isEnabled }
            let sa = vm.state(for: a).status
            let sb = vm.state(for: b).status
            return statusOrder(sa) < statusOrder(sb)
        }
    }

    private func statusOrder(_ s: AccountStatus) -> Int {
        switch s {
        case .error: 0
        case .idle: 1
        case .refreshing, .checkingIn: 2
        case .success: 3
        }
    }

    private func delete(_ account: Account) {
        KeychainService.delete(for: account.id)
        vm.removeState(for: account.id)
        if selectedAccount?.id == account.id { selectedAccount = nil }
        modelContext.delete(account)
    }
}

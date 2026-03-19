import SwiftUI
import SwiftData

struct MainWindowView: View {
    @EnvironmentObject private var vm: AccountListViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name) private var accounts: [Account]
    @State private var showAddForm = false
    @State private var selectedAccount: Account?

    var body: some View {
        NavigationSplitView {
            AccountListView(accounts: accounts, selectedAccount: $selectedAccount)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320)
        } detail: {
            if let account = selectedAccount {
                AccountDetailView(account: account)
            } else {
                ContentUnavailableView("选择一个账号", systemImage: "person.crop.circle", description: Text("在左侧选择账号查看详情"))
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showAddForm = true
                } label: {
                    Label("添加账号", systemImage: "plus")
                }

                Button {
                    Task { await vm.refreshAll(accounts: accounts) }
                } label: {
                    Label("刷新全部", systemImage: "arrow.clockwise")
                }

                Button {
                    Task { await vm.checkInAll(accounts: accounts) }
                } label: {
                    Label("全部签到", systemImage: "checkmark.circle")
                }

                Button {
                    vm.exportAllCookies(accounts: accounts)
                } label: {
                    Label("导出全部 Cookie", systemImage: "square.and.arrow.up")
                }
                .disabled(accounts.isEmpty)

                Button {
                    Task { await vm.testAllAPIKeys(accounts: accounts) }
                } label: {
                    Label("测试全部 Key", systemImage: "key.fill")
                }
                .disabled(accounts.isEmpty || vm.isTestingAllKeys)
            }
        }
        .sheet(isPresented: $showAddForm) {
            AccountFormView(mode: .add)
        }
        .onAppear {
            vm.prepareStates(for: accounts)
            NotificationService.requestPermission()
            vm.scheduler.start(
                onRefresh: { await vm.refreshAll(accounts: accounts) },
                onCheckIn: { await vm.checkInAll(accounts: accounts) }
            )
            vm.triggerInitialRefreshIfNeeded(accounts: accounts)
        }
        .onChange(of: accounts.count) { _, _ in
            vm.prepareStates(for: accounts)
        }
    }
}

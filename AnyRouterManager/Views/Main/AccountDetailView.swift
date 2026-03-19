import AppKit
import SwiftUI

struct AccountDetailView: View {
    let account: Account
    @EnvironmentObject private var vm: AccountListViewModel
    @State private var showEditForm = false
    @State private var isTestingAPIKey = false
    @State private var actionMessage: String?
    @State private var editingAPIKey = ""
    @State private var isEditingAPIKey = false

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

                // Inline API Key Editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key（令牌）")
                        .font(.headline)

                    if isEditingAPIKey {
                        HStack(spacing: 8) {
                            SecureField("输入 API Key", text: $editingAPIKey)
                                .textFieldStyle(.roundedBorder)

                            Button("保存") {
                                saveAPIKey()
                            }
                            .disabled(editingAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("取消") {
                                isEditingAPIKey = false
                                editingAPIKey = ""
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text(apiKeySummary)
                                .monospacedDigit()
                                .foregroundStyle(hasAPIKey ? .primary : .tertiary)

                            Spacer()

                            Button {
                                editingAPIKey = storedAPIKey ?? ""
                                isEditingAPIKey = true
                            } label: {
                                Label(hasAPIKey ? "修改" : "设置", systemImage: "pencil")
                            }

                            if hasAPIKey {
                                Button {
                                    copyAPIKey()
                                } label: {
                                    Label("复制", systemImage: "doc.on.doc")
                                }

                                Button {
                                    Task { await testAPIKey() }
                                } label: {
                                    if isTestingAPIKey {
                                        Label("测试中…", systemImage: "hourglass")
                                    } else {
                                        Label("测试", systemImage: "key")
                                    }
                                }
                                .disabled(isTestingAPIKey)

                                Button(role: .destructive) {
                                    deleteAPIKey()
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }

                    if let result = vm.state(for: account).apiKeyTestResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.hasPrefix("Key 可用") ? .green : .orange)
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

                    Button {
                        exportCookie()
                    } label: {
                        Label("导出 Cookie", systemImage: "doc.on.doc")
                    }

                    Spacer()

                    Button("编辑") {
                        showEditForm = true
                    }
                }

                if let actionMessage {
                    Text(actionMessage)
                        .font(.caption)
                        .foregroundStyle(actionMessage.hasPrefix("Cookie 已") || actionMessage.hasPrefix("Key 可用") ? .green : .red)
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showEditForm) {
            AccountFormView(mode: .edit(account))
        }
    }

    private var storedAPIKey: String? {
        KeychainService.loadAPIKey(for: account.id)
    }

    private var hasAPIKey: Bool {
        guard let storedAPIKey else { return false }
        return !storedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var apiKeySummary: String {
        guard let storedAPIKey else { return "未设置" }
        let trimmed = storedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "未设置" }
        let suffix = String(trimmed.suffix(min(4, trimmed.count)))
        return String(repeating: "•", count: max(8, min(16, trimmed.count))) + suffix
    }

    private func exportCookie() {
        guard let cookie = KeychainService.load(for: account.id), !cookie.isEmpty else {
            actionMessage = "导出失败：未找到 Cookie"
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cookie, forType: .string)
        actionMessage = "Cookie 已复制到剪贴板"
    }

    private func saveAPIKey() {
        let trimmed = editingAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try KeychainService.saveAPIKey(trimmed, for: account.id)
            isEditingAPIKey = false
            editingAPIKey = ""
            actionMessage = "API Key 已保存"
        } catch {
            actionMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func deleteAPIKey() {
        KeychainService.deleteAPIKey(for: account.id)
        isEditingAPIKey = false
        editingAPIKey = ""
        vm.state(for: account).apiKeyTestResult = nil
        actionMessage = "API Key 已删除"
    }

    private func copyAPIKey() {
        guard let apiKey = storedAPIKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            actionMessage = "复制失败：未找到 API Key"
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(apiKey, forType: .string)
        actionMessage = "API Key 已复制到剪贴板"
    }

    private func testAPIKey() async {
        guard let apiKey = storedAPIKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            actionMessage = "测试失败：请先设置 API Key"
            return
        }

        isTestingAPIKey = true
        actionMessage = "测试中…"

        do {
            let provider = ProviderConfig.provider(for: account.provider)
            let result = try await AnyRouterAPI().testAPIKey(provider: provider, apiKey: apiKey)
            actionMessage = result
        } catch {
            actionMessage = "测试失败：\(error.localizedDescription)"
        }

        isTestingAPIKey = false
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

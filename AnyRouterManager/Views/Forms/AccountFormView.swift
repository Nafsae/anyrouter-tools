import SwiftUI
import SwiftData

enum AccountFormMode {
    case add
    case edit(Account)
}

struct AccountFormView: View {
    let mode: AccountFormMode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var formVM = AccountFormViewModel()
    @State private var errorMessage: String?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "编辑账号" : "添加账号")
                .font(.headline)
                .padding()

            Form {
                Section("1. 粘贴 Cookie 并识别") {
                    Picker("Provider", selection: $formVM.provider) {
                        ForEach(AccountFormViewModel.providers, id: \.self) { p in
                            Text(p).tag(p)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Session Cookie")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $formVM.sessionCookie)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(.quaternary)
                            )
                    }

                    HStack {
                        Button {
                            Task { await formVM.detectAccount() }
                        } label: {
                            if formVM.isDetecting {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 16, height: 16)
                                Text(formVM.detectMessage ?? "识别中…")
                                    .font(.caption)
                            } else {
                                Label("自动识别", systemImage: "magnifyingglass")
                            }
                        }
                        .disabled(!formVM.canDetect)

                        if let msg = formVM.detectMessage, !formVM.isDetecting {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(msg.hasPrefix("识别成功") ? .green : .red)
                                .lineLimit(2)
                        }
                    }
                }

                Section("2. 确认账号信息") {
                    TextField("名称", text: $formVM.name, prompt: Text("自动填充或手动输入"))
                    TextField("邮箱", text: $formVM.email, prompt: Text("可选，方便备注"))
                    TextField("API User", text: $formVM.apiUser, prompt: Text("自动填充或手动输入"))
                }

                if let err = errorMessage {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "保存" : "添加") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isEditing ? formVM.name.isEmpty : !formVM.isValid)
            }
            .padding()
        }
        .frame(width: 500, height: 420)
        .onAppear {
            if case .edit(let account) = mode {
                formVM.load(from: account)
            }
        }
    }

    private func save() {
        do {
            switch mode {
            case .add:
                try formVM.save(context: modelContext)
            case .edit(let account):
                try formVM.update(account: account, context: modelContext)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

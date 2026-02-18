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
            // Title
            Text(isEditing ? "编辑账号" : "添加账号")
                .font(.headline)
                .padding()

            Form {
                TextField("名称", text: $formVM.name, prompt: Text("例如: 主账号"))

                TextField("API User", text: $formVM.apiUser, prompt: Text("数字 ID"))

                Picker("Provider", selection: $formVM.provider) {
                    ForEach(AccountFormViewModel.providers, id: \.self) { p in
                        Text(p).tag(p)
                    }
                }

                SecureField("Session Cookie", text: $formVM.sessionCookie, prompt: Text(isEditing ? "留空则保持不变" : "session=xxx 或纯 value"))
                    .help("从浏览器 DevTools → Application → Cookies 复制 session 值")

                if let err = errorMessage {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)

            // Buttons
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
        .frame(width: 420)
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

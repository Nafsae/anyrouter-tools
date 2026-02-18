import SwiftUI
import SwiftData

@main
struct AnyRouterManagerApp: App {
    @State private var listVM = AccountListViewModel()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Account.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(listVM)
        } label: {
            Label {
                Text("AnyRouter")
            } icon: {
                Image(systemName: "antenna.radiowaves.left.and.right")
            }
        }
        .menuBarExtraStyle(.window)

        WindowGroup {
            MainWindowView()
                .environment(listVM)
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 720, height: 520)

        Settings {
            SettingsView()
                .environment(listVM)
        }
    }
}

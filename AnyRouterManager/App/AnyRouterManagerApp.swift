import SwiftUI
import SwiftData
import AppKit

@main
struct AnyRouterManagerApp: App {
    @StateObject private var listVM = AccountListViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: AnyRouterSchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, migrationPlan: AnyRouterMigrationPlan.self, configurations: [config])
        } catch {
            NSLog("[AnyRouterManager] ModelContainer failed: \(error). Falling back to in-memory store.")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, migrationPlan: AnyRouterMigrationPlan.self, configurations: [fallback])
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environmentObject(listVM)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 720, height: 520)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(listVM)
                .modelContainer(sharedModelContainer)
        } label: {
            Label("AnyRouter", systemImage: "network")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(listVM)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
}

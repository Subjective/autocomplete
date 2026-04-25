import AppKit
import SwiftUI

@main
struct TabAnywhereApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var coordinator = CompletionCoordinator()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("TabAnywhere", id: "main") {
            ContentView(coordinator: coordinator)
                .frame(minWidth: 720, minHeight: 520)
                .onAppear {
                    coordinator.start()
                }
        }

        Settings {
            SettingsView(coordinator: coordinator)
                .frame(width: 500)
        }

        MenuBarExtra("TabAnywhere", systemImage: "text.cursor") {
            MenuBarContentView(coordinator: coordinator) {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var coordinator: CompletionCoordinator
    let openMainWindow: () -> Void

    var body: some View {
        Button("Open TabAnywhere") {
            openMainWindow()
        }

        Divider()

        Button(coordinator.isEnabled ? "Pause" : "Resume") {
            coordinator.toggleEnabled()
        }

        Button("Inspect Focus") {
            coordinator.refreshFocusedContextNow()
        }

        Button("Accessibility Settings") {
            coordinator.openAccessibilitySettings()
        }

        Divider()

        Text(coordinator.hasAccessibilityPermission ? "Accessibility: allowed" : "Accessibility: needed")
        Text("Hotkey: \(coordinator.acceptanceHotKeyDescription)")
    }
}

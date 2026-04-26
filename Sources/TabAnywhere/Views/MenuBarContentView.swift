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

        Button("Screen Recording Settings") {
            coordinator.openScreenRecordingSettings()
        }

        Divider()

        Text(coordinator.hasAccessibilityPermission ? "Accessibility: allowed" : "Accessibility: needed")
        Text(coordinator.hasScreenRecordingPermission ? "Screen Recording: allowed" : "Screen Recording: needed")
        Text("Hotkey: \(coordinator.acceptanceHotKeyDescription)")
    }
}

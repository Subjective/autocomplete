import SwiftUI

struct SettingsView: View {
    @ObservedObject var coordinator: CompletionCoordinator

    var body: some View {
        Form {
            Section("Completion") {
                Toggle("Enable suggestions", isOn: Binding(
                    get: { coordinator.isEnabled },
                    set: { _ in coordinator.toggleEnabled() }
                ))

                LabeledContent("Accept suggestion", value: coordinator.acceptanceHotKeyDescription)
                LabeledContent("Suggestion style", value: coordinator.suggestionStyleDescription)
                LabeledContent("Provider", value: coordinator.providerDescription)
                LabeledContent("Model", value: coordinator.selectedModelDescription)

                Picker("Hotkey", selection: Binding(
                    get: { coordinator.acceptanceHotKey },
                    set: { coordinator.setAcceptanceHotKey($0) }
                )) {
                    ForEach(AcceptanceHotKey.allCases) { hotKey in
                        Text(hotKey.label).tag(hotKey)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Style", selection: Binding(
                    get: { coordinator.suggestionStyle },
                    set: { coordinator.setSuggestionStyle($0) }
                )) {
                    ForEach(SuggestionPresentationStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
            }

            Section {
                ModelManagementSection(coordinator: coordinator, isCompact: true)
            }

            Section("Permissions") {
                LabeledContent("Accessibility", value: coordinator.hasAccessibilityPermission ? "Allowed" : "Needed")
                LabeledContent("Screen Recording", value: coordinator.hasScreenRecordingPermission ? "Allowed" : "Needed")

                HStack {
                    Button("Request Permission") {
                        coordinator.requestAccessibilityPermission()
                    }

                    Button("Open Privacy Settings") {
                        coordinator.openAccessibilitySettings()
                    }
                }

                Toggle("Use screenshots as context", isOn: Binding(
                    get: { coordinator.screenshotContextEnabled },
                    set: { coordinator.setScreenshotContextEnabled($0) }
                ))

                HStack {
                    Button("Request Screen Recording") {
                        coordinator.requestScreenRecordingPermission()
                    }

                    Button("Open Screen Recording Settings") {
                        coordinator.openScreenRecordingSettings()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

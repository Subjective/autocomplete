import SwiftUI

struct ContentView: View {
    @ObservedObject var coordinator: CompletionCoordinator
    @State private var nativeFieldText = ""
    @State private var nativeEditorText = ""

    var body: some View {
        NavigationSplitView {
            List {
                Section("Status") {
                    Label("MVP Loop", systemImage: "text.cursor")
                    Label("Permissions", systemImage: coordinator.hasAccessibilityPermission ? "checkmark.circle" : "exclamationmark.triangle")
                    Label("Mock Provider", systemImage: "wand.and.stars")
                }

                Section("Targets") {
                    Label("TextEdit", systemImage: "doc.text")
                    Label("Native Field", systemImage: "macwindow")
                    Label("Safari / Chrome Textarea", systemImage: "safari")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("TabAnywhere")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    statusSection
                    nativeTestSection
                    eventSection
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("System-wide Tab Autocomplete")
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(coordinator.hasAccessibilityPermission ? "Ready for supported fields" : "Accessibility permission needed")
                        .font(.title2.weight(.semibold))

                    Text(coordinator.statusMessage)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()

                Toggle("Enabled", isOn: Binding(
                    get: { coordinator.isEnabled },
                    set: { _ in coordinator.toggleEnabled() }
                ))
                .toggleStyle(.switch)
            }

            Divider()

            LabeledContent("Focused field", value: coordinator.focusedAppDescription)
            LabeledContent("Accept hotkey", value: coordinator.acceptanceHotKeyDescription)
            LabeledContent("Active suggestion", value: coordinator.activeSuggestionText.isEmpty ? "None" : coordinator.activeSuggestionText)

            HStack {
                Button {
                    coordinator.requestAccessibilityPermission()
                } label: {
                    Label("Request Permission", systemImage: "hand.raised")
                }

                Button {
                    coordinator.openAccessibilitySettings()
                } label: {
                    Label("Privacy Settings", systemImage: "gearshape")
                }

                Button {
                    coordinator.refreshFocusedContextNow()
                } label: {
                    Label("Inspect Focus", systemImage: "scope")
                }
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.separator.opacity(0.7), lineWidth: 1)
        }
    }

    private var nativeTestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Native Test Field")
                .font(.headline)

            TextField("Type “thank”, “let”, or “todo” and pause", text: $nativeFieldText, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $nativeEditorText)
                .font(.body)
                .frame(minHeight: 120)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.separator.opacity(0.7), lineWidth: 1)
                }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.separator.opacity(0.7), lineWidth: 1)
        }
    }

    private var eventSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Local Debug Events")
                .font(.headline)

            if coordinator.recentEvents.isEmpty {
                Text("No events yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(coordinator.recentEvents, id: \.self) { event in
                    Text(event)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.separator.opacity(0.7), lineWidth: 1)
        }
    }
}

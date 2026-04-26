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
                    Label("Screen Context", systemImage: coordinator.hasScreenRecordingPermission ? "camera.viewfinder" : "camera.viewfinder")
                    Label(coordinator.providerDescription, systemImage: "cpu")
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
                    styleLabSection
                    modelSection
                    nativeTestSection
                    promptInspectorSection
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
            LabeledContent("Suggestion style", value: coordinator.suggestionStyleDescription)
            LabeledContent("Provider", value: coordinator.providerDescription)
            LabeledContent("Model", value: coordinator.selectedModelDescription)
            LabeledContent("Screen context", value: coordinator.screenContextStatusMessage)
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

            HStack {
                Toggle("Screenshot Context", isOn: Binding(
                    get: { coordinator.screenshotContextEnabled },
                    set: { coordinator.setScreenshotContextEnabled($0) }
                ))
                .toggleStyle(.switch)

                Button {
                    coordinator.requestScreenRecordingPermission()
                } label: {
                    Label("Request Screen Recording", systemImage: "camera.viewfinder")
                }

                Button {
                    coordinator.openScreenRecordingSettings()
                } label: {
                    Label("Screen Settings", systemImage: "gearshape")
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

    private var styleLabSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Style Lab")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
                ForEach(SuggestionPresentationStyle.allCases) { style in
                    SuggestionStylePreviewCard(
                        style: style,
                        hotKey: coordinator.acceptanceHotKeyDescription,
                        isSelected: style == coordinator.suggestionStyle,
                        selectAction: {
                            coordinator.setSuggestionStyle(style)
                        }
                    )
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

    private var modelSection: some View {
        ModelManagementSection(coordinator: coordinator)
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

    private var promptInspectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Prompt Inspector")
                    .font(.headline)

                Spacer()

                if let snapshot = coordinator.lastPromptSnapshot {
                    Text(DateFormatter.tabAnywhereTime.string(from: snapshot.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let snapshot = coordinator.lastPromptSnapshot {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Provider", value: snapshot.provider)
                    LabeledContent("Model", value: snapshot.model)
                    LabeledContent("Transport", value: snapshot.transportDescription)
                    LabeledContent("Result", value: snapshot.result)
                }

                screenContextPreview(for: snapshot)
                promptBlock(title: "System", text: snapshot.systemPrompt)
                promptBlock(title: "User", text: snapshot.userPrompt)
            } else {
                Text("No prompt captured yet")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.separator.opacity(0.7), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func screenContextPreview(for snapshot: PromptInspectionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Screen")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let screenContext = snapshot.screenContext,
               let nsImage = NSImage(data: screenContext.imageData) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(.separator.opacity(0.7), lineWidth: 1)
                        }

                    Text(screenContext.promptDescription)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } else {
                Text(snapshot.screenContextStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func promptBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView {
                Text(text.isEmpty ? "Empty" : text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(minHeight: 80, maxHeight: 180)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}

private struct SuggestionStylePreviewCard: View {
    let style: SuggestionPresentationStyle
    let hotKey: String
    let isSelected: Bool
    let selectAction: () -> Void

    var body: some View {
        Button(action: selectAction) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: style.systemImage)
                        .foregroundStyle(.secondary)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(style.title)
                            .font(.subheadline.weight(.semibold))
                        Text(style.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.quaternary.opacity(0.45))

                    SuggestionBubbleView(
                        text: " — completed by TabAnywhere.",
                        style: style,
                        hotKey: hotKey
                    )
                    .padding(10)
                }
                .frame(height: style == .commandPalette ? 78 : 64)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.85) : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isSelected)
    }
}

import SwiftUI

struct ModelManagementSection: View {
    @ObservedObject var coordinator: CompletionCoordinator
    var isCompact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Models")
                        .font(.headline)
                    Text(coordinator.modelStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()
            }

            Picker("Provider", selection: Binding(
                get: { coordinator.selectedProviderKind },
                set: { coordinator.setProviderKind($0) }
            )) {
                ForEach(CompletionProviderKind.allCases) { provider in
                    Text(provider.title).tag(provider)
                }
            }
            .pickerStyle(.segmented)

            switch coordinator.selectedProviderKind {
            case .mock:
                Text(CompletionProviderKind.mock.summary)
                    .foregroundStyle(.secondary)
            case .localLlama:
                localModelControls
            case .huggingFaceRouter:
                cloudControls(provider: .huggingFaceRouter)
            case .gemini:
                cloudControls(provider: .gemini)
            case .openAICompatible:
                cloudControls(provider: .openAICompatible)
            }
        }
    }

    private var localModelControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Search Hugging Face GGUF models", text: Binding(
                    get: { coordinator.modelSearchQuery },
                    set: { coordinator.setModelSearchQuery($0) }
                ))
                .textFieldStyle(.roundedBorder)

                Button {
                    coordinator.searchModels()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .disabled(coordinator.isSearchingModels)
            }

            if coordinator.isSearchingModels {
                ProgressView()
            }

            if !coordinator.modelSearchResults.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(coordinator.modelSearchResults.prefix(isCompact ? 4 : 8)) { result in
                        modelResultRow(result)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Selected repo", value: coordinator.selectedModelID)

                if let selectedResult = selectedSearchResult, !selectedResult.ggufFiles.isEmpty {
                    Picker("GGUF file", selection: Binding(
                        get: { coordinator.selectedGGUFFile },
                        set: { coordinator.setSelectedGGUFFile($0) }
                    )) {
                        ForEach(selectedResult.ggufFiles) { file in
                            Text("\(file.name) · \(file.sizeDescription)").tag(file.path)
                        }
                    }
                } else {
                    TextField("GGUF filename", text: Binding(
                        get: { coordinator.selectedGGUFFile },
                        set: { coordinator.setSelectedGGUFFile($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Button {
                        coordinator.downloadSelectedModel()
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                    .disabled(coordinator.isDownloadingModel || coordinator.selectedGGUFFile.isEmpty)

                    Button {
                        coordinator.chooseLocalModelFile()
                    } label: {
                        Label("Choose File", systemImage: "folder")
                    }
                }

                if coordinator.isDownloadingModel {
                    ProgressView(value: coordinator.modelDownloadProgress)
                }

                LabeledContent("Local path", value: coordinator.localModelPath.isEmpty ? "None" : coordinator.localModelPath)
            }
        }
    }

    private func cloudControls(provider: CompletionProviderKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if provider == .openAICompatible {
                TextField("Base URL", text: Binding(
                    get: { coordinator.cloudBaseURL },
                    set: { coordinator.setCloudBaseURL($0) }
                ))
                .textFieldStyle(.roundedBorder)
            } else if provider == .huggingFaceRouter {
                LabeledContent("Base URL", value: "https://router.huggingface.co/v1")
            }

            TextField("Model ID", text: Binding(
                get: { coordinator.cloudModelID },
                set: { coordinator.setCloudModelID($0) }
            ))
            .textFieldStyle(.roundedBorder)

            SecureField(apiKeyPlaceholder(for: provider), text: Binding(
                get: { coordinator.cloudAPIKey },
                set: { coordinator.setCloudAPIKey($0) }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    private func apiKeyPlaceholder(for provider: CompletionProviderKind) -> String {
        switch provider {
        case .huggingFaceRouter:
            "Hugging Face token"
        case .gemini:
            "Google AI Studio API key"
        case .openAICompatible:
            "API key"
        case .mock, .localLlama:
            "API key"
        }
    }

    private func modelResultRow(_ result: ModelSearchResult) -> some View {
        Button {
            coordinator.selectModelSearchResult(result)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: result.id == coordinator.selectedModelID ? "checkmark.circle.fill" : "shippingbox")
                    .foregroundStyle(result.id == coordinator.selectedModelID ? Color.accentColor : Color.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(result.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var selectedSearchResult: ModelSearchResult? {
        coordinator.modelSearchResults.first { $0.id == coordinator.selectedModelID }
    }
}

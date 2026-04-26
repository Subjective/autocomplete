import AnyLanguageModel
import Foundation

struct AnyLanguageModelProviderConfiguration: Equatable {
    let kind: CompletionProviderKind
    let localModelPath: String
    let cloudBaseURL: String
    let cloudAPIKey: String
    let cloudModelID: String
    let allowsScreenImageInput: Bool
}

final class AnyLanguageModelCompletionProvider: CompletionProviding {
    private let configuration: AnyLanguageModelProviderConfiguration
    private let editPromptBuilder = EditPredictionPromptBuilder()
    private var cachedModel: (any LanguageModel)?

    init(configuration: AnyLanguageModelProviderConfiguration) {
        self.configuration = configuration
    }

    func promptPayload(for context: CompletionContext) -> CompletionPromptPayload {
        guard let window = context.editableTextWindow() else {
            return CompletionPromptPayload(
                systemPrompt: editPromptBuilder.instructions,
                userPrompt: "No editable text window available."
            )
        }

        return editPromptBuilder.payload(
            for: context,
            window: window,
            includeScreenImage: shouldAttachScreenImage(for: context)
        )
    }

    func suggestions(for context: CompletionContext, maximumCount: Int) async throws -> [CompletionSuggestion] {
        guard let window = context.editableTextWindow() else {
            return []
        }

        let model = try await makeModel()
        let boundedMaximumCount = min(max(maximumCount, 1), 3)
        let includeScreenImage = shouldAttachScreenImage(for: context)
        let payload = editPromptBuilder.payload(
            for: context,
            window: window,
            maximumSuggestions: boundedMaximumCount,
            includeScreenImage: includeScreenImage
        )
        let session = LanguageModelSession(model: model, instructions: payload.systemPrompt)
        let responseContent: String
        do {
            if includeScreenImage, let screenContext = context.screenContext {
                let image = Transcript.ImageSegment(
                    data: screenContext.imageData,
                    mimeType: screenContext.mimeType
                )
                let response = try await session.respond(
                    to: payload.userPrompt,
                    image: image,
                    options: generationOptions(maximumResponseTokens: 384)
                )
                responseContent = response.content
            } else {
                let response = try await session.respond(
                    to: payload.userPrompt,
                    options: generationOptions(maximumResponseTokens: 384)
                )
                responseContent = response.content
            }
        } catch {
            throw AnyLanguageModelProviderError.requestFailed(String(describing: error))
        }
        let predictions = editPromptBuilder.predictions(
            from: responseContent,
            for: window,
            maximumSuggestions: boundedMaximumCount
        )

        guard !predictions.isEmpty else {
            return []
        }

        return predictions.map { prediction in
            if let completionText = prediction.appendCompletionTextIfApplicable(
                originalCaretUTF16Offset: context.caretUTF16Offset,
                suffixIsEmpty: context.suffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                return CompletionSuggestion(
                    text: completionText,
                    contextSummary: "\(configuration.kind.title) / \(context.appName)"
                )
            }

            return CompletionSuggestion(
                editPrediction: prediction,
                contextSummary: "\(configuration.kind.title) / \(context.appName)"
            )
        }
    }

    private func makeModel() async throws -> any LanguageModel {
        if let cachedModel {
            return cachedModel
        }

        let model: any LanguageModel
        switch configuration.kind {
        case .localLlama:
            guard !configuration.localModelPath.isEmpty else {
                throw AnyLanguageModelProviderError.missingLocalModel
            }
            let baseURL = try await LlamaServerManager.shared.endpoint(for: configuration.localModelPath)
            model = OpenAILanguageModel(
                baseURL: baseURL,
                apiKey: "local",
                model: URL(fileURLWithPath: configuration.localModelPath).lastPathComponent,
                apiVariant: .chatCompletions
            )
        case .gemini:
            guard !configuration.cloudAPIKey.isEmpty else {
                throw AnyLanguageModelProviderError.missingCloudConfiguration
            }
            let apiKey = configuration.cloudAPIKey
            let modelID = configuration.cloudModelID
            model = GeminiLanguageModel(
                apiKey: apiKey,
                model: modelID
            )
        case .huggingFaceRouter, .openAICompatible:
            guard let baseURL = URL(string: configuration.cloudBaseURL), !configuration.cloudAPIKey.isEmpty else {
                throw AnyLanguageModelProviderError.missingCloudConfiguration
            }
            let apiKey = configuration.cloudAPIKey
            model = OpenAILanguageModel(
                baseURL: baseURL,
                apiKey: apiKey,
                model: configuration.cloudModelID,
                apiVariant: .chatCompletions
            )
        case .mock:
            throw AnyLanguageModelProviderError.unsupportedProvider
        }

        cachedModel = model
        return model
    }

    private func shouldAttachScreenImage(for context: CompletionContext) -> Bool {
        configuration.allowsScreenImageInput && context.screenContext != nil
    }

    private func generationOptions(maximumResponseTokens: Int) -> GenerationOptions {
        var options = GenerationOptions(temperature: 0.2, maximumResponseTokens: maximumResponseTokens)

        if configuration.kind == .localLlama {
            options[custom: LlamaLanguageModel.self] = .init(
                contextSize: 4096,
                batchSize: 512,
                threads: Int32(max(2, ProcessInfo.processInfo.processorCount - 2)),
                temperature: 0.2,
                topK: 32,
                topP: 0.9,
                repeatPenalty: 1.12,
                repeatLastN: 96
            )
        }

        return options
    }
}

enum AnyLanguageModelProviderError: LocalizedError {
    case missingLocalModel
    case missingCloudConfiguration
    case unsupportedProvider
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingLocalModel:
            "Select or download a GGUF model before using the local provider."
        case .missingCloudConfiguration:
            "Cloud provider configuration is missing."
        case .unsupportedProvider:
            "This provider is not backed by AnyLanguageModel."
        case .requestFailed(let detail):
            "Model request failed: \(detail)"
        }
    }
}

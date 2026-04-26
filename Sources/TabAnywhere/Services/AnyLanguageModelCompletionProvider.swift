import AnyLanguageModel
import Foundation

struct AnyLanguageModelProviderConfiguration: Equatable {
    let kind: CompletionProviderKind
    let localModelPath: String
    let cloudBaseURL: String
    let cloudAPIKey: String
    let cloudModelID: String
}

final class AnyLanguageModelCompletionProvider: CompletionProviding {
    private let configuration: AnyLanguageModelProviderConfiguration
    private let promptBuilder = CompletionPromptBuilder()
    private let editPromptBuilder = EditPredictionPromptBuilder()
    private var cachedModel: (any LanguageModel)?

    init(configuration: AnyLanguageModelProviderConfiguration) {
        self.configuration = configuration
    }

    func promptPayload(for context: CompletionContext) -> CompletionPromptPayload {
        guard let window = context.editableTextWindow() else {
            return promptBuilder.payload(for: context)
        }

        return editPromptBuilder.payload(for: context, window: window)
    }

    func suggestions(for context: CompletionContext, maximumCount: Int) async throws -> [CompletionSuggestion] {
        let rewriteSuggestions = try await editPredictionSuggestions(for: context, maximumCount: maximumCount)
        if !rewriteSuggestions.isEmpty {
            return rewriteSuggestions
        }

        guard context.suffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        if let completionSuggestion = try await completionSuggestion(for: context) {
            return [completionSuggestion]
        }

        return []
    }

    private func editPredictionSuggestions(for context: CompletionContext, maximumCount: Int) async throws -> [CompletionSuggestion] {
        guard let window = context.editableTextWindow() else {
            return []
        }

        let model = try await makeModel()
        let boundedMaximumCount = min(max(maximumCount, 1), 3)
        let payload = editPromptBuilder.payload(for: context, window: window, maximumSuggestions: boundedMaximumCount)
        let session = LanguageModelSession(model: model, instructions: payload.systemPrompt)
        let response = try await session.respond(to: payload.userPrompt, options: generationOptions(maximumResponseTokens: 384))
        let predictions = editPromptBuilder.predictions(
            from: response.content,
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

    private func completionSuggestion(for context: CompletionContext) async throws -> CompletionSuggestion? {
        let model = try await makeModel()
        let session = LanguageModelSession(model: model, instructions: promptBuilder.instructions)
        let prompt = promptBuilder.prompt(for: context)
        let response = try await session.respond(to: prompt, options: generationOptions(maximumResponseTokens: 64))

        guard let text = promptBuilder.validatedSuggestionText(response.content, for: context) else {
            return nil
        }

        return CompletionSuggestion(
            text: text,
            contextSummary: "\(configuration.kind.title) / \(context.appName)"
        )
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

    var errorDescription: String? {
        switch self {
        case .missingLocalModel:
            "Select or download a GGUF model before using the local provider."
        case .missingCloudConfiguration:
            "Cloud provider configuration is missing."
        case .unsupportedProvider:
            "This provider is not backed by AnyLanguageModel."
        }
    }
}

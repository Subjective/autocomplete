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
    private var cachedModel: (any LanguageModel)?

    init(configuration: AnyLanguageModelProviderConfiguration) {
        self.configuration = configuration
    }

    func promptPayload(for context: CompletionContext) -> CompletionPromptPayload {
        promptBuilder.payload(for: context)
    }

    func suggestion(for context: CompletionContext) async throws -> CompletionSuggestion? {
        let model = try await makeModel()
        let session = LanguageModelSession(model: model, instructions: promptBuilder.instructions)
        let prompt = promptBuilder.prompt(for: context)
        let response = try await session.respond(to: prompt, options: generationOptions())

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

    private func generationOptions() -> GenerationOptions {
        var options = GenerationOptions(temperature: 0.2, maximumResponseTokens: 64)

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

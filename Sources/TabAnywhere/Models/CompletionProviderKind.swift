import Foundation

enum CompletionProviderKind: String, CaseIterable, Identifiable {
    case mock
    case localLlama
    case huggingFaceRouter
    case gemini
    case openAICompatible

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mock:
            "Mock"
        case .localLlama:
            "Local GGUF"
        case .huggingFaceRouter:
            "Hugging Face Router"
        case .gemini:
            "Gemini"
        case .openAICompatible:
            "OpenAI-compatible"
        }
    }

    var summary: String {
        switch self {
        case .mock:
            "Deterministic local test completions."
        case .localLlama:
            "Runs a downloaded GGUF model through llama.cpp."
        case .huggingFaceRouter:
            "Uses Hugging Face's OpenAI-compatible router."
        case .gemini:
            "Uses a Google AI Studio Gemini API key."
        case .openAICompatible:
            "Connects to any Chat Completions-compatible endpoint."
        }
    }

    var defaultCloudModelID: String? {
        switch self {
        case .huggingFaceRouter:
            "meta-llama/Llama-3.1-8B-Instruct"
        case .gemini:
            "gemma-4-31b-it"
        case .openAICompatible:
            "gpt-4o-mini"
        case .mock, .localLlama:
            nil
        }
    }
}

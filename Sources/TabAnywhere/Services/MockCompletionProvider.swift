import Foundation

protocol CompletionProviding {
    func suggestion(for context: CompletionContext) async throws -> CompletionSuggestion?
}

struct MockCompletionProvider: CompletionProviding {
    func suggestion(for context: CompletionContext) async throws -> CompletionSuggestion? {
        let prefix = context.prefix
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !isProbablyCompleteSentence(trimmed), context.suffix.count < 500 else {
            return nil
        }

        let lowercased = trimmed.lowercased()
        let suggestion: String

        if trimmed.isEmpty {
            suggestion = "Drafted by TabAnywhere."
        } else if lowercased.hasSuffix("thank") || lowercased.hasSuffix("thanks") {
            suggestion = " you for the update."
        } else if lowercased.hasSuffix("let") {
            suggestion = " me know what you think."
        } else if lowercased.hasSuffix("i am") || lowercased.hasSuffix("i'm") {
            suggestion = " following up on this."
        } else if lowercased.hasSuffix("can you") {
            suggestion = " take a look when you have a chance?"
        } else if lowercased.hasSuffix("todo") {
            suggestion = ": verify TextEdit, a native field, and a browser textarea."
        } else {
            suggestion = " — completed by TabAnywhere."
        }

        return CompletionSuggestion(
            text: suggestion,
            contextSummary: "\(context.appName) / \(context.role)"
        )
    }

    private func isProbablyCompleteSentence(_ text: String) -> Bool {
        guard let last = text.last else {
            return false
        }

        return [".", "!", "?"].contains(last)
    }
}

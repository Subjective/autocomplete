import Foundation

protocol CompletionProviding {
    func suggestions(for context: CompletionContext, maximumCount: Int) async throws -> [CompletionSuggestion]
}

struct MockCompletionProvider: CompletionProviding {
    private let diffService = TextDiffService()

    func suggestions(for context: CompletionContext, maximumCount: Int) async throws -> [CompletionSuggestion] {
        if let editSuggestion = editSuggestion(for: context) {
            return [editSuggestion]
        }

        let prefix = context.prefix
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !isProbablyCompleteSentence(trimmed), context.suffix.count < 500 else {
            return []
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

        return [CompletionSuggestion(
            text: suggestion,
            contextSummary: "\(context.appName) / \(context.role)"
        )]
    }

    private func editSuggestion(for context: CompletionContext) -> CompletionSuggestion? {
        guard let window = context.editableTextWindow() else {
            return nil
        }

        var rewritten = window.text
        var didRewrite = false

        if rewritten.contains("unfrotunately") {
            rewritten = rewritten.replacingOccurrences(of: "unfrotunately", with: "unfortunately")
            didRewrite = true
        }

        if rewritten.contains("teh ") {
            rewritten = rewritten.replacingOccurrences(of: "teh ", with: "the ")
            didRewrite = true
        }

        guard didRewrite else {
            return nil
        }

        let caretDelta = rewritten.utf16.count - window.text.utf16.count
        let caretOffset = max(0, min(rewritten.utf16.count, window.caretUTF16OffsetInWindow + caretDelta))

        guard let prediction = diffService.prediction(
            rewrittenText: rewritten,
            rewrittenCaretUTF16OffsetInWindow: caretOffset,
            originalWindow: window
        ) else {
            return nil
        }

        return CompletionSuggestion(
            editPrediction: prediction,
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

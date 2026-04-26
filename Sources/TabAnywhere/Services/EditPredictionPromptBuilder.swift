import Foundation

struct EditPredictionPromptBuilder {
    private let caretMarker = "<|caret|>"
    private let diffService = TextDiffService()

    var instructions: String {
        """
        You are TabAnywhere Edit Predictor.

        Predict the user's next small edit by rewriting the provided editable text window.

        Return only the rewritten editable text window.
        Include exactly one <|caret|> marker.

        Rules:
        - Preserve unchanged text exactly.
        - Make only a small, likely edit near the caret.
        - You may fix typos, spelling, punctuation, or incomplete words.
        - Prefer completing the current thought only when strongly implied.
        - Preserve tone, language, formatting, and indentation.
        - Use app, window, field, and visual context only to disambiguate.
        - Do not invent specific facts, names, dates, links, commitments, or personal details.
        - Do not rely on sensitive personal information inferred from screenshots.
        - If no useful edit is likely, return the editable text unchanged.
        - Do not include Markdown, labels, quotes, or explanations.
        """
    }

    func payload(for context: CompletionContext, window: EditableTextWindow, maximumSuggestions: Int = 1) -> CompletionPromptPayload {
        CompletionPromptPayload(
            systemPrompt: instructions(forMaximumSuggestions: maximumSuggestions),
            userPrompt: prompt(for: context, window: window, maximumSuggestions: maximumSuggestions)
        )
    }

    func prompt(for context: CompletionContext, window: EditableTextWindow, maximumSuggestions: Int = 1) -> String {
        let candidateInstruction = maximumSuggestions > 1
            ? "Candidate count: up to \(maximumSuggestions). Put each candidate between <|suggestion|> and <|end_suggestion|>."
            : "Candidate count: 1."

        return """
        App: \(context.appName)
        Window: \(context.windowTitle ?? "Unknown")
        Field role: \(context.role)

        \(candidateInstruction)

        Recent actions:
        <|recent_actions|>
        None
        <|end_recent_actions|>

        Recent visual context:
        <|visual_context|>
        None
        <|end_visual_context|>

        Editable text window:
        <|editable_text|>
        \(window.caretMarkerText)
        <|end_editable_text|>
        """
    }

    func predictions(from rawText: String, for window: EditableTextWindow, maximumSuggestions: Int = 1) -> [EditPrediction] {
        candidateTexts(from: rawText, maximumSuggestions: maximumSuggestions).compactMap { candidate in
            prediction(fromCandidateText: candidate, for: window)
        }
    }

    private func instructions(forMaximumSuggestions maximumSuggestions: Int) -> String {
        guard maximumSuggestions > 1 else {
            return instructions
        }

        return """
        \(instructions)

        Multiple candidates:
        - Return at most \(maximumSuggestions) candidates.
        - Put each candidate between <|suggestion|> and <|end_suggestion|>.
        - Each candidate must independently include exactly one <|caret|> marker.
        """
    }

    private func candidateTexts(from rawText: String, maximumSuggestions: Int) -> [String] {
        guard maximumSuggestions > 1, rawText.contains("<|suggestion|>") else {
            return [rawText]
        }

        let chunks = rawText
            .components(separatedBy: "<|suggestion|>")
            .dropFirst()
            .compactMap { chunk -> String? in
                chunk.components(separatedBy: "<|end_suggestion|>").first
            }

        return Array(chunks.prefix(maximumSuggestions))
    }

    private func prediction(fromCandidateText candidate: String, for window: EditableTextWindow) -> EditPrediction? {
        let text = candidate.trimmingCharacters(in: .newlines)

        guard !text.hasPrefix("```"), !text.hasSuffix("```") else {
            return nil
        }

        let disallowedDelimiters = [
            "<|editable_text|>",
            "<|end_editable_text|>",
            "<|recent_actions|>",
            "<|end_recent_actions|>",
            "<|visual_context|>",
            "<|end_visual_context|>",
            "<|suggestion|>",
            "<|end_suggestion|>"
        ]

        guard disallowedDelimiters.allSatisfy({ !text.contains($0) }) else {
            return nil
        }

        let parts = text.components(separatedBy: caretMarker)
        guard parts.count == 2 else {
            return nil
        }

        let rewrittenText = parts.joined()
        let caretOffset = parts[0].utf16.count
        return diffService.prediction(
            rewrittenText: rewrittenText,
            rewrittenCaretUTF16OffsetInWindow: caretOffset,
            originalWindow: window
        )
    }
}

import Foundation

struct EditPredictionPromptBuilder {
    private let caretMarker = "<|caret|>"
    private let diffService = TextDiffService()

    var instructions: String {
        """
        You are TabAnywhere Edit Predictor.

        Predict the user's next likely edit by rewriting the provided editable text window.

        Return only the rewritten editable text window.
        Include exactly one <|caret|> marker.

        Rules:
        - Preserve unchanged text exactly.
        - Make a likely edit near the caret.
        - Prefer a small edit when the user's intent is only weakly implied.
        - You may fix typos, spelling, punctuation, or incomplete words.
        - If the editable text is empty or the caret is at the start of a reply/comment, and visible screen context clearly shows what is being answered, you may write a concise complete reply.
        - Use facts, names, dates, and commitments that are explicitly visible in the editable text or attached screenshot.
        - Do not invent facts, names, dates, links, commitments, or personal details that are not grounded in the editable text or attached screenshot.
        - For screenshot-grounded replies, include only the details needed to answer naturally.
        - Preserve tone, language, formatting, and indentation.
        - Use app, window, field, and visual context to infer reply intent when the evidence is strong.
        - Do not expose sensitive personal information unless it is necessary to answer the visible request.
        - If no useful edit is likely, return the editable text unchanged.
        - Do not include Markdown, labels, quotes, or explanations.
        """
    }

    func payload(
        for context: CompletionContext,
        window: EditableTextWindow,
        maximumSuggestions: Int = 1,
        includeScreenImage: Bool = false
    ) -> CompletionPromptPayload {
        CompletionPromptPayload(
            systemPrompt: instructions(forMaximumSuggestions: maximumSuggestions),
            userPrompt: prompt(
                for: context,
                window: window,
                maximumSuggestions: maximumSuggestions,
                includeScreenImage: includeScreenImage
            )
        )
    }

    func prompt(
        for context: CompletionContext,
        window: EditableTextWindow,
        maximumSuggestions: Int = 1,
        includeScreenImage: Bool = false
    ) -> String {
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
        \(visualContextDescription(for: context, includeScreenImage: includeScreenImage))
        <|end_visual_context|>

        Editable text window:
        <|editable_text|>
        \(window.caretMarkerText)
        <|end_editable_text|>
        """
    }

    private func visualContextDescription(for context: CompletionContext, includeScreenImage: Bool) -> String {
        guard let screenContext = context.screenContext else {
            return "None"
        }

        if includeScreenImage {
            return """
            A screenshot of the user's current screen is attached to this message.
            Use it as grounded context for predicting the next edit. If the user is replying, commenting, or composing in response to visible content, the screenshot may justify a longer concise completion.
            \(screenContext.promptDescription)
            """
        }

        return """
        Screenshot capture is available, but this provider is not configured for image input.
        Do not infer visual details from the screen.
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

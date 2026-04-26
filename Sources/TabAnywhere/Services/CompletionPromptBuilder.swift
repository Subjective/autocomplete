import Foundation

struct CompletionPromptPayload: Equatable {
    let systemPrompt: String
    let userPrompt: String
}

struct CompletionPromptBuilder {
    var instructions: String {
        """
        You are TabAnywhere, a low-latency system-wide inline completion engine.
        Predict the short text that should be inserted at the cursor, continuing exactly from the end of the user's prefix.

        Use context in this priority order:
        1. The exact prefix at the cursor.
        2. Text in the same field or document.
        3. Selected text and nearby UI labels.
        4. App name, window title, and field role.
        5. Recent screenshot summaries.
        6. General language patterns.

        Rules:
        - Return only the text to insert at the cursor.
        - Do not repeat the existing prefix.
        - The completed text must read as a grammatically correct continuation of the prefix.
        - Preserve the user's apparent tone, language, formality, and writing style.
        - Prefer short, safe, high-probability completions over clever or specific ones.
        - Do not be creative when a generic completion would work.
        - Do not invent specific facts, names, dates, excuses, numbers, links, or commitments.
        - Do not reveal or rely on sensitive personal information inferred from screenshots.
        - Return an empty response if no useful short completion is likely.
        - Do not include quotes, markdown, labels, or explanations.

        Spacing:
        - If the prefix already ends with a space, do not add another leading space unless two spaces are intentional.
        - If the prefix ends in the middle of a word, continue that word without a leading space.
        - If the prefix ends after a complete word with no trailing space, start with a leading space when the next token is a new word.
        - Include punctuation only when likely useful.

        Length:
        - Prefer 1 to 8 words.
        - Avoid completing more than one sentence unless strongly implied.

        Examples:
        Prefix: "Thank"
        Completion: " you for the update."

        Prefix: "Thank "
        Completion: "you for the update."

        Prefix: "I'll fol"
        Completion: "low up tomorrow."

        Prefix: "Can you"
        Completion: " take a look when you have a chance?"

        Prefix: "Looks good,"
        Completion: " thank you."

        Prefix: "The meeting is at 3."
        Completion: ""
        """
    }

    func payload(for context: CompletionContext) -> CompletionPromptPayload {
        CompletionPromptPayload(
            systemPrompt: instructions,
            userPrompt: prompt(for: context)
        )
    }

    func prompt(for context: CompletionContext, includeInstructions: Bool = false) -> String {
        let contextPrompt = """
        App: \(context.appName)
        Window: \(context.windowTitle ?? "Unknown")
        Field role: \(context.role)
        Selected text:
        <|selected_text|>
        \(context.selectedText.isEmpty ? "None" : context.selectedText)
        <|end_selected_text|>

        Same-field context:
        <|field_context|>
        \(context.value)
        <|end_field_context|>

        Recent visual context:
        <|visual_context|>
        None
        <|end_visual_context|>

        Prefix to complete:
        <|prefix|>
        \(context.prefix)
        <|end_prefix|>
        """

        guard includeInstructions else {
            return contextPrompt
        }

        return """
        \(instructions)

        \(contextPrompt)
        """
    }

    func validatedSuggestionText(_ rawText: String, for context: CompletionContext) -> String? {
        var text = rawText.removingWrappingFormatting()

        if text.hasPrefix(context.prefix) {
            text.removeFirst(context.prefix.count)
            text = text.removingWrappingFormatting()
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= 240 else {
            return nil
        }

        let normalizedSuffix = context.suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedSuffix.isEmpty, normalizedSuffix.hasPrefix(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return nil
        }

        return text
    }
}

private extension String {
    func removingWrappingFormatting() -> String {
        var text = trimmingCharacters(in: .newlines)
        let wrappingCharacters = CharacterSet(charactersIn: "\"'`")

        while let first = text.unicodeScalars.first, wrappingCharacters.contains(first) {
            text.removeFirst()
        }

        while let last = text.unicodeScalars.last, wrappingCharacters.contains(last) {
            text.removeLast()
        }

        return text.trimmingCharacters(in: .newlines)
    }
}

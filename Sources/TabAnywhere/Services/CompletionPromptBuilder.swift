import Foundation

struct CompletionPromptBuilder {
    var instructions: String {
        """
        You are TabAnywhere, a system-wide inline completion assistant.
        Continue the user's text at the cursor.

        Rules:
        - Return only the text to insert at the cursor.
        - Do not repeat the existing prefix.
        - Do not include quotes, markdown, or explanations.
        - Return an empty response if no useful short completion is available.
        - Keep the completion concise and compatible with the suffix.
        """
    }

    func prompt(for context: CompletionContext, includeInstructions: Bool = false) -> String {
        let contextPrompt = """
        App: \(context.appName)
        Window: \(context.windowTitle ?? "Unknown")
        Field role: \(context.role)
        Selected text: \(context.selectedText.isEmpty ? "None" : context.selectedText)

        Prefix before cursor:
        \(context.prefix)

        Suffix after cursor:
        \(context.suffix)
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
        var text = rawText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))

        if text.hasPrefix(context.prefix) {
            text.removeFirst(context.prefix.count)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !text.isEmpty, text.count <= 240 else {
            return nil
        }

        let normalizedSuffix = context.suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedSuffix.isEmpty, normalizedSuffix.hasPrefix(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return nil
        }

        return text
    }
}

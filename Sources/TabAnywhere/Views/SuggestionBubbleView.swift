import SwiftUI

struct SuggestionBubbleView: View {
    let suggestion: CompletionSuggestion
    let style: SuggestionPresentationStyle
    let hotKey: String
    let caretHeight: CGFloat

    init(text: String, style: SuggestionPresentationStyle, hotKey: String, caretHeight: CGFloat = 16) {
        self.suggestion = CompletionSuggestion(text: text, contextSummary: "Preview")
        self.style = style
        self.hotKey = hotKey
        self.caretHeight = caretHeight
    }

    init(suggestion: CompletionSuggestion, style: SuggestionPresentationStyle, hotKey: String, caretHeight: CGFloat = 16) {
        self.suggestion = suggestion
        self.style = style
        self.hotKey = hotKey
        self.caretHeight = caretHeight
    }

    var body: some View {
        if case .edit(let prediction) = suggestion.kind {
            editPredictionBody(prediction)
        } else {
            switch style {
            case .popup:
                popupBody
            case .ghostText:
                ghostTextBody
            case .compactChip:
                compactChipBody
            case .textOnly:
                textOnlyBody
            case .candidateWindow:
                candidateWindowBody
            case .commandPalette:
                commandPaletteBody
            }
        }
    }

    private var text: String {
        suggestion.text
    }

    private var popupBody: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle")
                .foregroundStyle(.secondary)

            Text(text)
                .font(popupBodyFont)
                .lineLimit(2)

            Spacer(minLength: 8)
            hotKeyBadge
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.separator.opacity(0.65), lineWidth: 1)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var ghostTextBody: some View {
        Text(text)
            .font(.system(size: inlineFontSize, weight: .regular))
            .foregroundStyle(.secondary.opacity(0.82))
            .lineLimit(1)
            .padding(.horizontal, 0)
            .padding(.vertical, 0)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var inlineFontSize: CGFloat {
        min(max(caretHeight * 0.82, 11), 36)
    }

    private var textOnlyFontSize: CGFloat {
        min(max(caretHeight * 0.78, 11), 34)
    }

    private var popupFontSize: CGFloat {
        min(max(caretHeight * 0.68, 12), 18)
    }

    private var compactFontSize: CGFloat {
        min(max(caretHeight * 0.62, 11), 16)
    }

    private var candidateFontSize: CGFloat {
        min(max(caretHeight * 0.64, 12), 18)
    }

    private var commandFontSize: CGFloat {
        min(max(caretHeight * 0.64, 12), 18)
    }

    private var popupBodyFont: Font {
        .system(size: popupFontSize, weight: .medium)
    }

    private var compactBodyFont: Font {
        .system(size: compactFontSize, weight: .medium)
    }

    private var candidateBodyFont: Font {
        .system(size: candidateFontSize, weight: .medium)
    }

    private var commandBodyFont: Font {
        .system(size: commandFontSize, weight: .semibold)
    }

    private var textOnlyBodyFont: Font {
        .system(size: textOnlyFontSize, weight: .regular)
    }

    private var compactChipBody: some View {
        HStack(spacing: 8) {
            Image(systemName: "tab.right")
                .foregroundStyle(.secondary)

            Text(text)
                .font(compactBodyFont)
                .lineLimit(1)

            hotKeyBadge
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.separator.opacity(0.55), lineWidth: 1)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var textOnlyBody: some View {
        Text(text)
            .font(textOnlyBodyFont)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 0)
            .padding(.vertical, 0)
            .shadow(color: .black.opacity(0.16), radius: 1, x: 0, y: 1)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var candidateWindowBody: some View {
        HStack(spacing: 10) {
            Text("1")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(candidateBodyFont)
                    .lineLimit(2)

                Text("Accept with \(hotKey)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.separator.opacity(0.65), lineWidth: 1)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var commandPaletteBody: some View {
        HStack(spacing: 12) {
            Image(systemName: "command")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(commandBodyFont)
                    .lineLimit(1)

                Text("TabAnywhere completion")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)
            hotKeyBadge
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.separator.opacity(0.8), lineWidth: 1)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func editPredictionBody(_ prediction: EditPrediction) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)

                Text("Edit")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)
                hotKeyBadge
            }

            diffText(for: prediction)
                .font(popupBodyFont)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.separator.opacity(0.7), lineWidth: 1)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func diffText(for prediction: EditPrediction) -> Text {
        displayFragments(for: prediction).reduce(Text("")) { partial, fragment in
            let text = Text(fragment.text)

            switch fragment.kind {
            case .unchanged:
                return partial + text.foregroundColor(.secondary)
            case .inserted:
                return partial + text.foregroundColor(.green)
            case .deleted:
                return partial + text.foregroundColor(.red).strikethrough()
            }
        }
    }

    private func displayFragments(for prediction: EditPrediction) -> [TextDiffFragment] {
        let fragments = prediction.diffFragments
        guard fragments.contains(where: { $0.kind != .unchanged }) else {
            return []
        }

        return fragments.enumerated().compactMap { index, fragment in
            guard fragment.kind == .unchanged else {
                return fragment
            }

            let previousChanged = index > 0 && fragments[index - 1].kind != .unchanged
            let nextChanged = index + 1 < fragments.count && fragments[index + 1].kind != .unchanged

            if previousChanged, nextChanged {
                return TextDiffFragment(kind: .unchanged, text: trimmedMiddle(fragment.text, limit: 18))
            }

            if previousChanged {
                return TextDiffFragment(kind: .unchanged, text: trimmedPrefix(fragment.text, limit: 32))
            }

            if nextChanged {
                return TextDiffFragment(kind: .unchanged, text: trimmedSuffix(fragment.text, limit: 32))
            }

            return nil
        }
    }

    private func trimmedPrefix(_ text: String, limit: Int) -> String {
        guard text.count > limit else {
            return text
        }

        return String(text.prefix(limit)) + "..."
    }

    private func trimmedSuffix(_ text: String, limit: Int) -> String {
        guard text.count > limit else {
            return text
        }

        return "..." + String(text.suffix(limit))
    }

    private func trimmedMiddle(_ text: String, limit: Int) -> String {
        guard text.count > limit * 2 else {
            return text
        }

        return String(text.prefix(limit)) + "..." + String(text.suffix(limit))
    }

    private var hotKeyBadge: some View {
        Text(hotKey)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

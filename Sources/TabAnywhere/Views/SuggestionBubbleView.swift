import SwiftUI

struct SuggestionBubbleView: View {
    let text: String
    let style: SuggestionPresentationStyle
    let hotKey: String

    var body: some View {
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

    private var popupBody: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle")
                .foregroundStyle(.secondary)

            Text(text)
                .font(.system(size: 13, weight: .medium))
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
        HStack(spacing: 8) {
            Text(text)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary.opacity(0.82))
                .lineLimit(2)

            Text(hotKey)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var compactChipBody: some View {
        HStack(spacing: 8) {
            Image(systemName: "tab.right")
                .foregroundStyle(.secondary)

            Text(text)
                .font(.system(size: 12, weight: .medium))
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
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
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
                    .font(.system(size: 13, weight: .medium))
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
                    .font(.system(size: 13, weight: .semibold))
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

    private var hotKeyBadge: some View {
        Text(hotKey)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

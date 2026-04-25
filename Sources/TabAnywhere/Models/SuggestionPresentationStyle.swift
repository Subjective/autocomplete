import Foundation

enum SuggestionPresentationStyle: String, CaseIterable, Identifiable {
    case popup
    case ghostText
    case compactChip
    case textOnly
    case candidateWindow
    case commandPalette

    var id: String { rawValue }

    var title: String {
        switch self {
        case .popup:
            return "Popup"
        case .ghostText:
            return "Ghost Text"
        case .compactChip:
            return "Compact Chip"
        case .textOnly:
            return "Text Only"
        case .candidateWindow:
            return "Candidate Window"
        case .commandPalette:
            return "Command Palette"
        }
    }

    var summary: String {
        switch self {
        case .popup:
            return "Most reliable across apps"
        case .ghostText:
            return "Closest to inline completion"
        case .compactChip:
            return "Small with visible affordance"
        case .textOnly:
            return "Least visual chrome"
        case .candidateWindow:
            return "Familiar macOS input style"
        case .commandPalette:
            return "Manual fallback surface"
        }
    }

    var systemImage: String {
        switch self {
        case .popup:
            return "bubble.left"
        case .ghostText:
            return "text.cursor"
        case .compactChip:
            return "capsule"
        case .textOnly:
            return "textformat"
        case .candidateWindow:
            return "list.bullet.rectangle"
        case .commandPalette:
            return "command"
        }
    }

    var minWidth: CGFloat {
        switch self {
        case .ghostText, .textOnly:
            return 180
        case .compactChip:
            return 260
        case .commandPalette:
            return 420
        case .popup, .candidateWindow:
            return 240
        }
    }

    var maxWidth: CGFloat {
        switch self {
        case .commandPalette:
            return 560
        case .ghostText, .textOnly:
            return 460
        default:
            return 520
        }
    }

    var minHeight: CGFloat {
        switch self {
        case .commandPalette:
            return 54
        case .ghostText, .textOnly:
            return 24
        default:
            return 38
        }
    }

    var maxHeight: CGFloat {
        switch self {
        case .commandPalette:
            return 88
        case .candidateWindow:
            return 96
        case .ghostText, .textOnly:
            return 60
        default:
            return 90
        }
    }

    var hasShadow: Bool {
        switch self {
        case .ghostText, .textOnly:
            return false
        default:
            return true
        }
    }
}

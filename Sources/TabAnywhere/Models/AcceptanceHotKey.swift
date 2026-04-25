import Carbon
import Foundation

enum AcceptanceHotKey: String, CaseIterable, Identifiable {
    case optionTab
    case tab

    var id: String { rawValue }

    var label: String {
        switch self {
        case .optionTab:
            return "Option+Tab"
        case .tab:
            return "Tab"
        }
    }

    var keyCode: UInt32 {
        UInt32(kVK_Tab)
    }

    var modifiers: UInt32 {
        switch self {
        case .optionTab:
            return UInt32(optionKey)
        case .tab:
            return 0
        }
    }
}

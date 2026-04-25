import ApplicationServices
import Foundation

struct CompletionContext {
    let element: AXUIElement
    let appName: String
    let windowTitle: String?
    let role: String
    let value: String
    let selectedRange: CFRange?
    let caretBounds: CGRect?

    var prefix: String {
        guard let selectedRange else {
            return value
        }

        return value.substringByUTF16Range(location: 0, length: selectedRange.location) ?? value
    }

    var suffix: String {
        guard let selectedRange else {
            return ""
        }

        let start = selectedRange.location + selectedRange.length
        let length = max(0, value.utf16.count - start)
        return value.substringByUTF16Range(location: start, length: length) ?? ""
    }

    var selectedText: String {
        guard let selectedRange, selectedRange.length > 0 else {
            return ""
        }

        return value.substringByUTF16Range(location: selectedRange.location, length: selectedRange.length) ?? ""
    }
}

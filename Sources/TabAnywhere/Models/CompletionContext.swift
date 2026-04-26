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

    var caretUTF16Offset: Int {
        guard let selectedRange else {
            return value.utf16.count
        }

        return selectedRange.location + selectedRange.length
    }

    var hasSelection: Bool {
        selectedRange?.length ?? 0 > 0
    }

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

    func editableTextWindow(maxBeforeCaret: Int = 600, maxAfterCaret: Int = 260) -> EditableTextWindow? {
        let fullLength = value.utf16.count
        let caret = min(max(caretUTF16Offset, 0), fullLength)
        let start = max(0, caret - maxBeforeCaret)
        let end = min(fullLength, caret + maxAfterCaret)
        let length = max(0, end - start)

        guard let text = value.substringByUTF16Range(location: start, length: length) else {
            return nil
        }

        return EditableTextWindow(
            text: text,
            startUTF16Offset: start,
            endUTF16Offset: end,
            caretUTF16OffsetInWindow: caret - start
        )
    }
}

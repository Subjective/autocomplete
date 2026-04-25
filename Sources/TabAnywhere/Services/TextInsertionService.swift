import AppKit
import ApplicationServices
import Foundation

final class TextInsertionService {
    func insert(_ suggestion: CompletionSuggestion, into context: CompletionContext) -> Bool {
        if insertWithAccessibility(suggestion.text, into: context) {
            return true
        }

        pasteText(suggestion.text)
        return true
    }

    private func insertWithAccessibility(_ text: String, into context: CompletionContext) -> Bool {
        guard let selectedRange = context.selectedRange else {
            return false
        }

        var valueSettable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(context.element, kAXValueAttribute as CFString, &valueSettable) == .success,
              valueSettable.boolValue,
              let newValue = context.value.replacingUTF16Range(
                location: selectedRange.location,
                length: selectedRange.length,
                with: text
              )
        else {
            return false
        }

        let setValueError = AXUIElementSetAttributeValue(
            context.element,
            kAXValueAttribute as CFString,
            newValue as CFTypeRef
        )

        guard setValueError == .success else {
            return false
        }

        var newRange = CFRange(location: selectedRange.location + text.utf16.count, length: 0)
        if let rangeValue = AXValueCreate(.cfRange, &newRange) {
            AXUIElementSetAttributeValue(
                context.element,
                kAXSelectedTextRangeAttribute as CFString,
                rangeValue
            )
        }

        return true
    }

    private func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previousItems = pasteboard.pasteboardItems ?? []

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        sendCommandV()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            pasteboard.clearContents()
            if !previousItems.isEmpty {
                pasteboard.writeObjects(previousItems)
            }
        }
    }

    private func sendCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 9

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
}

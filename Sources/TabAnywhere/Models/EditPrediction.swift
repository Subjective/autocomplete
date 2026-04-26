import Foundation

struct EditPrediction: Equatable {
    let originalWindow: EditableTextWindow
    let rewrittenWindowText: String
    let rewrittenCaretUTF16OffsetInWindow: Int
    let edits: [TextEdit]
    let diffFragments: [TextDiffFragment]

    var targetCaretUTF16Offset: Int {
        originalWindow.startUTF16Offset + rewrittenCaretUTF16OffsetInWindow
    }

    var summary: String {
        if edits.count == 1, let edit = edits.first {
            return edit.summary
        }

        return "\(edits.count) edits"
    }

    func appendCompletionTextIfApplicable(originalCaretUTF16Offset: Int, suffixIsEmpty: Bool) -> String? {
        guard suffixIsEmpty, edits.count == 1, let edit = edits.first else {
            return nil
        }

        guard edit.isInsertion, edit.startUTF16Offset == originalCaretUTF16Offset else {
            return nil
        }

        guard !edit.replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return edit.replacement
    }
}

struct EditableTextWindow: Equatable {
    let text: String
    let startUTF16Offset: Int
    let endUTF16Offset: Int
    let caretUTF16OffsetInWindow: Int

    var caretMarkerText: String {
        guard let prefix = text.substringByUTF16Range(location: 0, length: caretUTF16OffsetInWindow),
              let suffix = text.substringByUTF16Range(
                location: caretUTF16OffsetInWindow,
                length: text.utf16.count - caretUTF16OffsetInWindow
              )
        else {
            return text
        }

        return "\(prefix)<|caret|>\(suffix)"
    }
}

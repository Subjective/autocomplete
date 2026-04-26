import Foundation

struct TextDiffService {
    private let maximumEditCount = 3
    private let maximumEditDistanceFromCaret = 250
    private let maximumDeletedUTF16Length = 80
    private let maximumEditUTF16Length = 160
    private let maximumCompletionUTF16Length = 240

    func prediction(
        rewrittenText: String,
        rewrittenCaretUTF16OffsetInWindow: Int,
        originalWindow: EditableTextWindow
    ) -> EditPrediction? {
        guard rewrittenCaretUTF16OffsetInWindow >= 0,
              rewrittenCaretUTF16OffsetInWindow <= rewrittenText.utf16.count,
              rewrittenText != originalWindow.text
        else {
            return nil
        }

        if let caretInsertionPrediction = predictionForCaretInsertion(
            rewrittenText: rewrittenText,
            rewrittenCaretUTF16OffsetInWindow: rewrittenCaretUTF16OffsetInWindow,
            originalWindow: originalWindow
        ) {
            return caretInsertionPrediction
        }

        let diff = diffFragments(original: originalWindow.text, rewritten: rewrittenText)
        let edits = textEdits(from: diff, windowStartUTF16Offset: originalWindow.startUTF16Offset)

        guard !edits.isEmpty else {
            return nil
        }

        let prediction = EditPrediction(
            originalWindow: originalWindow,
            rewrittenWindowText: rewrittenText,
            rewrittenCaretUTF16OffsetInWindow: rewrittenCaretUTF16OffsetInWindow,
            edits: edits,
            diffFragments: diff
        )

        guard isValid(prediction) else {
            return nil
        }

        return prediction
    }

    private func predictionForCaretInsertion(
        rewrittenText: String,
        rewrittenCaretUTF16OffsetInWindow: Int,
        originalWindow: EditableTextWindow
    ) -> EditPrediction? {
        let caret = originalWindow.caretUTF16OffsetInWindow
        guard let originalPrefix = originalWindow.text.substringByUTF16Range(location: 0, length: caret),
              let originalSuffix = originalWindow.text.substringByUTF16Range(
                location: caret,
                length: originalWindow.text.utf16.count - caret
              )
        else {
            return nil
        }

        let insertedUTF16Length = rewrittenText.utf16.count - originalPrefix.utf16.count - originalSuffix.utf16.count
        guard insertedUTF16Length > 0,
              rewrittenText.hasPrefix(originalPrefix),
              rewrittenText.hasSuffix(originalSuffix),
              let insertedText = rewrittenText.substringByUTF16Range(
                location: originalPrefix.utf16.count,
                length: insertedUTF16Length
              ),
              "\(originalPrefix)\(insertedText)\(originalSuffix)" == rewrittenText,
              !insertedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        let absoluteCaret = originalWindow.startUTF16Offset + caret
        let diffFragments = [
            TextDiffFragment(kind: .unchanged, text: originalPrefix),
            TextDiffFragment(kind: .inserted, text: insertedText),
            TextDiffFragment(kind: .unchanged, text: originalSuffix)
        ].filter { !$0.text.isEmpty }

        let prediction = EditPrediction(
            originalWindow: originalWindow,
            rewrittenWindowText: rewrittenText,
            rewrittenCaretUTF16OffsetInWindow: rewrittenCaretUTF16OffsetInWindow,
            edits: [
                TextEdit(
                    startUTF16Offset: absoluteCaret,
                    endUTF16Offset: absoluteCaret,
                    originalText: "",
                    replacement: insertedText
                )
            ],
            diffFragments: diffFragments
        )

        guard isValid(prediction) else {
            return nil
        }

        return prediction
    }

    private func isValid(_ prediction: EditPrediction) -> Bool {
        guard prediction.edits.count <= maximumEditCount else {
            return false
        }

        let deletedLength = prediction.edits.reduce(0) { $0 + $1.deletedUTF16Length }
        guard deletedLength <= maximumDeletedUTF16Length else {
            return false
        }

        let changedLength = prediction.edits.reduce(0) { partial, edit in
            partial + edit.deletedUTF16Length + edit.insertedUTF16Length
        }

        let appendCompletion = prediction.appendCompletionTextIfApplicable(
            originalCaretUTF16Offset: prediction.originalWindow.startUTF16Offset + prediction.originalWindow.caretUTF16OffsetInWindow,
            suffixIsEmpty: true
        ) != nil
        let maximumChangedLength = appendCompletion ? maximumCompletionUTF16Length : maximumEditUTF16Length
        guard changedLength <= maximumChangedLength else {
            return false
        }

        let caretOffset = prediction.originalWindow.startUTF16Offset + prediction.originalWindow.caretUTF16OffsetInWindow
        return prediction.edits.allSatisfy { edit in
            edit.distance(fromUTF16Offset: caretOffset) <= maximumEditDistanceFromCaret
        }
    }

    private func diffFragments(original: String, rewritten: String) -> [TextDiffFragment] {
        let originalCharacters = Array(original)
        let rewrittenCharacters = Array(rewritten)
        let originalCount = originalCharacters.count
        let rewrittenCount = rewrittenCharacters.count

        var table = Array(
            repeating: Array(repeating: 0, count: rewrittenCount + 1),
            count: originalCount + 1
        )

        if originalCount > 0, rewrittenCount > 0 {
            for originalIndex in stride(from: originalCount - 1, through: 0, by: -1) {
                for rewrittenIndex in stride(from: rewrittenCount - 1, through: 0, by: -1) {
                    if originalCharacters[originalIndex] == rewrittenCharacters[rewrittenIndex] {
                        table[originalIndex][rewrittenIndex] = table[originalIndex + 1][rewrittenIndex + 1] + 1
                    } else {
                        table[originalIndex][rewrittenIndex] = max(
                            table[originalIndex + 1][rewrittenIndex],
                            table[originalIndex][rewrittenIndex + 1]
                        )
                    }
                }
            }
        }

        var fragments: [TextDiffFragment] = []
        var originalIndex = 0
        var rewrittenIndex = 0

        while originalIndex < originalCount || rewrittenIndex < rewrittenCount {
            if originalIndex < originalCount,
               rewrittenIndex < rewrittenCount,
               originalCharacters[originalIndex] == rewrittenCharacters[rewrittenIndex] {
                append(String(originalCharacters[originalIndex]), kind: .unchanged, to: &fragments)
                originalIndex += 1
                rewrittenIndex += 1
            } else if rewrittenIndex < rewrittenCount,
                      (originalIndex == originalCount ||
                        table[originalIndex][rewrittenIndex + 1] >= table[originalIndex + 1][rewrittenIndex]) {
                append(String(rewrittenCharacters[rewrittenIndex]), kind: .inserted, to: &fragments)
                rewrittenIndex += 1
            } else if originalIndex < originalCount {
                append(String(originalCharacters[originalIndex]), kind: .deleted, to: &fragments)
                originalIndex += 1
            }
        }

        return fragments
    }

    private func append(_ text: String, kind: TextDiffFragmentKind, to fragments: inout [TextDiffFragment]) {
        guard !text.isEmpty else {
            return
        }

        if let last = fragments.last, last.kind == kind {
            fragments[fragments.count - 1] = TextDiffFragment(kind: kind, text: last.text + text)
        } else {
            fragments.append(TextDiffFragment(kind: kind, text: text))
        }
    }

    private func textEdits(from fragments: [TextDiffFragment], windowStartUTF16Offset: Int) -> [TextEdit] {
        var edits: [TextEdit] = []
        var originalOffset = windowStartUTF16Offset
        var pendingStart: Int?
        var pendingOriginal = ""
        var pendingReplacement = ""

        func flushPending() {
            guard let start = pendingStart else {
                return
            }

            edits.append(TextEdit(
                startUTF16Offset: start,
                endUTF16Offset: start + pendingOriginal.utf16.count,
                originalText: pendingOriginal,
                replacement: pendingReplacement
            ))
            pendingStart = nil
            pendingOriginal = ""
            pendingReplacement = ""
        }

        for fragment in fragments {
            switch fragment.kind {
            case .unchanged:
                flushPending()
                originalOffset += fragment.text.utf16.count
            case .deleted:
                if pendingStart == nil {
                    pendingStart = originalOffset
                }
                pendingOriginal += fragment.text
                originalOffset += fragment.text.utf16.count
            case .inserted:
                if pendingStart == nil {
                    pendingStart = originalOffset
                }
                pendingReplacement += fragment.text
            }
        }

        flushPending()
        return edits
    }
}

private extension TextEdit {
    func distance(fromUTF16Offset offset: Int) -> Int {
        if endUTF16Offset < offset {
            return offset - endUTF16Offset
        }

        if startUTF16Offset > offset {
            return startUTF16Offset - offset
        }

        return 0
    }
}

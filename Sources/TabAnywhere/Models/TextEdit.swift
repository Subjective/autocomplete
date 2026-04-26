import Foundation

struct TextEdit: Equatable {
    let startUTF16Offset: Int
    let endUTF16Offset: Int
    let originalText: String
    let replacement: String

    var deletedUTF16Length: Int {
        max(0, endUTF16Offset - startUTF16Offset)
    }

    var insertedUTF16Length: Int {
        replacement.utf16.count
    }

    var isInsertion: Bool {
        startUTF16Offset == endUTF16Offset
    }

    var summary: String {
        if originalText.isEmpty {
            return "Insert \(replacement.previewFragment)"
        }

        if replacement.isEmpty {
            return "Delete \(originalText.previewFragment)"
        }

        return "\(originalText.previewFragment) -> \(replacement.previewFragment)"
    }
}

struct TextDiffFragment: Equatable {
    let kind: TextDiffFragmentKind
    let text: String
}

enum TextDiffFragmentKind: Equatable {
    case unchanged
    case inserted
    case deleted
}

private extension String {
    var previewFragment: String {
        let collapsed = replacingOccurrences(of: "\n", with: "\\n")
        if collapsed.count <= 36 {
            return "\"\(collapsed)\""
        }

        return "\"\(collapsed.prefix(33))...\""
    }
}

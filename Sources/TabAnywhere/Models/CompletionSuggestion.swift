import Foundation

struct CompletionSuggestion: Identifiable, Equatable {
    let id = UUID()
    let kind: CompletionSuggestionKind
    let contextSummary: String

    init(text: String, contextSummary: String) {
        self.kind = .completion(text)
        self.contextSummary = contextSummary
    }

    init(editPrediction: EditPrediction, contextSummary: String) {
        self.kind = .edit(editPrediction)
        self.contextSummary = contextSummary
    }

    var text: String {
        switch kind {
        case .completion(let text):
            return text
        case .edit(let prediction):
            return prediction.summary
        }
    }

    var isEditPrediction: Bool {
        if case .edit = kind {
            return true
        }

        return false
    }
}

enum CompletionSuggestionKind: Equatable {
    case completion(String)
    case edit(EditPrediction)
}

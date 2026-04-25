import Foundation

struct CompletionSuggestion: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let contextSummary: String
}

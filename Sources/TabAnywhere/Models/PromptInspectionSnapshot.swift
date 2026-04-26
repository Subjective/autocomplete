import Foundation

struct PromptInspectionSnapshot: Equatable {
    let provider: String
    let model: String
    let systemPrompt: String
    let userPrompt: String
    let transportDescription: String
    let createdAt: Date
    let result: String

    func withResult(_ result: String) -> PromptInspectionSnapshot {
        PromptInspectionSnapshot(
            provider: provider,
            model: model,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            transportDescription: transportDescription,
            createdAt: createdAt,
            result: result
        )
    }
}

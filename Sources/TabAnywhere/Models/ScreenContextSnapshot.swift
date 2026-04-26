import Foundation

struct ScreenContextSnapshot: Equatable {
    let capturedAt: Date
    let imageData: Data
    let mimeType: String
    let pixelWidth: Int
    let pixelHeight: Int
    let sourceDescription: String

    var promptDescription: String {
        """
        Captured at: \(DateFormatter.tabAnywhereTime.string(from: capturedAt))
        Source: \(sourceDescription)
        Image: \(pixelWidth)x\(pixelHeight) \(mimeType)
        """
    }
}

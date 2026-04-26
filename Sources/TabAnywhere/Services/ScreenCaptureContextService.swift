import AppKit
import CoreGraphics
import Foundation
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

final class ScreenCaptureContextService {
    private let maximumPixelDimension = 1280
    private let jpegQuality = 0.72

    var isScreenRecordingAllowed: Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func captureSnapshot(near caretBounds: CGRect?) async throws -> ScreenContextSnapshot {
        guard isScreenRecordingAllowed else {
            throw ScreenCaptureContextError.permissionDenied
        }

        let content = try await SCShareableContent.current
        guard let display = displayForCapture(from: content.displays, caretBounds: caretBounds) else {
            throw ScreenCaptureContextError.noDisplayAvailable
        }

        let ownProcessID = ProcessInfo.processInfo.processIdentifier
        let excludedApplications = content.applications.filter { $0.processID == ownProcessID }
        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApplications,
            exceptingWindows: []
        )
        if #available(macOS 14.2, *) {
            filter.includeMenuBar = true
        }

        let configuration = SCStreamConfiguration()
        let targetSize = scaledPixelSize(for: filter)
        configuration.width = targetSize.width
        configuration.height = targetSize.height
        configuration.showsCursor = false
        configuration.queueDepth = 1
        configuration.scalesToFit = true
        configuration.preservesAspectRatio = true
        configuration.captureResolution = .best

        let image = try await captureImage(contentFilter: filter, configuration: configuration)
        let imageData = try encodeJPEG(image)

        return ScreenContextSnapshot(
            capturedAt: Date(),
            imageData: imageData,
            mimeType: "image/jpeg",
            pixelWidth: image.width,
            pixelHeight: image.height,
            sourceDescription: "Display \(display.displayID)"
        )
    }

    private func displayForCapture(from displays: [SCDisplay], caretBounds: CGRect?) -> SCDisplay? {
        if let caretBounds {
            let caretPoint = CGPoint(x: caretBounds.midX, y: caretBounds.midY)
            if let containingDisplay = displays.first(where: { $0.frame.contains(caretPoint) }) {
                return containingDisplay
            }
        }

        if let mainDisplayID = NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
           let mainDisplay = displays.first(where: { $0.displayID == mainDisplayID }) {
            return mainDisplay
        }

        return displays.first
    }

    private func scaledPixelSize(for filter: SCContentFilter) -> (width: Int, height: Int) {
        let scale = max(CGFloat(filter.pointPixelScale), 1)
        let contentSize = filter.contentRect.size
        let rawWidth = max(contentSize.width * scale, 1)
        let rawHeight = max(contentSize.height * scale, 1)
        let longestSide = max(rawWidth, rawHeight)

        guard longestSide > CGFloat(maximumPixelDimension) else {
            return (Int(rawWidth.rounded()), Int(rawHeight.rounded()))
        }

        let ratio = CGFloat(maximumPixelDimension) / longestSide
        return (
            Int((rawWidth * ratio).rounded()),
            Int((rawHeight * ratio).rounded())
        )
    }

    private func captureImage(contentFilter: SCContentFilter, configuration: SCStreamConfiguration) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: contentFilter, configuration: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let image else {
                    continuation.resume(throwing: ScreenCaptureContextError.emptyCapture)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }

    private func encodeJPEG(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ScreenCaptureContextError.imageEncodingFailed
        }

        let options = [
            kCGImageDestinationLossyCompressionQuality: jpegQuality
        ] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)

        guard CGImageDestinationFinalize(destination) else {
            throw ScreenCaptureContextError.imageEncodingFailed
        }

        return data as Data
    }
}

enum ScreenCaptureContextError: LocalizedError {
    case permissionDenied
    case noDisplayAvailable
    case emptyCapture
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Screen Recording permission is required before screenshots can be used as context."
        case .noDisplayAvailable:
            "No display was available for screenshot context."
        case .emptyCapture:
            "ScreenCaptureKit returned an empty screenshot."
        case .imageEncodingFailed:
            "Could not encode the screenshot for model input."
        }
    }
}

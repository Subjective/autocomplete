import AppKit
import SwiftUI

final class SuggestionWindowController {
    private let panel: NSPanel
    private let hostingView: NSHostingView<SuggestionBubbleView>

    init() {
        hostingView = NSHostingView(rootView: SuggestionBubbleView(text: ""))
        hostingView.frame = CGRect(x: 0, y: 0, width: 360, height: 42)

        panel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    func show(_ suggestion: CompletionSuggestion, near rect: CGRect?) {
        hostingView.rootView = SuggestionBubbleView(text: suggestion.text)

        let preferredSize = hostingView.fittingSize
        let width = min(max(preferredSize.width, 220), 520)
        let height = min(max(preferredSize.height, 40), 90)
        panel.setContentSize(NSSize(width: width, height: height))
        panel.setFrameOrigin(anchorPoint(for: rect, panelSize: NSSize(width: width, height: height)))
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func anchorPoint(for rect: CGRect?, panelSize: NSSize) -> NSPoint {
        guard let rect, let screen = NSScreen.screen(containing: rect) ?? NSScreen.main else {
            let mouse = NSEvent.mouseLocation
            return NSPoint(x: mouse.x + 14, y: mouse.y - panelSize.height - 14)
        }

        let rawPoint = NSPoint(x: rect.maxX + 8, y: rect.minY - panelSize.height - 6)
        let flippedY = screen.frame.maxY - rect.maxY - panelSize.height - 6
        let flippedPoint = NSPoint(x: rect.maxX + 8, y: flippedY)
        let candidate = screen.visibleFrame.contains(rawPoint) ? rawPoint : flippedPoint

        let clampedX = min(max(candidate.x, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - panelSize.width - 8)
        let clampedY = min(max(candidate.y, screen.visibleFrame.minY + 8), screen.visibleFrame.maxY - panelSize.height - 8)
        return NSPoint(x: clampedX, y: clampedY)
    }
}

private extension NSScreen {
    static func screen(containing rect: CGRect) -> NSScreen? {
        screens.first { screen in
            screen.frame.intersects(rect) || screen.frame.contains(NSPoint(x: rect.midX, y: rect.midY))
        }
    }
}

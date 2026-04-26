import AppKit
import SwiftUI

final class SuggestionWindowController {
    private let panel: NSPanel
    private let hostingView: NSHostingView<SuggestionBubbleView>

    init() {
        hostingView = NSHostingView(rootView: SuggestionBubbleView(text: "", style: .popup, hotKey: "Option+Tab"))
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

    func show(
        _ suggestion: CompletionSuggestion,
        style: SuggestionPresentationStyle,
        hotKey: String,
        near rect: CGRect?
    ) {
        let renderStyle = suggestion.isEditPrediction ? SuggestionPresentationStyle.popup : style
        let caretHeight = max(rect?.height ?? 16, 1)
        hostingView.rootView = SuggestionBubbleView(
            suggestion: suggestion,
            style: renderStyle,
            hotKey: hotKey,
            caretHeight: caretHeight
        )
        panel.hasShadow = renderStyle.hasShadow

        let preferredSize = hostingView.fittingSize
        let maxWidth = suggestion.isEditPrediction ? 640 : renderStyle.maxWidth
        let maxHeight = suggestion.isEditPrediction ? 140 : renderStyle.maxHeight
        let width = min(max(preferredSize.width, renderStyle.minWidth), maxWidth)
        let height = min(max(preferredSize.height, renderStyle.minHeight), maxHeight)
        panel.setContentSize(NSSize(width: width, height: height))
        panel.setFrameOrigin(anchorPoint(for: rect, panelSize: NSSize(width: width, height: height), style: renderStyle))
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func anchorPoint(for rect: CGRect?, panelSize: NSSize, style: SuggestionPresentationStyle) -> NSPoint {
        guard let rect else {
            return fallbackPoint(panelSize: panelSize)
        }

        guard let screen = NSScreen.screen(containingAccessibilityRect: rect) ?? NSScreen.main else {
            return fallbackPoint(panelSize: panelSize)
        }

        if style == .commandPalette {
            return NSPoint(
                x: screen.visibleFrame.midX - panelSize.width / 2,
                y: screen.visibleFrame.maxY - panelSize.height - 84
            )
        }

        let appKitRect = screen.appKitRect(fromAccessibilityRect: rect)
        let candidate: NSPoint

        if style == .ghostText || style == .textOnly {
            candidate = NSPoint(
                x: appKitRect.maxX + inlineHorizontalGap(for: appKitRect.height),
                y: appKitRect.minY + (appKitRect.height - panelSize.height) / 2
            )
        } else {
            let horizontalOffset = popupHorizontalGap(for: appKitRect.height)
            let verticalOffset = popupVerticalGap(for: appKitRect.height)
            candidate = NSPoint(
                x: appKitRect.maxX + horizontalOffset,
                y: appKitRect.minY - panelSize.height - verticalOffset
            )
        }

        let clampedX = min(max(candidate.x, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - panelSize.width - 8)
        let clampedY = min(max(candidate.y, screen.visibleFrame.minY + 8), screen.visibleFrame.maxY - panelSize.height - 8)
        return NSPoint(x: clampedX, y: clampedY)
    }

    private func fallbackPoint(panelSize: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else {
            return NSPoint.zero
        }

        return NSPoint(
            x: screen.visibleFrame.midX - panelSize.width / 2,
            y: screen.visibleFrame.maxY - panelSize.height - 84
        )
    }

    private func inlineHorizontalGap(for caretHeight: CGFloat) -> CGFloat {
        min(max(caretHeight * 0.06, 0), 2)
    }

    private func popupHorizontalGap(for caretHeight: CGFloat) -> CGFloat {
        min(max(caretHeight * 0.28, 4), 10)
    }

    private func popupVerticalGap(for caretHeight: CGFloat) -> CGFloat {
        min(max(caretHeight * 0.22, 3), 9)
    }
}

private extension NSScreen {
    static func screen(containingAccessibilityRect rect: CGRect) -> NSScreen? {
        screens.first { screen in
            screen.accessibilityFrame.intersects(rect) ||
                screen.accessibilityFrame.contains(NSPoint(x: rect.midX, y: rect.midY))
        }
    }

    var accessibilityFrame: CGRect {
        guard let mainFrame = NSScreen.main?.frame else {
            return frame
        }

        return CGRect(
            x: frame.minX,
            y: mainFrame.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    func appKitRect(fromAccessibilityRect rect: CGRect) -> CGRect {
        let yWithinScreen = rect.minY - accessibilityFrame.minY
        return CGRect(
            x: rect.minX,
            y: frame.maxY - yWithinScreen - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}

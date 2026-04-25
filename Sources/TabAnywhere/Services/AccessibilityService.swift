import AppKit
import ApplicationServices
import Foundation

final class AccessibilityService {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestPermissionPrompt() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary

        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func focusedContext() -> CompletionContext? {
        let systemWide = AXUIElementCreateSystemWide()

        guard let element = copyAttribute(systemWide, kAXFocusedUIElementAttribute) as AXUIElement? else {
            return nil
        }

        guard isEditableTextElement(element), !isSecureTextElement(element) else {
            return nil
        }

        let role = copyAttribute(element, kAXRoleAttribute) as String? ?? "Unknown"
        let value = copyAttribute(element, kAXValueAttribute) as String? ?? ""
        let selectedRange = selectedTextRange(in: element)
        let resolvedCaretBounds: CGRect?
        if let selectedRange {
            resolvedCaretBounds = caretBounds(for: element, selectedRange: selectedRange)
        } else {
            resolvedCaretBounds = nil
        }
        let appElement = copyAttribute(systemWide, kAXFocusedApplicationAttribute) as AXUIElement?
        let appName = appElement.flatMap(resolveAppName(for:)) ?? "Unknown App"
        let windowTitle = appElement.flatMap(resolveWindowTitle(for:))

        return CompletionContext(
            element: element,
            appName: appName,
            windowTitle: windowTitle,
            role: role,
            value: value,
            selectedRange: selectedRange,
            caretBounds: resolvedCaretBounds
        )
    }

    private func isEditableTextElement(_ element: AXUIElement) -> Bool {
        let role = copyAttribute(element, kAXRoleAttribute) as String?
        let roleDescription = copyAttribute(element, kAXRoleDescriptionAttribute) as String?

        if role == kAXTextAreaRole as String ||
            role == kAXTextFieldRole as String ||
            role == kAXComboBoxRole as String {
            return true
        }

        if roleDescription?.localizedCaseInsensitiveContains("text") == true {
            return true
        }

        var settable = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success {
            return settable.boolValue
        }

        return false
    }

    private func isSecureTextElement(_ element: AXUIElement) -> Bool {
        let role = copyAttribute(element, kAXRoleAttribute) as String?
        let subrole = copyAttribute(element, kAXSubroleAttribute) as String?

        return role == "AXSecureTextField" || subrole == "AXSecureTextField"
    }

    private func selectedTextRange(in element: AXUIElement) -> CFRange? {
        guard let value = copyAttribute(element, kAXSelectedTextRangeAttribute) as AXValue? else {
            return nil
        }

        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(value, .cfRange, &range) else {
            return nil
        }

        return range
    }

    private func caretBounds(for element: AXUIElement, selectedRange: CFRange) -> CGRect? {
        var caretRange = CFRange(location: selectedRange.location + selectedRange.length, length: 0)

        guard let rangeValue = AXValueCreate(.cfRange, &caretRange) else {
            return nil
        }

        var rawValue: CFTypeRef?
        let error = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &rawValue
        )

        guard error == .success, let rawValue else {
            return nil
        }

        let axValue = rawValue as! AXValue
        var rect = CGRect.zero
        guard AXValueGetValue(axValue, .cgRect, &rect), rect.isUsableCaretBounds else {
            return nil
        }

        return rect
    }

    private func resolveAppName(for appElement: AXUIElement) -> String? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(appElement, &pid) == .success else {
            return copyAttribute(appElement, kAXTitleAttribute) as String?
        }

        return NSRunningApplication(processIdentifier: pid)?.localizedName
    }

    private func resolveWindowTitle(for appElement: AXUIElement) -> String? {
        guard let window = copyAttribute(appElement, kAXFocusedWindowAttribute) as AXUIElement? else {
            return nil
        }

        return copyAttribute(window, kAXTitleAttribute) as String?
    }

    private func copyAttribute<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else {
            return nil
        }

        return value as? T
    }
}

private extension CGRect {
    var isUsableCaretBounds: Bool {
        !isNull &&
            origin.x.isFinite &&
            origin.y.isFinite &&
            width.isFinite &&
            height.isFinite &&
            width >= 0 &&
            height > 0
    }
}

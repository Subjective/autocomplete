import AppKit
import Combine
import Foundation

final class CompletionCoordinator: ObservableObject {
    @Published var isEnabled = true
    @Published var hasAccessibilityPermission = false
    @Published var focusedAppDescription = "No focused text field yet"
    @Published var activeSuggestionText = ""
    @Published var statusMessage = "Waiting for Accessibility permission"
    @Published var recentEvents: [String] = []
    @Published private(set) var acceptanceHotKey: AcceptanceHotKey
    @Published private(set) var suggestionStyle: SuggestionPresentationStyle

    private let accessibility = AccessibilityService()
    private let provider: CompletionProviding = MockCompletionProvider()
    private let insertion = TextInsertionService()
    private let hotKeyManager = HotKeyManager()
    private let suggestionWindow = SuggestionWindowController()

    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var debounceWorkItem: DispatchWorkItem?
    private var activeSuggestion: CompletionSuggestion?
    private var activeContext: CompletionContext?
    private var didStart = false

    var acceptanceHotKeyDescription: String {
        acceptanceHotKey.label
    }

    var suggestionStyleDescription: String {
        suggestionStyle.title
    }

    init() {
        let storedValue = UserDefaults.standard.string(forKey: "AcceptanceHotKey") ?? AcceptanceHotKey.optionTab.rawValue
        acceptanceHotKey = AcceptanceHotKey(rawValue: storedValue) ?? .optionTab
        let storedStyle = UserDefaults.standard.string(forKey: "SuggestionStyle") ?? SuggestionPresentationStyle.ghostText.rawValue
        suggestionStyle = SuggestionPresentationStyle(rawValue: storedStyle) ?? .ghostText
    }

    deinit {
        stop()
    }

    func start() {
        guard !didStart else {
            refreshPermissionState()
            return
        }

        didStart = true
        refreshPermissionState()
        hotKeyManager.onHotKey = { [weak self] in
            self?.acceptActiveSuggestion()
        }
        hotKeyManager.register(acceptanceHotKey)
        installEventMonitors()
        log("Registered \(acceptanceHotKeyDescription) accept hotkey")
    }

    func stop() {
        debounceWorkItem?.cancel()
        hotKeyManager.unregister()
        suggestionWindow.hide()

        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }

        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }

    func requestAccessibilityPermission() {
        accessibility.requestPermissionPrompt()
        refreshPermissionState()
        log("Requested Accessibility permission")
    }

    func openAccessibilitySettings() {
        accessibility.openAccessibilitySettings()
    }

    func refreshPermissionState() {
        hasAccessibilityPermission = accessibility.isTrusted
        statusMessage = hasAccessibilityPermission
            ? "Running. Type in TextEdit, this window, Safari, or Chrome."
            : "Accessibility permission is required to inspect fields and accept suggestions."
    }

    func refreshFocusedContextNow() {
        refreshPermissionState()

        guard hasAccessibilityPermission else {
            clearSuggestion(reason: "Accessibility permission missing")
            return
        }

        guard let context = accessibility.focusedContext() else {
            focusedAppDescription = "No supported text field focused"
            clearSuggestion(reason: "No editable text field focused")
            return
        }

        focusedAppDescription = context.windowTitle.map {
            "\(context.appName) - \($0) (\(context.role))"
        } ?? "\(context.appName) (\(context.role))"

        guard isEnabled, let suggestion = provider.suggestion(for: context), !suggestion.text.isEmpty else {
            clearSuggestion(reason: "No suggestion for current context")
            return
        }

        activeContext = context
        activeSuggestion = suggestion
        activeSuggestionText = suggestion.text
        suggestionWindow.show(
            suggestion,
            style: suggestionStyle,
            hotKey: acceptanceHotKeyDescription,
            near: context.caretBounds
        )
        statusMessage = "Suggestion ready in \(suggestion.contextSummary)"
        log("Suggested \(suggestion.text)")
    }

    func acceptActiveSuggestion() {
        refreshPermissionState()

        guard hasAccessibilityPermission else {
            clearSuggestion(reason: "Cannot accept without Accessibility permission")
            return
        }

        guard let suggestion = activeSuggestion, let context = activeContext else {
            log("No active suggestion to accept")
            return
        }

        _ = insertion.insert(suggestion, into: context)
        log("Accepted \(suggestion.text)")
        clearSuggestion(reason: "Suggestion accepted")
    }

    func toggleEnabled() {
        isEnabled.toggle()
        if !isEnabled {
            clearSuggestion(reason: "Paused")
        } else {
            scheduleSuggestionRefresh(reason: "Resumed")
        }
    }

    func setAcceptanceHotKey(_ hotKey: AcceptanceHotKey) {
        acceptanceHotKey = hotKey
        UserDefaults.standard.set(hotKey.rawValue, forKey: "AcceptanceHotKey")
        hotKeyManager.register(hotKey)
        log("Registered \(hotKey.label) accept hotkey")
    }

    func setSuggestionStyle(_ style: SuggestionPresentationStyle) {
        suggestionStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: "SuggestionStyle")
        log("Selected \(style.title) suggestion style")

        if let activeSuggestion, let activeContext {
            suggestionWindow.show(
                activeSuggestion,
                style: style,
                hotKey: acceptanceHotKeyDescription,
                near: activeContext.caretBounds
            )
        }
    }

    func previewSuggestionStyle(_ style: SuggestionPresentationStyle) {
        let suggestion = CompletionSuggestion(
            text: " — completed by TabAnywhere.",
            contextSummary: "Style Preview"
        )
        suggestionWindow.show(
            suggestion,
            style: style,
            hotKey: acceptanceHotKeyDescription,
            near: nil
        )
        statusMessage = "Previewing \(style.title)"
        log("Previewed \(style.title) style")
    }

    private func installEventMonitors() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleObservedEvent(event)
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleObservedEvent(event)
            return event
        }
    }

    private func handleObservedEvent(_ event: NSEvent) {
        guard isEnabled else {
            return
        }

        switch event.type {
        case .keyDown:
            let isAcceptanceKey = event.keyCode == 48 &&
                (event.modifierFlags.contains(.option) || acceptanceHotKey == .tab)
            if isAcceptanceKey {
                return
            }
            clearSuggestion(reason: "Typing continued", shouldLog: false)
            scheduleSuggestionRefresh(reason: "Typing pause")
        case .leftMouseDown, .rightMouseDown:
            clearSuggestion(reason: "Focus changed", shouldLog: false)
            scheduleSuggestionRefresh(reason: "Focus refresh")
        default:
            break
        }
    }

    private func scheduleSuggestionRefresh(reason: String) {
        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshFocusedContextNow()
        }
        debounceWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)
        statusMessage = "\(reason)..."
    }

    private func clearSuggestion(reason: String, shouldLog: Bool = true) {
        activeSuggestion = nil
        activeContext = nil
        activeSuggestionText = ""
        suggestionWindow.hide()
        statusMessage = reason

        if shouldLog {
            log(reason)
        }
    }

    private func log(_ message: String) {
        let timestamp = DateFormatter.tabAnywhereTime.string(from: Date())
        recentEvents.insert("[\(timestamp)] \(message)", at: 0)
        recentEvents = Array(recentEvents.prefix(8))
    }
}

private extension DateFormatter {
    static let tabAnywhereTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

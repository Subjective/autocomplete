import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

final class CompletionCoordinator: ObservableObject {
    @Published var isEnabled = true
    @Published var hasAccessibilityPermission = false
    @Published var focusedAppDescription = "No focused text field yet"
    @Published var activeSuggestionText = ""
    @Published var statusMessage = "Waiting for Accessibility permission"
    @Published var recentEvents: [String] = []
    @Published var selectedProviderKind: CompletionProviderKind
    @Published var modelSearchQuery: String
    @Published var selectedModelID: String
    @Published var selectedGGUFFile: String
    @Published var localModelPath: String
    @Published var cloudBaseURL: String
    @Published var cloudAPIKey: String
    @Published var cloudModelID: String
    @Published private(set) var modelSearchResults: [ModelSearchResult] = []
    @Published private(set) var modelStatusMessage = "Mock provider selected"
    @Published private(set) var isSearchingModels = false
    @Published private(set) var isDownloadingModel = false
    @Published private(set) var modelDownloadProgress = 0.0
    @Published private(set) var acceptanceHotKey: AcceptanceHotKey
    @Published private(set) var suggestionStyle: SuggestionPresentationStyle

    private let accessibility = AccessibilityService()
    private let mockProvider: CompletionProviding = MockCompletionProvider()
    private let modelCatalog = ModelCatalogService()
    private let insertion = TextInsertionService()
    private let hotKeyManager = HotKeyManager()
    private let suggestionWindow = SuggestionWindowController()

    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var debounceWorkItem: DispatchWorkItem?
    private var generationTask: Task<Void, Never>?
    private var modelSearchTask: Task<Void, Never>?
    private var modelDownloadTask: Task<Void, Never>?
    private var activeSuggestion: CompletionSuggestion?
    private var activeContext: CompletionContext?
    private var cachedProviderConfiguration: AnyLanguageModelProviderConfiguration?
    private var cachedAnyProvider: AnyLanguageModelCompletionProvider?
    private var generationRequestID = 0
    private var didStart = false

    var acceptanceHotKeyDescription: String {
        acceptanceHotKey.label
    }

    var suggestionStyleDescription: String {
        suggestionStyle.title
    }

    var providerDescription: String {
        selectedProviderKind.title
    }

    var selectedModelDescription: String {
        switch selectedProviderKind {
        case .mock:
            "Mock deterministic"
        case .localLlama:
            localModelPath.isEmpty ? "\(selectedModelID) / \(selectedGGUFFile)" : URL(fileURLWithPath: localModelPath).lastPathComponent
        case .huggingFaceRouter, .gemini, .openAICompatible:
            cloudModelID
        }
    }

    init() {
        let storedValue = UserDefaults.standard.string(forKey: "AcceptanceHotKey") ?? AcceptanceHotKey.optionTab.rawValue
        acceptanceHotKey = AcceptanceHotKey(rawValue: storedValue) ?? .optionTab
        let storedStyle = UserDefaults.standard.string(forKey: "SuggestionStyle") ?? SuggestionPresentationStyle.ghostText.rawValue
        suggestionStyle = SuggestionPresentationStyle(rawValue: storedStyle) ?? .ghostText
        let storedProvider = UserDefaults.standard.string(forKey: "CompletionProviderKind") ?? CompletionProviderKind.mock.rawValue
        selectedProviderKind = CompletionProviderKind(rawValue: storedProvider) ?? .mock
        modelSearchQuery = UserDefaults.standard.string(forKey: "ModelSearchQuery") ?? "gemma 4 gguf"
        selectedModelID = UserDefaults.standard.string(forKey: "SelectedModelID") ?? "ggml-org/gemma-4-E2B-it-GGUF"
        selectedGGUFFile = UserDefaults.standard.string(forKey: "SelectedGGUFFile") ?? ""
        localModelPath = UserDefaults.standard.string(forKey: "LocalModelPath") ?? ""
        cloudBaseURL = UserDefaults.standard.string(forKey: "CloudBaseURL") ?? "https://router.huggingface.co/v1"
        cloudAPIKey = UserDefaults.standard.string(forKey: "CloudAPIKey") ?? ""
        cloudModelID = UserDefaults.standard.string(forKey: "CloudModelID") ?? CompletionProviderKind.huggingFaceRouter.defaultCloudModelID ?? ""
        updateModelStatus()
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
        generationTask?.cancel()
        modelSearchTask?.cancel()
        modelDownloadTask?.cancel()
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

        guard isEnabled else {
            clearSuggestion(reason: "No suggestion for current context")
            return
        }

        activeContext = context
        activeSuggestion = nil
        activeSuggestionText = ""
        suggestionWindow.hide()
        statusMessage = "Generating with \(providerDescription)..."

        let requestID = generationRequestID + 1
        generationRequestID = requestID
        generationTask?.cancel()
        generationTask = Task { [weak self, context, requestID] in
            guard let self else {
                return
            }

            do {
                let provider = self.makeCompletionProvider()
                let suggestion = try await provider.suggestion(for: context)

                await MainActor.run {
                    guard self.generationRequestID == requestID, !Task.isCancelled else {
                        return
                    }

                    guard let suggestion, !suggestion.text.isEmpty else {
                        self.clearSuggestion(reason: "No suggestion for current context")
                        return
                    }

                    self.activeContext = context
                    self.activeSuggestion = suggestion
                    self.activeSuggestionText = suggestion.text
                    self.suggestionWindow.show(
                        suggestion,
                        style: self.suggestionStyle,
                        hotKey: self.acceptanceHotKeyDescription,
                        near: context.caretBounds
                    )
                    self.statusMessage = "Suggestion ready in \(suggestion.contextSummary)"
                    self.log("Suggested \(suggestion.text)")
                }
            } catch {
                await MainActor.run {
                    guard self.generationRequestID == requestID, !Task.isCancelled else {
                        return
                    }

                    let reason = "Provider unavailable: \(error.localizedDescription)"
                    self.modelStatusMessage = reason
                    self.clearSuggestion(reason: reason)
                    return
                }
            }
        }
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

    func setProviderKind(_ provider: CompletionProviderKind) {
        selectedProviderKind = provider
        UserDefaults.standard.set(provider.rawValue, forKey: "CompletionProviderKind")
        if shouldReplaceCloudModelForProviderSwitch(to: provider), let defaultModelID = provider.defaultCloudModelID {
            setCloudModelID(defaultModelID)
        }
        invalidateCompletionProvider()
        updateModelStatus()
        clearSuggestion(reason: "Selected \(provider.title) provider")
    }

    func setModelSearchQuery(_ query: String) {
        modelSearchQuery = query
        UserDefaults.standard.set(query, forKey: "ModelSearchQuery")
    }

    func setSelectedModelID(_ modelID: String) {
        selectedModelID = modelID
        UserDefaults.standard.set(modelID, forKey: "SelectedModelID")
        updateModelStatus()
    }

    func setSelectedGGUFFile(_ file: String) {
        selectedGGUFFile = file
        UserDefaults.standard.set(file, forKey: "SelectedGGUFFile")
        updateModelStatus()
    }

    func setLocalModelPath(_ path: String) {
        localModelPath = path
        UserDefaults.standard.set(path, forKey: "LocalModelPath")
        invalidateCompletionProvider()
        updateModelStatus()
    }

    func setCloudBaseURL(_ baseURL: String) {
        cloudBaseURL = baseURL
        UserDefaults.standard.set(baseURL, forKey: "CloudBaseURL")
        invalidateCompletionProvider()
        updateModelStatus()
    }

    func setCloudAPIKey(_ apiKey: String) {
        cloudAPIKey = apiKey
        UserDefaults.standard.set(apiKey, forKey: "CloudAPIKey")
        invalidateCompletionProvider()
        updateModelStatus()
    }

    func setCloudModelID(_ modelID: String) {
        cloudModelID = modelID
        UserDefaults.standard.set(modelID, forKey: "CloudModelID")
        invalidateCompletionProvider()
        updateModelStatus()
    }

    func searchModels() {
        modelSearchTask?.cancel()
        isSearchingModels = true
        modelStatusMessage = "Searching Hugging Face..."

        modelSearchTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let results = try await self.modelCatalog.searchGGUFModels(query: self.modelSearchQuery)
                await MainActor.run {
                    self.modelSearchResults = results
                    self.isSearchingModels = false
                    self.modelStatusMessage = results.isEmpty ? "No GGUF models found" : "Found \(results.count) model\(results.count == 1 ? "" : "s")"
                }
            } catch {
                await MainActor.run {
                    self.isSearchingModels = false
                    self.modelStatusMessage = "Model search failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func selectModelSearchResult(_ result: ModelSearchResult) {
        setSelectedModelID(result.id)
        if let firstFile = preferredGGUFFile(from: result.ggufFiles) {
            setSelectedGGUFFile(firstFile.path)
        }
        modelStatusMessage = "Selected \(result.id)"
    }

    func downloadSelectedModel() {
        guard !selectedModelID.isEmpty, !selectedGGUFFile.isEmpty else {
            modelStatusMessage = "Select a GGUF file before downloading"
            return
        }

        modelDownloadTask?.cancel()
        isDownloadingModel = true
        modelDownloadProgress = 0
        modelStatusMessage = "Downloading \(selectedGGUFFile)..."

        modelDownloadTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let url = try await self.modelCatalog.downloadGGUF(
                    modelID: self.selectedModelID,
                    filePath: self.selectedGGUFFile
                ) { progress in
                    self.modelDownloadProgress = progress.fractionCompleted.isFinite ? progress.fractionCompleted : 0
                }

                await MainActor.run {
                    self.isDownloadingModel = false
                    self.modelDownloadProgress = 1
                    self.setLocalModelPath(url.path)
                    self.modelStatusMessage = "Downloaded \(url.lastPathComponent)"
                }
            } catch {
                await MainActor.run {
                    self.isDownloadingModel = false
                    self.modelStatusMessage = "Download failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func chooseLocalModelFile() {
        let panel = NSOpenPanel()
        if let ggufType = UTType(filenameExtension: "gguf") {
            panel.allowedContentTypes = [ggufType]
        }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.nameFieldStringValue = "Model GGUF"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }
            self?.setLocalModelPath(url.path)
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
        generationRequestID += 1
        generationTask?.cancel()
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

    private func makeCompletionProvider() -> CompletionProviding {
        switch selectedProviderKind {
        case .mock:
            return mockProvider
        case .localLlama, .huggingFaceRouter, .gemini, .openAICompatible:
            let configuration = AnyLanguageModelProviderConfiguration(
                kind: selectedProviderKind,
                localModelPath: localModelPath,
                cloudBaseURL: selectedProviderKind == .huggingFaceRouter ? "https://router.huggingface.co/v1" : cloudBaseURL,
                cloudAPIKey: cloudAPIKey,
                cloudModelID: cloudModelID
            )

            if cachedProviderConfiguration == configuration, let cachedAnyProvider {
                return cachedAnyProvider
            }

            let provider = AnyLanguageModelCompletionProvider(configuration: configuration)
            cachedProviderConfiguration = configuration
            cachedAnyProvider = provider
            return provider
        }
    }

    private func invalidateCompletionProvider() {
        cachedProviderConfiguration = nil
        cachedAnyProvider = nil
    }

    private func shouldReplaceCloudModelForProviderSwitch(to provider: CompletionProviderKind) -> Bool {
        guard provider.defaultCloudModelID != nil else {
            return false
        }

        let appProvidedDefaults = CompletionProviderKind.allCases.compactMap(\.defaultCloudModelID) + ["gemini-2.5-flash"]
        return cloudModelID.isEmpty || appProvidedDefaults.contains(cloudModelID)
    }

    private func updateModelStatus() {
        switch selectedProviderKind {
        case .mock:
            modelStatusMessage = "Mock provider selected"
        case .localLlama:
            modelStatusMessage = localModelPath.isEmpty
                ? "Download or choose a GGUF model"
                : "Local model ready: \(URL(fileURLWithPath: localModelPath).lastPathComponent)"
        case .huggingFaceRouter:
            modelStatusMessage = cloudAPIKey.isEmpty
                ? "Add a Hugging Face token to use the router"
                : "Router model ready: \(cloudModelID)"
        case .gemini:
            modelStatusMessage = cloudAPIKey.isEmpty
                ? "Add a Google AI Studio API key to use Gemini"
                : "Gemini model ready: \(cloudModelID)"
        case .openAICompatible:
            modelStatusMessage = cloudAPIKey.isEmpty
                ? "Add an API key to use the endpoint"
                : "Cloud model ready: \(cloudModelID)"
        }
    }

    private func preferredGGUFFile(from files: [GGUFFile]) -> GGUFFile? {
        files.first { $0.name.localizedCaseInsensitiveContains("q4") }
            ?? files.first { $0.name.localizedCaseInsensitiveContains("Q4") }
            ?? files.first
    }
}

private extension DateFormatter {
    static let tabAnywhereTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

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
    @Published var screenshotContextEnabled: Bool
    @Published private(set) var hasScreenRecordingPermission = false
    @Published private(set) var screenContextStatusMessage = "Screenshot context not checked"
    @Published private(set) var modelSearchResults: [ModelSearchResult] = []
    @Published private(set) var modelStatusMessage = "Mock provider selected"
    @Published private(set) var isSearchingModels = false
    @Published private(set) var isDownloadingModel = false
    @Published private(set) var modelDownloadProgress = 0.0
    @Published private(set) var lastPromptSnapshot: PromptInspectionSnapshot?
    @Published private(set) var acceptanceHotKey: AcceptanceHotKey
    @Published private(set) var suggestionStyle: SuggestionPresentationStyle

    private let accessibility = AccessibilityService()
    private let mockProvider: CompletionProviding = MockCompletionProvider()
    private let modelCatalog = ModelCatalogService()
    private let insertion = TextInsertionService()
    private let hotKeyManager = HotKeyManager()
    private let suggestionWindow = SuggestionWindowController()
    private let screenCapture = ScreenCaptureContextService()

    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var debounceWorkItem: DispatchWorkItem?
    private var generationTask: Task<Void, Never>?
    private var modelSearchTask: Task<Void, Never>?
    private var modelDownloadTask: Task<Void, Never>?
    private var activeSuggestion: CompletionSuggestion?
    private var activeSuggestions: [CompletionSuggestion] = []
    private var activeContext: CompletionContext?
    private var cachedProviderConfiguration: AnyLanguageModelProviderConfiguration?
    private var cachedAnyProvider: AnyLanguageModelCompletionProvider?
    private var generationRequestID = 0
    private let maximumSuggestionCount = 1
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
        screenshotContextEnabled = UserDefaults.standard.object(forKey: "ScreenshotContextEnabled") as? Bool ?? false
        updateModelStatus()
        refreshScreenRecordingPermissionState()
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

    func requestScreenRecordingPermission() {
        _ = screenCapture.requestScreenRecordingPermission()
        refreshScreenRecordingPermissionState()
        log("Requested Screen Recording permission")
    }

    func openAccessibilitySettings() {
        accessibility.openAccessibilitySettings()
    }

    func openScreenRecordingSettings() {
        screenCapture.openScreenRecordingSettings()
    }

    func refreshPermissionState() {
        hasAccessibilityPermission = accessibility.isTrusted
        statusMessage = hasAccessibilityPermission
            ? "Running. Type in TextEdit, this window, Safari, or Chrome."
            : "Accessibility permission is required to inspect fields and accept suggestions."
    }

    func refreshScreenRecordingPermissionState() {
        guard screenshotContextEnabled else {
            hasScreenRecordingPermission = screenCapture.isScreenRecordingAllowed
            screenContextStatusMessage = "Screenshot context disabled"
            return
        }

        hasScreenRecordingPermission = screenCapture.isScreenRecordingAllowed
        screenContextStatusMessage = hasScreenRecordingPermission
            ? "Screenshot context ready"
            : "Screen Recording permission is needed for screenshot context"
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
        activeSuggestions = []
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
                let requestContext = await self.contextByAddingScreenContext(to: context)
                let provider = self.makeCompletionProvider()
                let promptSnapshot = self.makePromptSnapshot(for: requestContext)
                await MainActor.run {
                    guard self.generationRequestID == requestID, !Task.isCancelled else {
                        return
                    }
                    self.lastPromptSnapshot = promptSnapshot
                }
                let suggestions = try await provider.suggestions(for: requestContext, maximumCount: self.maximumSuggestionCount)

                await MainActor.run {
                    guard self.generationRequestID == requestID, !Task.isCancelled else {
                        return
                    }

                    guard let suggestion = suggestions.first, !suggestion.text.isEmpty else {
                        self.lastPromptSnapshot = promptSnapshot.withResult("No suggestion")
                        self.clearSuggestion(reason: "No suggestion for current context")
                        return
                    }

                    self.lastPromptSnapshot = promptSnapshot.withResult("Suggested: \(suggestions.map(\.text).joined(separator: " | "))")
                    self.activeContext = requestContext
                    self.activeSuggestion = suggestion
                    self.activeSuggestions = suggestions
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
                    self.lastPromptSnapshot = self.lastPromptSnapshot?.withResult(reason)
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

        if insertion.insert(suggestion, into: context) {
            log("Accepted \(suggestion.text)")
            clearSuggestion(reason: "Suggestion accepted")
        } else {
            log("Could not apply \(suggestion.text)")
            clearSuggestion(reason: "Could not apply suggestion in this field")
        }
    }

    func toggleEnabled() {
        isEnabled.toggle()
        if !isEnabled {
            clearSuggestion(reason: "Paused")
        } else {
            scheduleSuggestionRefresh(reason: "Resumed")
        }
    }

    func setScreenshotContextEnabled(_ isEnabled: Bool) {
        screenshotContextEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: "ScreenshotContextEnabled")
        if isEnabled {
            refreshScreenRecordingPermissionState()
            scheduleSuggestionRefresh(reason: "Screenshot context enabled")
        } else {
            screenContextStatusMessage = "Screenshot context disabled"
            scheduleSuggestionRefresh(reason: "Screenshot context disabled")
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
                let details = try await self.modelCatalog.details(for: self.selectedModelID)
                let mmprojFile = self.preferredMMProjFile(from: details.ggufFiles)
                let filePaths = Array(Set(([self.selectedGGUFFile] + [mmprojFile?.path].compactMap { $0 })))

                try await self.modelCatalog.downloadGGUFFiles(
                    modelID: self.selectedModelID,
                    filePaths: filePaths
                ) { progress in
                    self.modelDownloadProgress = progress.fractionCompleted.isFinite ? progress.fractionCompleted : 0
                }
                let url = try self.modelCatalog.localFileURL(
                    modelID: self.selectedModelID,
                    filePath: self.selectedGGUFFile
                )

                await MainActor.run {
                    self.isDownloadingModel = false
                    self.modelDownloadProgress = 1
                    self.setLocalModelPath(url.path)
                    if let mmprojFile {
                        self.modelStatusMessage = "Downloaded \(url.lastPathComponent) with \(mmprojFile.name)"
                    } else {
                        self.modelStatusMessage = "Downloaded \(url.lastPathComponent)"
                    }
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
        activeSuggestions = []
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

    private func makePromptSnapshot(for context: CompletionContext) -> PromptInspectionSnapshot {
        let payload: CompletionPromptPayload
        switch selectedProviderKind {
        case .mock:
            payload = CompletionPromptPayload(systemPrompt: "Mock provider", userPrompt: "Mock provider does not send a model prompt.")
        case .localLlama, .huggingFaceRouter, .gemini, .openAICompatible:
            let provider = makeCompletionProvider() as? AnyLanguageModelCompletionProvider
            payload = provider?.promptPayload(for: context) ?? CompletionPromptPayload(
                systemPrompt: "Unavailable",
                userPrompt: "Could not build edit prediction prompt."
            )
        }

        return PromptInspectionSnapshot(
            provider: providerDescription,
            model: selectedModelDescription,
            systemPrompt: payload.systemPrompt,
            userPrompt: payload.userPrompt,
            transportDescription: promptTransportDescription,
            screenContext: context.screenContext,
            screenContextStatus: screenContextStatusMessage,
            createdAt: Date(),
            result: "Pending"
        )
    }

    private func recordSkippedPrompt(for context: CompletionContext, result: String) {
        var snapshot = makePromptSnapshot(for: context)
        snapshot = snapshot.withResult(result)
        lastPromptSnapshot = snapshot
    }

    private var promptTransportDescription: String {
        switch selectedProviderKind {
        case .mock:
            return "No model transport"
        case .localLlama:
            return "OpenAI-compatible chat completion via local llama-server --jinja at http://127.0.0.1:18080/v1"
        case .huggingFaceRouter:
            return "OpenAI-compatible chat completion via Hugging Face Router"
        case .gemini:
            return "Gemini API via AnyLanguageModel"
        case .openAICompatible:
            return "OpenAI-compatible chat completion via \(cloudBaseURL)"
        }
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
                cloudModelID: cloudModelID,
                allowsScreenImageInput: screenImageInputAllowed(for: selectedProviderKind)
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
                : localModelStatusDescription
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

    private var localModelStatusDescription: String {
        let name = URL(fileURLWithPath: localModelPath).lastPathComponent
        if LlamaServerManager.multimodalProjectorPath(for: localModelPath) != nil {
            return "Local model ready with screenshot projector: \(name)"
        }

        return "Local model ready, text-only until mmproj*.gguf is next to it: \(name)"
    }

    private func contextByAddingScreenContext(to context: CompletionContext) async -> CompletionContext {
        let screenshotContextEnabled = await MainActor.run {
            self.screenshotContextEnabled
        }
        guard screenshotContextEnabled else {
            await MainActor.run {
                self.screenContextStatusMessage = "Screenshot context disabled"
            }
            return context
        }

        let providerAllowsScreenImage = await MainActor.run {
            self.screenImageInputAllowed(for: self.selectedProviderKind)
        }
        guard providerAllowsScreenImage else {
            await MainActor.run {
                self.screenContextStatusMessage = self.screenImageInputUnavailableReason(for: self.selectedProviderKind)
            }
            return context
        }

        guard screenCapture.isScreenRecordingAllowed else {
            await MainActor.run {
                self.hasScreenRecordingPermission = false
                self.screenContextStatusMessage = "Screen Recording permission is needed for screenshot context"
            }
            return context
        }

        await MainActor.run {
            self.hasScreenRecordingPermission = true
            self.screenContextStatusMessage = "Capturing screenshot context..."
        }

        do {
            let snapshot = try await screenCapture.captureSnapshot(near: context.caretBounds)
            await MainActor.run {
                self.screenContextStatusMessage = "Attached screenshot context: \(snapshot.pixelWidth)x\(snapshot.pixelHeight)"
            }
            return context.withScreenContext(snapshot)
        } catch {
            await MainActor.run {
                self.screenContextStatusMessage = "Screenshot skipped: \(error.localizedDescription)"
            }
            return context
        }
    }

    private func screenImageInputAllowed(for provider: CompletionProviderKind) -> Bool {
        switch provider {
        case .mock:
            return false
        case .gemini, .openAICompatible:
            return true
        case .huggingFaceRouter:
            let model = cloudModelID.lowercased()
            return model.contains("gemma-4") || model.contains("vision") || model.contains("-vl")
        case .localLlama:
            return LlamaServerManager.multimodalProjectorPath(for: localModelPath) != nil
        }
    }

    private func screenImageInputUnavailableReason(for provider: CompletionProviderKind) -> String {
        switch provider {
        case .mock:
            return "Mock provider does not accept screenshot images"
        case .gemini, .openAICompatible:
            return "Screenshot input is configured for this provider"
        case .huggingFaceRouter:
            return "Hugging Face Router screenshot input is enabled only for known vision model IDs"
        case .localLlama:
            return "Local screenshot input requires an mmproj*.gguf file next to the selected GGUF model"
        }
    }

    private func preferredGGUFFile(from files: [GGUFFile]) -> GGUFFile? {
        let modelFiles = files.filter { !$0.name.localizedCaseInsensitiveContains("mmproj") }
        return modelFiles.first { $0.name.localizedCaseInsensitiveContains("q4") }
            ?? files.first { $0.name.localizedCaseInsensitiveContains("Q4") }
            ?? modelFiles.first
            ?? files.first
    }

    private func preferredMMProjFile(from files: [GGUFFile]) -> GGUFFile? {
        let mmprojFiles = files.filter { $0.name.localizedCaseInsensitiveContains("mmproj") }
        return mmprojFiles.first { $0.name.localizedCaseInsensitiveContains("f16") }
            ?? mmprojFiles.first { $0.name.localizedCaseInsensitiveContains("bf16") }
            ?? mmprojFiles.first
    }
}

extension DateFormatter {
    static let tabAnywhereTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

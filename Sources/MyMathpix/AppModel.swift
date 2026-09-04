import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum CaptureTrigger {
        case interface
        case globalShortcut
    }
    let history: HistoryStore
    let diagnosticLog: DiagnosticLog

    @Published var selectedID: UUID?
    @Published var isProcessing = false
    @Published var statusMessage = "Ready"
    @Published var errorMessage: String?
    @Published private(set) var hasToken: Bool
    @Published private(set) var usage: UsageSnapshot
    @Published var hotKeyConfiguration: HotKeyConfiguration
    @Published var launchAtLogin = false
    @Published private(set) var ticket01SafeSummary: String?

    private let recognitionService: any RecognitionService
    private let recognitionConfiguration: (any RecognitionConfiguration)?
    private let captureCoordinator: CaptureCoordinator
    private let ticket01Reporter: Ticket01AcceptanceReporter?
    private let hotKeyRegistrar: any HotKeyRegistering
    private let launchAtLoginController: any LaunchAtLoginControlling
    private var historyObservation: AnyCancellable?
    private var recognitionTask: Task<Void, Never>?
    private var slowTask: Task<Void, Never>?
    private var openMainWindow: (() -> Void)?
    private let defaults: UserDefaults

    init(
        recognitionService: (any RecognitionService)? = nil,
        recognitionConfiguration: (any RecognitionConfiguration)? = nil,
        captureCoordinator: CaptureCoordinator? = nil,
        history: HistoryStore? = nil,
        defaults: UserDefaults = .standard,
        hotKeyRegistrar: (any HotKeyRegistering)? = nil,
        launchAtLoginController: (any LaunchAtLoginControlling)? = nil,
        diagnosticLog: DiagnosticLog? = nil,
        ticket01Reporter: Ticket01AcceptanceReporter? = nil
    ) {
        let resolvedRecognitionService: any RecognitionService
        let resolvedRecognitionConfiguration: (any RecognitionConfiguration)?
        if let recognitionService {
            resolvedRecognitionService = recognitionService
            resolvedRecognitionConfiguration = recognitionConfiguration
        } else {
            let liveRecognitionService = LiveRecognitionService()
            resolvedRecognitionService = liveRecognitionService
            resolvedRecognitionConfiguration = recognitionConfiguration ?? liveRecognitionService
        }
        let history = history ?? HistoryStore()
        self.recognitionService = resolvedRecognitionService
        self.recognitionConfiguration = resolvedRecognitionConfiguration
        self.captureCoordinator = captureCoordinator ?? CaptureCoordinator()
        self.history = history
        self.defaults = defaults
        self.hotKeyRegistrar = hotKeyRegistrar ?? HotKeyManager()
        self.launchAtLoginController = launchAtLoginController ?? SystemLaunchAtLoginController()
        self.diagnosticLog = diagnosticLog ?? DiagnosticLog()
        self.ticket01Reporter = ticket01Reporter
        hasToken = resolvedRecognitionConfiguration?.isConfigured ?? true
        usage = Self.loadUsage(defaults: defaults)
        hotKeyConfiguration = Self.loadHotKey(defaults: defaults)
        launchAtLogin = self.launchAtLoginController.isEnabled
        selectedID = history.items.first?.id
        historyObservation = history.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        try? self.diagnosticLog.record(.appLaunched)
        do {
            try self.hotKeyRegistrar.register(hotKeyConfiguration) {
                [weak self] in self?.startCapture(trigger: .globalShortcut)
            }
        } catch {
            try? self.diagnosticLog.record(.shortcutConflict)
            errorMessage = error.localizedDescription
        }
    }

    var selectedItem: HistoryItem? {
        history.item(id: selectedID)
    }

    func startCapture(trigger: CaptureTrigger = .interface) {
        guard !captureCoordinator.isActive else {
            errorMessage = AppError.captureInProgress.localizedDescription
            return
        }
        guard !isProcessing else {
            ticket01Reporter?.markSecondCaptureBlocked()
            errorMessage = "Wait for the current recognition to finish before capturing another snippet."
            return
        }
        guard hasToken else {
            errorMessage = AppError.missingToken.localizedDescription
            showMainWindow()
            return
        }
        statusMessage = "Select a screen region — Esc cancels"
        ticket01Reporter?.markCaptureRequested(
            triggeredByGlobalShortcut: trigger == .globalShortcut
        )
        let began = captureCoordinator.begin { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let snippet):
                self.ticket01Reporter?.markCaptureCompleted(
                    snippet: snippet,
                    overlayDismissed: !self.captureCoordinator.isActive
                )
                self.startRecognition(uploadPayload: snippet.uploadPayload, mode: .fast)
            case .failure(let error) where error is CancellationError:
                self.statusMessage = "Ready"
                try? self.diagnosticLog.record(.captureCancelled)
                self.ticket01Reporter?.markCancelled(recentHistoryCount: self.history.items.count)
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.statusMessage = "Capture failed"
                try? self.diagnosticLog.record(.captureFailed)
                self.ticket01Reporter?.markFailure(
                    code: (error as? AppError)?.safeDiagnosticCode ?? "capture_error",
                    recentHistoryCount: self.history.items.count
                )
                self.showMainWindow()
            }
        }
        if began {
            try? diagnosticLog.record(.captureStarted)
            ticket01Reporter?.markSelecting()
        }
    }

    func retryHighQuality() {
        guard let item = selectedItem, let data = history.imageData(for: item) else { return }
        if !item.markdown.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Replace the current edits?"
            alert.informativeText = "High Quality Retry will replace the current source with a new Datalab result."
            alert.addButton(withTitle: "Retry and Replace")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        startRecognition(uploadPayload: UploadPayload(pngData: data), mode: .balanced, existingID: item.id)
    }

    func retryFailed() {
        guard let item = selectedItem, let data = history.imageData(for: item) else { return }
        startRecognition(uploadPayload: UploadPayload(pngData: data), mode: item.mode, existingID: item.id)
    }

    func updateMarkdown(_ markdown: String) {
        guard var item = selectedItem else { return }
        item.markdown = markdown
        do { try history.update(item) }
        catch { errorMessage = "The edited result could not be saved: \(error.localizedDescription)" }
    }

    func deleteSelected() {
        guard let selectedID else { return }
        do {
            try history.delete(id: selectedID)
            self.selectedID = history.items.first?.id
            try? diagnosticLog.record(.historyItemDeleted)
        } catch {
            errorMessage = "The history item could not be deleted: \(error.localizedDescription)"
        }
    }

    func clearHistory() throws {
        try history.clear()
        selectedID = nil
        try? diagnosticLog.record(.historyCleared)
    }

    func saveToken(_ token: String) throws {
        guard let recognitionConfiguration else {
            throw AppError.service("Credential settings are unavailable in this isolated acceptance run.")
        }
        try recognitionConfiguration.saveToken(token)
        hasToken = recognitionConfiguration.isConfigured
    }

    func testAndSaveToken(_ token: String) async throws {
        guard let recognitionConfiguration else {
            throw AppError.service("Credential settings are unavailable in this isolated acceptance run.")
        }
        try await recognitionConfiguration.testAndSaveToken(token)
        hasToken = recognitionConfiguration.isConfigured
    }

    func saveHotKey(_ configuration: HotKeyConfiguration) throws {
        do {
            try hotKeyRegistrar.register(configuration) {
                [weak self] in self?.startCapture(trigger: .globalShortcut)
            }
        } catch {
            try? diagnosticLog.record(.shortcutConflict)
            throw error
        }
        hotKeyConfiguration = configuration
        let data = try JSONEncoder().encode(configuration)
        defaults.set(data, forKey: "hot-key")
        try? diagnosticLog.record(.shortcutUpdated)
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        try launchAtLoginController.setEnabled(enabled)
        launchAtLogin = launchAtLoginController.isEnabled
        try? diagnosticLog.record(launchAtLogin ? .launchAtLoginEnabled : .launchAtLoginDisabled)
    }

    func requestScreenCapturePermission() {
        captureCoordinator.requestPermission()
    }

    func installMainWindowOpener(_ opener: @escaping () -> Void) {
        openMainWindow = opener
    }

    func exportDiagnostics(to url: URL) throws {
        try diagnosticLog.exportData().write(to: url, options: .atomic)
    }

    func clearDiagnostics() throws {
        try diagnosticLog.clear()
    }

    func ticket01MarkRecognizingVisible() {
        ticket01Reporter?.markRecognizingVisible()
    }

    func ticket01MarkResultEditorVisible(
        originalSnippetVisible: Bool,
        canonicalMarkdown: String,
        isComplete: Bool
    ) {
        ticket01Reporter?.markResultEditorVisible(
            originalSnippetVisible: originalSnippetVisible,
            canonicalMarkdown: canonicalMarkdown,
            isComplete: isComplete
        )
    }

    func ticket01MarkPreviewVisible(
        renderedFormulaVisible: Bool,
        renderedTableVisible: Bool
    ) {
        ticket01Reporter?.markPreviewVisible(
            renderedFormulaVisible: renderedFormulaVisible,
            renderedTableVisible: renderedTableVisible
        )
    }

    func ticket01MarkRecentHistoryVisible() {
        ticket01Reporter?.markRecentHistoryVisible()
    }

    func showMainWindow() {
        let application = NSApplication.shared
        application.activate(ignoringOtherApps: true)
        if let window = application.windows.first(where: { $0.title == "MyMathpix" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openMainWindow?()
        }
    }

    private func startRecognition(uploadPayload: UploadPayload, mode: RecognitionMode, existingID: UUID? = nil) {
        guard !isProcessing, hasToken else {
            errorMessage = isProcessing ? "Another recognition is already running." : AppError.missingToken.localizedDescription
            return
        }
        do {
            let id: UUID
            if let existingID, var item = history.item(id: existingID) {
                item.status = .processing
                item.mode = mode
                item.errorMessage = nil
                try history.update(item)
                id = existingID
            } else {
                let item = try history.create(uploadPayload: uploadPayload)
                id = item.id
                selectedID = id
            }
            selectedID = id
            isProcessing = true
            statusMessage = mode == .fast ? "Recognizing…" : "Running high-quality recognition…"
            showMainWindow()
            ticket01Reporter?.markRecognitionStarted()
            try? diagnosticLog.record(.recognitionStarted, mode: mode)
            usage.requestCount += 1
            persistUsage()

            slowTask?.cancel()
            slowTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                self?.statusMessage = "Still processing — this is taking longer than usual"
            }

            recognitionTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let result = try await recognitionService.recognize(uploadPayload: uploadPayload, mode: mode)
                    complete(id: id, result: result, mode: mode)
                } catch is CancellationError {
                    fail(id: id, error: AppError.service("Recognition was cancelled."), mode: mode)
                } catch {
                    fail(id: id, error: error, mode: mode)
                }
            }
        } catch {
            errorMessage = "The snippet could not be saved: \(error.localizedDescription)"
        }
    }

    private func complete(id: UUID, result: DatalabResult, mode: RecognitionMode) {
        slowTask?.cancel()
        guard var item = history.item(id: id) else {
            isProcessing = false
            statusMessage = "Recognition result was discarded because its history item no longer exists"
            return
        }
        item.markdown = MarkdownNormalizer.normalize(result.markdown)
        item.html = result.html
        item.status = .complete
        item.mode = mode
        item.runtime = result.runtime
        item.costSummary = result.costSummary
        item.errorMessage = nil
        do { try history.update(item) }
        catch { errorMessage = "The recognition result could not be saved: \(error.localizedDescription)" }
        usage.successfulCount += 1
        usage.cumulativeCost += result.costValue ?? 0
        persistUsage()
        isProcessing = false
        statusMessage = "Recognition complete"
        try? diagnosticLog.record(.recognitionCompleted, mode: mode)
        if let ticket01Reporter {
            ticket01Reporter.markComplete(recentHistoryCount: history.items.count)
            ticket01SafeSummary = ticket01Reporter.safeSummary
        }
        if let latex = MarkdownNormalizer.pureFormula(in: item.markdown) {
            ClipboardService.copyMarkdown(latex)
            NSSound(named: "Glass")?.play()
        } else {
            showMainWindow()
        }
    }

    private func fail(id: UUID, error: Error, mode: RecognitionMode) {
        slowTask?.cancel()
        if var item = history.item(id: id) {
            item.status = .failed
            item.mode = mode
            item.errorMessage = error.localizedDescription
            try? history.update(item)
        }
        isProcessing = false
        statusMessage = "Recognition failed"
        errorMessage = error.localizedDescription
        try? diagnosticLog.record(.recognitionFailed, mode: mode)
        if let ticket01Reporter {
            ticket01Reporter.markRecognitionFailed(recentHistoryCount: history.items.count)
            ticket01SafeSummary = ticket01Reporter.safeSummary
        }
        showMainWindow()
    }

    private func persistUsage() {
        if let data = try? JSONEncoder().encode(usage) { defaults.set(data, forKey: "usage") }
    }

    private static func loadUsage(defaults: UserDefaults) -> UsageSnapshot {
        guard let data = defaults.data(forKey: "usage"),
              let value = try? JSONDecoder().decode(UsageSnapshot.self, from: data) else { return UsageSnapshot() }
        return value
    }

    private static func loadHotKey(defaults: UserDefaults) -> HotKeyConfiguration {
        guard let data = defaults.data(forKey: "hot-key"),
              let value = try? JSONDecoder().decode(HotKeyConfiguration.self, from: data) else { return HotKeyConfiguration() }
        return value
    }

}

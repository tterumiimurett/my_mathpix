import AppKit
import Combine
import Foundation
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    enum CaptureTrigger {
        case interface
        case globalShortcut
    }
    let history: HistoryStore
    let usageRecords: UsageRecordStore

    @Published var selectedID: UUID?
    @Published var isProcessing = false
    @Published var statusMessage = "Ready"
    @Published var errorMessage: String?
    @Published private(set) var hasToken: Bool
    @Published private(set) var needsCredentialRecovery = false
    @Published private(set) var usage: UsageSnapshot
    @Published var hotKeyConfiguration: HotKeyConfiguration
    @Published var launchAtLogin = false
    @Published private(set) var ticket01SafeSummary: String?

    private let recognitionService: any RecognitionService
    private let recognitionConfiguration: (any RecognitionConfiguration)?
    private let captureCoordinator: CaptureCoordinator
    private let ticket01Reporter: Ticket01AcceptanceReporter?
    private let hotKeyManager = HotKeyManager()
    private var historyObservation: AnyCancellable?
    private var recognitionTask: Task<Void, Never>?
    private var slowTask: Task<Void, Never>?
    private let defaults: UserDefaults
    private let appInteractionEnabled: Bool
    private let slowMessageDelay: Duration
    private var activeAttempt: ActiveAttempt?

    private struct ActiveAttempt {
        let id: UUID
        let historyItemID: UUID
        let mode: RecognitionMode
        let startedAt: TimeInterval
    }

    init(
        recognitionService: (any RecognitionService)? = nil,
        recognitionConfiguration: (any RecognitionConfiguration)? = nil,
        captureCoordinator: CaptureCoordinator? = nil,
        history: HistoryStore? = nil,
        usageRecords: UsageRecordStore? = nil,
        defaults: UserDefaults = .standard,
        ticket01Reporter: Ticket01AcceptanceReporter? = nil,
        appInteractionEnabled: Bool = true,
        slowMessageDelay: Duration = .seconds(5)
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
        self.usageRecords = usageRecords ?? UsageRecordStore()
        self.defaults = defaults
        self.ticket01Reporter = ticket01Reporter
        self.appInteractionEnabled = appInteractionEnabled
        self.slowMessageDelay = slowMessageDelay
        hasToken = resolvedRecognitionConfiguration?.isConfigured ?? true
        usage = Self.loadUsage(defaults: defaults)
        hotKeyConfiguration = Self.loadHotKey(defaults: defaults)
        launchAtLogin = SMAppService.mainApp.status == .enabled
        selectedID = history.items.first?.id
        historyObservation = history.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        if appInteractionEnabled {
            do {
                try hotKeyManager.register(hotKeyConfiguration) {
                    [weak self] in self?.startCapture(trigger: .globalShortcut)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
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
                self.recognizeCapturedSnippet(snippet.uploadPayload)
            case .failure(let error) where error is CancellationError:
                self.statusMessage = "Ready"
                self.ticket01Reporter?.markCancelled(recentHistoryCount: self.history.items.count)
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.statusMessage = "Capture failed"
                self.ticket01Reporter?.markFailure(
                    code: (error as? AppError)?.diagnosticCode.rawValue
                        ?? DiagnosticCode.captureError.rawValue,
                    recentHistoryCount: self.history.items.count
                )
                self.showMainWindow()
            }
        }
        if began {
            ticket01Reporter?.markSelecting()
        }
    }

    var retryNeedsConfirmation: Bool {
        !(selectedItem?.markdown.isEmpty ?? true)
    }

    func retryHighQuality(replacingCurrentContent: Bool = false) {
        guard let item = selectedItem, let data = history.imageData(for: item) else { return }
        guard item.markdown.isEmpty || replacingCurrentContent else { return }
        startRecognition(uploadPayload: UploadPayload(pngData: data), mode: .balanced, existingID: item.id)
    }

    func retryFailed(replacingCurrentContent: Bool = false) {
        guard let item = selectedItem, let data = history.imageData(for: item) else { return }
        guard item.markdown.isEmpty || replacingCurrentContent else { return }
        startRecognition(uploadPayload: UploadPayload(pngData: data), mode: item.mode, existingID: item.id)
    }

    func recognizeCapturedSnippet(_ uploadPayload: UploadPayload) {
        startRecognition(uploadPayload: uploadPayload, mode: .fast)
    }

    func cancelRecognition() {
        recognitionTask?.cancel()
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
        } catch {
            errorMessage = "The history item could not be deleted: \(error.localizedDescription)"
        }
    }

    func clearHistory() throws {
        try history.clear()
        selectedID = nil
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
        needsCredentialRecovery = false
    }

    func clearToken() throws {
        guard let recognitionConfiguration else {
            throw AppError.service("Credential settings are unavailable in this isolated acceptance run.")
        }
        try recognitionConfiguration.clearToken()
        hasToken = recognitionConfiguration.isConfigured
        needsCredentialRecovery = false
    }

    func saveHotKey(_ configuration: HotKeyConfiguration) throws {
        try hotKeyManager.register(configuration) {
            [weak self] in self?.startCapture(trigger: .globalShortcut)
        }
        hotKeyConfiguration = configuration
        let data = try JSONEncoder().encode(configuration)
        defaults.set(data, forKey: "hot-key")
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() }
        else { try SMAppService.mainApp.unregister() }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func requestScreenCapturePermission() {
        captureCoordinator.requestPermission()
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
        guard appInteractionEnabled else { return }
        NSApp.activate(ignoringOtherApps: true)
        let appDisplayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "MyMathpix"
        if let window = NSApp.windows.first(where: { $0.title == appDisplayName }) ?? NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func startRecognition(uploadPayload: UploadPayload, mode: RecognitionMode, existingID: UUID? = nil) {
        guard !isProcessing, hasToken else {
            errorMessage = isProcessing ? "Another recognition is already running." : AppError.missingToken.localizedDescription
            return
        }
        do {
            needsCredentialRecovery = false
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
            usage.requestCount += 1
            persistUsage()
            activeAttempt = ActiveAttempt(
                id: UUID(),
                historyItemID: id,
                mode: mode,
                startedAt: Date().timeIntervalSince1970
            )

            slowTask?.cancel()
            slowTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: self.slowMessageDelay)
                guard !Task.isCancelled else { return }
                self.statusMessage = "Still processing — this is taking longer than usual"
            }

            recognitionTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let result = try await recognitionService.recognize(uploadPayload: uploadPayload, mode: mode)
                    complete(id: id, result: result, mode: mode)
                } catch is CancellationError {
                    fail(
                        id: id,
                        error: AppError.service("Recognition was cancelled."),
                        mode: mode,
                        outcome: .cancelled
                    )
                } catch {
                    fail(id: id, error: error, mode: mode, outcome: .failed)
                }
            }
        } catch {
            errorMessage = "The snippet could not be saved: \(error.localizedDescription)"
        }
    }

    private func complete(id: UUID, result: DatalabResult, mode: RecognitionMode) {
        slowTask?.cancel()
        usage.successfulCount += 1
        needsCredentialRecovery = false
        usage.cumulativeCost += result.costValue ?? 0
        persistUsage()
        recordAttempt(
            historyItemID: id,
            outcome: .complete,
            serviceRuntime: result.runtime,
            costCents: result.costValue,
            costBreakdownJSON: result.costSummary,
            parseQualityScore: result.parseQualityScore,
            automaticRetryCount: result.automaticRetryCount,
            failureCode: nil
        )
        isProcessing = false
        recognitionTask = nil
        guard var item = history.item(id: id) else {
            statusMessage = "Recognition result was discarded because its history item no longer exists"
            return
        }
        item.markdown = MarkdownNormalizer.normalize(result.markdown)
        item.html = result.html
        item.status = .complete
        item.mode = mode
        item.errorMessage = nil
        do { try history.update(item) }
        catch { errorMessage = "The recognition result could not be saved: \(error.localizedDescription)" }
        statusMessage = "Recognition complete"
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

    private func fail(
        id: UUID,
        error: Error,
        mode: RecognitionMode,
        outcome: UsageRecordOutcome
    ) {
        slowTask?.cancel()
        if var item = history.item(id: id) {
            item.status = .failed
            item.mode = mode
            item.errorMessage = error.localizedDescription
            try? history.update(item)
        }
        isProcessing = false
        recognitionTask = nil
        statusMessage = "Recognition failed"
        errorMessage = error.localizedDescription
        needsCredentialRecovery = (error as? AppError)?.diagnosticCode == .invalidCredentials
        recordAttempt(
            historyItemID: id,
            outcome: outcome,
            serviceRuntime: nil,
            costCents: nil,
            parseQualityScore: nil,
            automaticRetryCount: nil,
            failureCode: (error as? AppError)?.diagnosticCode ?? .recognitionFailure
        )
        if let ticket01Reporter {
            ticket01Reporter.markRecognitionFailed(recentHistoryCount: history.items.count)
            ticket01SafeSummary = ticket01Reporter.safeSummary
        }
        showMainWindow()
    }

    private func persistUsage() {
        if let data = try? JSONEncoder().encode(usage) { defaults.set(data, forKey: "usage") }
    }

    private func recordAttempt(
        historyItemID: UUID,
        outcome: UsageRecordOutcome,
        serviceRuntime: Double?,
        costCents: Double?,
        costBreakdownJSON: String? = nil,
        parseQualityScore: Double?,
        automaticRetryCount: Int?,
        failureCode: DiagnosticCode?
    ) {
        guard let attempt = activeAttempt,
              attempt.historyItemID == historyItemID else { return }
        let finishedAt = Date().timeIntervalSince1970
        do {
            try usageRecords.record(
                UsageRecord(
                    id: attempt.id,
                    historyItemID: attempt.historyItemID,
                    startedAt: attempt.startedAt,
                    finishedAt: finishedAt,
                    mode: attempt.mode,
                    outcome: outcome,
                    elapsedSeconds: max(0, finishedAt - attempt.startedAt),
                    serviceRuntimeSeconds: serviceRuntime,
                    costCents: costCents,
                    costBreakdownJSON: costBreakdownJSON,
                    parseQualityScore: parseQualityScore,
                    automaticRetryCount: automaticRetryCount,
                    failureCode: failureCode
                )
            )
        } catch {
            errorMessage = "The Usage Record could not be saved."
        }
        activeAttempt = nil
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

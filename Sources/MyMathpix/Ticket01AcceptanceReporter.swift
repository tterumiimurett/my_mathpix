import AppKit
import Foundation

@MainActor
final class Ticket01AcceptanceReporter {
    struct Evidence: Codable, Equatable, Sendable {
        var schema = 4
        var acceptanceRunID = ""
        var processID = 0
        var permissionPreflightGranted: Bool?
        var permissionRequestAttempted = false
        var permissionRequestGranted: Bool?
        var phase = "launched"
        var captureTriggeredByGlobalShortcut = false
        var captureCompleted = false
        var overlayDismissed = false
        var recognizingWasVisible = false
        var secondCaptureBlocked = false
        var submitCount = 0
        var pollCount = 0
        var pngValid = false
        var fieldsApproved = false
        var fixtureValid = false
        var guardBandAbsent = false
        var resultComplete = false
        var pngPixelWidth = 0
        var pngPixelHeight = 0
        var expectedPixelWidth = 0
        var expectedPixelHeight = 0
        var selectionPointWidth = 0.0
        var selectionPointHeight = 0.0
        var selectedDisplayScale = 0.0
        var selectedDisplayWasSecondary = false
        var pixelGeometryPreserved = false
        var recentHistoryCount = 0
        var resultEditorVisible = false
        var originalSnippetVisible = false
        var canonicalMarkdownVisible = false
        var canonicalMarkdownMatchesFixture = false
        var previewVisible = false
        var renderedFormulaVisible = false
        var renderedTableVisible = false
        var recentHistoryVisible = false
        var failureCode: String?
        var lastFailureCode: String?
        var recoveryProbeStarted = false
        var activeDisplayCount = 0
        var distinctDisplayScaleCount = 0
    }

    private(set) var evidence = Evidence()
    private let evidenceURL: URL
    private let encoder: JSONEncoder

    var safeSummary: String {
        "Ticket 01 · attempts \(evidence.submitCount) · polls \(evidence.pollCount) · Recent History \(evidence.recentHistoryCount)"
    }

    init(runID: UUID) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MyMathpix/Ticket01Acceptance", isDirectory: true)
        evidenceURL = base.appendingPathComponent("evidence.json")
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        evidence.acceptanceRunID = runID.uuidString.lowercased()
        evidence.processID = Int(ProcessInfo.processInfo.processIdentifier)
        evidence.activeDisplayCount = NSScreen.screens.count
        evidence.distinctDisplayScaleCount = Set(NSScreen.screens.map(\.backingScaleFactor)).count
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        persist()
    }

    func markCaptureRequested(triggeredByGlobalShortcut: Bool) {
        evidence.captureTriggeredByGlobalShortcut = evidence.captureTriggeredByGlobalShortcut
            || triggeredByGlobalShortcut
        persist()
    }

    func markPermissionObservation(_ observation: ScreenCapturePermissionObservation) {
        evidence = Self.permissionObservationEvidence(
            starting: evidence,
            preflightGranted: observation.preflightGranted,
            requestAttempted: observation.requestAttempted,
            requestGranted: observation.requestGranted
        )
        persist()
    }

    nonisolated static func permissionObservationEvidence(
        starting: Evidence,
        preflightGranted: Bool,
        requestAttempted: Bool,
        requestGranted: Bool?
    ) -> Evidence {
        var evidence = starting
        evidence.permissionPreflightGranted = preflightGranted
        evidence.permissionRequestAttempted = requestAttempted
        evidence.permissionRequestGranted = requestGranted
        return evidence
    }

    func markSelecting() {
        evidence = Self.selectionStartedEvidence(starting: evidence)
        persist()
    }

    nonisolated static func selectionStartedEvidence(starting: Evidence) -> Evidence {
        var evidence = starting
        if evidence.phase == "failed" || evidence.phase == "cancelled" {
            evidence.recoveryProbeStarted = true
        }
        if evidence.lastFailureCode == nil {
            evidence.lastFailureCode = evidence.failureCode
        }
        evidence.failureCode = nil
        evidence.phase = "selecting"
        return evidence
    }

    func markCaptureCompleted(snippet: CapturedSnippet, overlayDismissed: Bool) {
        evidence.captureCompleted = true
        evidence.overlayDismissed = overlayDismissed
        evidence.phase = "captured"
        evidence.expectedPixelWidth = snippet.geometry.expectedPixelWidth
        evidence.expectedPixelHeight = snippet.geometry.expectedPixelHeight
        evidence.selectionPointWidth = snippet.geometry.selectionSizeInPoints.width
        evidence.selectionPointHeight = snippet.geometry.selectionSizeInPoints.height
        evidence.selectedDisplayScale = snippet.geometry.displayScale
        evidence.selectedDisplayWasSecondary = snippet.geometry.selectedDisplayWasSecondary
        persist()
    }

    func markRecognitionStarted() {
        evidence.phase = "recognizing"
        persist()
    }

    func markRecognizingVisible() {
        guard evidence.phase == "recognizing" else { return }
        evidence.recognizingWasVisible = true
        persist()
    }

    func markSecondCaptureBlocked() {
        evidence.secondCaptureBlocked = true
        persist()
    }

    func markComplete(recentHistoryCount: Int) {
        applyMockSnapshot()
        evidence.phase = "complete"
        evidence.failureCode = nil
        evidence.recentHistoryCount = recentHistoryCount
        evidence.resultEditorVisible = false
        evidence.originalSnippetVisible = false
        evidence.canonicalMarkdownVisible = false
        evidence.canonicalMarkdownMatchesFixture = false
        evidence.previewVisible = false
        evidence.renderedFormulaVisible = false
        evidence.renderedTableVisible = false
        evidence.recentHistoryVisible = false
        persist()
    }

    func markRecognitionFailed(recentHistoryCount: Int) {
        evidence = Self.recognitionFailureEvidence(
            starting: evidence,
            snapshot: Ticket01MockURLProtocol.snapshot(),
            recentHistoryCount: recentHistoryCount
        )
        persist()
    }

    nonisolated static func recognitionFailureEvidence(
        starting: Evidence,
        snapshot: Ticket01MockURLProtocol.Snapshot,
        recentHistoryCount: Int
    ) -> Evidence {
        var evidence = starting
        apply(snapshot: snapshot, to: &evidence)
        evidence.phase = "failed"
        evidence.failureCode = "recognition_failed"
        evidence.lastFailureCode = "recognition_failed"
        evidence.recentHistoryCount = recentHistoryCount
        return evidence
    }

    func markResultEditorVisible(
        originalSnippetVisible: Bool,
        canonicalMarkdown: String,
        isComplete: Bool
    ) {
        guard evidence.phase == "complete" else { return }
        evidence.resultEditorVisible = true
        evidence.originalSnippetVisible = originalSnippetVisible
        evidence.canonicalMarkdownVisible = true
        evidence.canonicalMarkdownMatchesFixture = isComplete
            && canonicalMarkdown == Ticket01MockContract.expectedCanonicalMarkdown
        persist()
    }

    func markPreviewVisible(
        renderedFormulaVisible: Bool,
        renderedTableVisible: Bool
    ) {
        guard evidence.phase == "complete",
              renderedFormulaVisible,
              renderedTableVisible else { return }
        evidence.previewVisible = true
        evidence.renderedFormulaVisible = true
        evidence.renderedTableVisible = true
        persist()
    }

    func markRecentHistoryVisible() {
        guard evidence.phase == "complete" else { return }
        evidence.recentHistoryVisible = true
        persist()
    }

    func markCancelled(recentHistoryCount: Int) {
        evidence.phase = "cancelled"
        evidence.failureCode = nil
        evidence.recentHistoryCount = recentHistoryCount
        persist()
    }

    func markFailure(code: String, recentHistoryCount: Int) {
        evidence.phase = "failed"
        evidence.failureCode = code
        evidence.lastFailureCode = code
        evidence.recentHistoryCount = recentHistoryCount
        persist()
    }

    private func applyMockSnapshot() {
        let snapshot = Ticket01MockURLProtocol.snapshot()
        Self.apply(snapshot: snapshot, to: &evidence)
    }

    nonisolated private static func apply(
        snapshot: Ticket01MockURLProtocol.Snapshot,
        to evidence: inout Evidence
    ) {
        evidence.submitCount = snapshot.submitCount
        evidence.pollCount = snapshot.pollCount
        evidence.pngValid = snapshot.pngWasValid
        evidence.fieldsApproved = snapshot.fieldsWereApproved
        evidence.fixtureValid = snapshot.fixtureWasValid
        evidence.guardBandAbsent = snapshot.guardBandWasAbsent
        evidence.resultComplete = snapshot.resultWasReturned
        evidence.pngPixelWidth = snapshot.pixelWidth
        evidence.pngPixelHeight = snapshot.pixelHeight
        evidence.pixelGeometryPreserved = snapshot.pixelWidth == evidence.expectedPixelWidth
            && snapshot.pixelHeight == evidence.expectedPixelHeight
    }

    private func persist() {
        guard let data = try? encoder.encode(evidence) else { return }
        try? data.write(to: evidenceURL, options: .atomic)
    }
}

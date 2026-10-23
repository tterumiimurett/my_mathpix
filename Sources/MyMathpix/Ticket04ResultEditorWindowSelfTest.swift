import AppKit
import CoreGraphics
import Foundation
import WebKit

/// Runs in the real SwiftUI window of the signed App. Only capture pixels and the
/// external recognition service are synthetic; the Result Editor is not mocked.
@MainActor
enum Ticket04ResultEditorWindowSelfTest {
    private static var started = false
    private static let defaultsName = "com.byterumi.mymathpix.ticket04.window.\(UUID().uuidString)"
    private static let diagnosticsRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("Ticket04WindowTest-\(UUID().uuidString)", isDirectory: true)

    private static let recognitionService = WindowRecognitionService()

    static func makeModel() -> AppModel {
        let defaults = UserDefaults(suiteName: defaultsName)!
        return AppModel(
            recognitionService: recognitionService,
            history: HistoryStore(inMemory: true),
            usageRecords: UsageRecordStore(inMemory: true),
            defaults: defaults,
            hotKeyRegistrar: WindowTestHotKeyRegistrar(),
            diagnosticLog: DiagnosticLog(rootURL: diagnosticsRoot)
        )
    }

    static func run(model: AppModel) async {
        guard !started else { return }
        started = true
        // Let SwiftUI finish its initial window restoration before moving it.
        try? await Task.sleep(for: .milliseconds(400))
        guard let window = NSApp.windows.first(where: { $0.title == "MyMathpix" }),
              !NSScreen.screens.isEmpty,
              let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
              ) else {
            finish(false, scenario: "window-unavailable")
            return
        }
        guard !window.isRestorable, window.frameAutosaveName.isEmpty else {
            finish(false, scenario: "disposable-window-state")
            return
        }
        if let pixels = bitmap.bitmapData {
            pixels.initialize(repeating: 0, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
        }
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            finish(false, scenario: "fixture-unavailable")
            return
        }
        for screen in NSScreen.screens {
            let scenario = "empty-panel-overlap"
            try? model.clearHistory()
            model.errorMessage = AppError.selectionTooSmall.localizedDescription
            model.showResultEditor()
            try? await Task.sleep(for: .milliseconds(200))
            model.errorMessage = nil
            try? await Task.sleep(for: .milliseconds(200))
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                finish(false, scenario: "display-unavailable")
                return
            }
            // Recreate the default large window, even after an earlier test or
            // launch persisted a smaller frame. This keeps the regression red-capable.
            window.setContentSize(NSSize(width: 1180, height: 760))
            window.center()
            NSApp.windows.filter { $0.frame.width >= 200 }.forEach { $0.orderOut(nil) }
            recognitionService.defersCompletion = true
            model.recognizeCapturedSnippet(CapturedSnippet(
                uploadPayload: UploadPayload(pngData: png),
                geometry: CaptureGeometry(
                    expectedPixelWidth: 32, expectedPixelHeight: 32,
                    selectionSizeInPoints: CGSize(width: 32, height: 32),
                    displayScale: 1, selectedDisplayWasSecondary: number.uint32Value != CGMainDisplayID()
                ),
                displayID: number.uint32Value
            ))
            guard model.isProcessing, !window.isVisible else {
                finish(false, scenario: "hidden-during-recognition")
                return
            }
            // Deliver the external result while the real hidden WK view's initial
            // document is still loading, rather than assuming a fixed mock delay.
            var pendingDocumentObserved = false
            for _ in 0..<200 {
                if let panel = NSApp.windows.first(where: {
                    $0.identifier?.rawValue == "com.byterumi.mymathpix.compact-result"
                }), let content = panel.contentView, let webView = findWebView(in: content),
                   webView.isLoading, recognitionService.complete() {
                    pendingDocumentObserved = true
                    break
                }
                try? await Task.sleep(for: .milliseconds(1))
            }
            print("TICKET04_PENDING_DOCUMENT_OBSERVED pending=\(pendingDocumentObserved)")
            guard pendingDocumentObserved else {
                finish(false, scenario: "missing-pending-document")
                return
            }
            await waitForRecognitionAndWindowSettlement(model: model)
            // The capture result is a compact surface, not the explicit main workspace.
            // Inspect settled visible AppKit windows rather than a presenter method call.
            let resultWindows = NSApp.windows.filter { $0.isVisible && $0.frame.width >= 200 }
            let resultWindow = resultWindows.first
            let compact = resultWindows.count == 1
                && resultWindow.map { $0.frame.width <= 480 && $0.frame.height <= min(720, screen.visibleFrame.height) } == true
            let floating = resultWindow.map { $0.level.rawValue >= NSWindow.Level.floating.rawValue } == true
            let supportsOtherSpaces = resultWindow.map {
                $0.collectionBehavior.contains(.canJoinAllSpaces)
                    && $0.collectionBehavior.contains(.fullScreenAuxiliary)
                    && !$0.canBecomeMain
            } == true
            guard compact, floating, supportsOtherSpaces, !window.isVisible else {
                print("TICKET04_COMPACT_OBSERVATION visible-windows=\(resultWindows.count) main-visible=\(window.isVisible) width=\(resultWindow?.frame.width ?? 0) height=\(resultWindow?.frame.height ?? 0) floating=\(floating)")
                finish(false, scenario: "compact-result-role")
                return
            }
            let frame = resultWindow!.frame
            let visible = screen.visibleFrame
            let placed = abs(frame.minX - visible.minX - 16) <= 1
                && abs(frame.maxY - visible.maxY + 16) <= 1
            let onDisplay = resultWindow!.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            guard !model.isProcessing,
                  model.selectedItem?.status == .complete,
                  resultWindow!.isVisible, !resultWindow!.isMiniaturized,
                  onDisplay == number, placed else {
                print("TICKET04_WINDOW_OBSERVATION visible=\(window.isVisible) minimized=\(window.isMiniaturized) display-matches=\(onDisplay == number) inset-matches=\(placed)")
                print("TICKET04_WINDOW_GEOMETRY x=\(frame.minX) top=\(frame.maxY) width=\(frame.width) height=\(frame.height) expected-x=\(visible.minX + 16) expected-top=\(visible.maxY - 16)")
                finish(false, scenario: "completion-placement")
                return
            }
            guard await previewContainsFixture(in: resultWindow!, scenario: scenario) else {
                finish(false, scenario: "\(scenario)-preview-dom")
                return
            }
            model.showMainWindow()
            try? await Task.sleep(for: .milliseconds(250))
            guard window.isVisible, window.frame.width >= 920, !resultWindow!.isVisible else {
                print("TICKET04_WORKSPACE_OBSERVATION main-visible=\(window.isVisible) main-width=\(window.frame.width) result-visible=\(resultWindow!.isVisible)")
                finish(false, scenario: "explicit-workspace-role")
                return
            }
            print("TICKET04_WINDOW_ROLES_OBSERVED compact-width=\(frame.width) compact-height=\(frame.height) floating=\(floating) other-spaces=\(supportsOtherSpaces) main-width=\(window.frame.width)")
            let selectedBeforeMenu = model.selectedID
            model.showResultEditor()
            try? await Task.sleep(for: .milliseconds(250))
            let reopened = NSApp.windows.filter { $0.isVisible && $0.frame.width >= 200 }
            guard !window.isVisible, reopened.count == 1, reopened.first === resultWindow,
                  model.selectedID == selectedBeforeMenu else {
                print("TICKET04_RESULT_REOPEN_OBSERVATION main-visible=\(window.isVisible) same-result=\(reopened.first === resultWindow) selected-preserved=\(model.selectedID == selectedBeforeMenu)")
                finish(false, scenario: "result-command-role")
                return
            }
            for _ in 0..<2 {
                postClick(to: resultWindow!)
                try? await Task.sleep(for: .milliseconds(150))
                guard resultWindow!.isVisible else {
                    finish(false, scenario: "inside-click-dismissed-result")
                    return
                }
                postClick(to: window)
                try? await Task.sleep(for: .milliseconds(150))
                guard !resultWindow!.isVisible, !window.isVisible,
                      model.selectedID == selectedBeforeMenu else {
                    finish(false, scenario: "outside-click-result-dismissal")
                    return
                }
                model.showResultEditor()
                try? await Task.sleep(for: .milliseconds(150))
                guard resultWindow!.isVisible, model.selectedID == selectedBeforeMenu else {
                    finish(false, scenario: "reopen-after-outside-click")
                    return
                }
            }
            print("TICKET04_OUTSIDE_CLICK_OK inside-retained=true outside-hidden=true reopen-preserved=true")
        }
        // A recoverable recognition error must attach to the compact surface,
        // without bringing its hidden history/settings workspace back on screen.
        recognitionService.defersCompletion = false
        recognitionService.failure = .invalidCredentials
        NSApp.windows.filter { $0.frame.width >= 200 }.forEach { $0.orderOut(nil) }
        model.recognizeCapturedSnippet(CapturedSnippet(
            uploadPayload: UploadPayload(pngData: png),
            geometry: CaptureGeometry(expectedPixelWidth: 32, expectedPixelHeight: 32,
                selectionSizeInPoints: CGSize(width: 32, height: 32), displayScale: 1,
                selectedDisplayWasSecondary: false),
            displayID: CGMainDisplayID()
        ))
        await waitForRecognitionAndWindowSettlement(model: model)
        let failedResult = NSApp.windows.first {
            $0.identifier?.rawValue == "com.byterumi.mymathpix.compact-result"
        }
        let recoverySheetVisible = failedResult?.attachedSheet?.isVisible == true
        print("TICKET04_FAILURE_WINDOW_OBSERVED main-visible=\(window.isVisible) result-visible=\(failedResult?.isVisible == true) result-sheet=\(recoverySheetVisible) credential-recovery=\(model.needsCredentialRecovery)")
        guard !window.isVisible, failedResult?.isVisible == true,
              model.selectedItem?.status == .failed, model.needsCredentialRecovery,
              recoverySheetVisible else {
            finish(false, scenario: "compact-error-recovery")
            return
        }
        finish(true, scenario: "all-connected-displays")
    }

    private static func postClick(to window: NSWindow) {
        // Exercise the real local event dispatch without activating controls or
        // requiring input access outside this disposable test application.
        if let event = NSEvent.mouseEvent(with: .otherMouseDown,
            location: NSPoint(x: 10, y: 10), modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 0) {
            NSApp.postEvent(event, atStart: false)
        }
    }

    private static func findWebView(in view: NSView) -> WKWebView? {
        if let webView = view as? WKWebView { return webView }
        for child in view.subviews {
            if let found = findWebView(in: child) { return found }
        }
        return nil
    }

    private static func previewContainsFixture(in window: NSWindow, scenario: String) async -> Bool {
        guard let content = window.contentView, let webView = findWebView(in: content) else {
            print("TICKET04_PREVIEW_DOM_OBSERVED scenario=\(scenario) webview=false")
            return false
        }
        var counts: [NSNumber] = []
        for _ in 0..<100 {
            counts = await withCheckedContinuation { continuation in
                webView.evaluateJavaScript("[document.body?.innerText.includes('TICKET 01 SAFE FIXTURE') === true, document.querySelectorAll('.katex').length, document.querySelectorAll('table').length]") { value, _ in
                    continuation.resume(returning: value as? [NSNumber] ?? [])
                }
            }
            if counts.count == 3, counts[0].boolValue, counts[1].intValue > 0, counts[2].intValue > 0 {
                print("TICKET04_PREVIEW_DOM_OBSERVED scenario=\(scenario) fixture=true formulas=\(counts[1]) tables=\(counts[2])")
                return true
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        print("TICKET04_PREVIEW_DOM_OBSERVED scenario=\(scenario) fixture=\(counts.first?.boolValue == true) formulas=\(counts.dropFirst().first?.intValue ?? 0) tables=\(counts.dropFirst(2).first?.intValue ?? 0) loading=\(webView.isLoading)")
        return false
    }

    private static func waitForRecognitionAndWindowSettlement(model: AppModel) async {
        for _ in 0..<100 {
            if !model.isProcessing { break }
            try? await Task.sleep(for: .milliseconds(20))
        }
        // Observe settled AppKit/SwiftUI state, not a presentation method call.
        try? await Task.sleep(for: .milliseconds(400))
    }

    private static func finish(_ passed: Bool, scenario: String) {
        UserDefaults.standard.removePersistentDomain(forName: defaultsName)
        try? FileManager.default.removeItem(at: diagnosticsRoot)
        print("TICKET04_RESULT_EDITOR_WINDOW_\(passed ? "OK" : "FAIL") \(scenario)")
        fflush(stdout)
        exit(passed ? 0 : 1)
    }
}

@MainActor
private final class WindowRecognitionService: RecognitionService {
    var failure: AppError?
    var defersCompletion = false
    private var completion: CheckedContinuation<Void, Never>?

    func complete() -> Bool {
        guard let completion else { return false }
        self.completion = nil
        completion.resume()
        return true
    }

    func recognize(uploadPayload: UploadPayload, mode: RecognitionMode) async throws -> DatalabResult {
        if defersCompletion {
            await withCheckedContinuation { completion = $0 }
        } else {
            try await Task.sleep(for: .milliseconds(200))
        }
        if let failure { throw failure }
        return DatalabResult(
            markdown: Ticket01MockContract.expectedCanonicalMarkdown, html: nil, runtime: nil,
            costSummary: nil, costValue: nil, parseQualityScore: nil,
            automaticRetryCount: 0
        )
    }
}

@MainActor
private final class WindowTestHotKeyRegistrar: HotKeyRegistering {
    func register(_ configuration: HotKeyConfiguration, action: @escaping () -> Void) throws {}
}

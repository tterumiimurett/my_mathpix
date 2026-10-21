import AppKit
import CoreGraphics
import Foundation

/// Runs in the real SwiftUI window of the signed App. Only capture pixels and the
/// external recognition service are synthetic; the Result Editor is not mocked.
@MainActor
enum Ticket04ResultEditorWindowSelfTest {
    private static var started = false
    private static let defaultsName = "com.byterumi.mymathpix.ticket04.window.\(UUID().uuidString)"
    private static let diagnosticsRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("Ticket04WindowTest-\(UUID().uuidString)", isDirectory: true)

    static func makeModel() -> AppModel {
        let defaults = UserDefaults(suiteName: defaultsName)!
        return AppModel(
            recognitionService: WindowRecognitionService(),
            history: HistoryStore(inMemory: true),
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
        if let pixels = bitmap.bitmapData {
            pixels.initialize(repeating: 0, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
        }
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            finish(false, scenario: "fixture-unavailable")
            return
        }
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                finish(false, scenario: "display-unavailable")
                return
            }
            // Recreate the default large window, even after an earlier test or
            // launch persisted a smaller frame. This keeps the regression red-capable.
            window.setContentSize(NSSize(width: 1180, height: 760))
            window.center()
            window.orderOut(nil)
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
            for _ in 0..<100 {
                if !model.isProcessing { break }
                try? await Task.sleep(for: .milliseconds(20))
            }
            // Observe settled AppKit/SwiftUI state, not a presentation method call.
            try? await Task.sleep(for: .milliseconds(400))
            let frame = window.frame
            let visible = screen.visibleFrame
            let placed = abs(frame.minX - visible.minX - 16) <= 1
                && abs(frame.maxY - visible.maxY + 16) <= 1
            let onDisplay = window.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            guard !model.isProcessing,
                  model.selectedItem?.status == .complete,
                  window.isVisible, !window.isMiniaturized,
                  onDisplay == number, placed else {
                print("TICKET04_WINDOW_OBSERVATION visible=\(window.isVisible) minimized=\(window.isMiniaturized) display-matches=\(onDisplay == number) inset-matches=\(placed)")
                print("TICKET04_WINDOW_GEOMETRY x=\(frame.minX) top=\(frame.maxY) width=\(frame.width) height=\(frame.height) expected-x=\(visible.minX + 16) expected-top=\(visible.maxY - 16)")
                finish(false, scenario: "completion-placement")
                return
            }
        }
        finish(true, scenario: "all-connected-displays")
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
    func recognize(uploadPayload: UploadPayload, mode: RecognitionMode) async throws -> DatalabResult {
        try await Task.sleep(for: .milliseconds(200))
        return DatalabResult(
            markdown: "Local window acceptance result", html: nil, runtime: nil,
            costSummary: nil, costValue: nil, parseQualityScore: nil
        )
    }
}

@MainActor
private final class WindowTestHotKeyRegistrar: HotKeyRegistering {
    func register(_ configuration: HotKeyConfiguration, action: @escaping () -> Void) throws {}
}

import AppKit
import CoreGraphics
import SwiftUI

@main
struct MyMathpixApp: App {
    @StateObject private var model: AppModel

    private var appDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "MyMathpix"
    }

    init() {
        if GoldenSetRunner.handles(CommandLine.arguments) {
            exit(GoldenSetRunner.runBlocking(arguments: CommandLine.arguments))
        }
        let launch = AppLaunchConfiguration.current(arguments: CommandLine.arguments)
        if launch.runsLocalTokenStoreSelfTest {
            let passed = Ticket01LocalTokenStoreSelfTest.run()
            print(passed ? "TICKET01_LOCAL_TOKEN_OK" : "TICKET01_LOCAL_TOKEN_FAIL")
            exit(passed ? 0 : 1)
        }
        if launch.runsTicket02RecognitionSelfTest {
            let passed = Ticket02RecognitionSelfTest.runBlocking()
            print(passed ? "TICKET02_RECOGNITION_OK" : "TICKET02_RECOGNITION_FAIL")
            exit(passed ? 0 : 1)
        }
        if launch.runsOverlayLifecycleSelfTest {
            let passed = Ticket01OverlayLifecycleSelfTest.run()
            print(passed ? "TICKET01_OVERLAY_LIFECYCLE_OK" : "TICKET01_OVERLAY_LIFECYCLE_FAIL")
            exit(passed ? 0 : 1)
        }
        if launch.runsResourceBundleSelfTest {
            let document = MarkdownRenderer.document(for: "$$x^2$$")
            let passed = AppResources.directoryURL != nil
                && document.contains(".katex")
                && document.contains("katex.render")
                && document.contains("data-tex")
            print(passed ? "TICKET01_RESOURCE_BUNDLE_OK" : "TICKET01_RESOURCE_BUNDLE_FAIL")
            exit(passed ? 0 : 1)
        }
        if launch.runsTicket01MockSelfTest {
            let passed = Ticket01MockRecognitionSelfTest.runBlocking()
            if passed {
                print("TICKET01_MOCK_PROTOCOL_OK submit=1 polls=multiple png=yes fields=yes fixture=yes guard=yes result=yes")
            }
            exit(passed ? 0 : 1)
        }
        if launch.runsTicket04DailyWorkflowSelfTest {
            exit(Ticket04DailyWorkflowSelfTest.run() ? 0 : 1)
        }
        if launch.runsTicket03SelfTest {
            exit(Ticket03SelfCheck.run() ? 0 : 1)
        }
        if let format = launch.ticket03PasteboardInspection {
            let passed = Ticket03PasteboardInspector.inspect(format)
            if passed {
                print("TICKET03_PASTEBOARD_OK format=\(format.rawValue) values=yes public_types=yes")
            }
            exit(passed ? 0 : 1)
        }
        if launch.runsSelfTest {
            exit(SelfCheck.run() ? 0 : 1)
        }
        if launch.reportsScreenPermissionState {
            print("TICKET01_SCREEN_PERMISSION granted=\(CGPreflightScreenCaptureAccess() ? "yes" : "no")")
            exit(0)
        }
        if launch.runsTicket04ResultEditorWindowSelfTest {
            _model = StateObject(wrappedValue: Ticket04ResultEditorWindowSelfTest.makeModel())
        } else if launch.runsTicket03Acceptance {
            let history = HistoryStore(inMemory: true)
            do {
                try Ticket03AcceptanceFixture.seed(history: history)
            } catch {
                fatalError("Ticket 03 acceptance fixture could not be prepared")
            }
            let defaults = UserDefaults(
                suiteName: "com.byterumi.mymathpix.ticket03.\(ProcessInfo.processInfo.processIdentifier)"
            )!
            let reporter = Ticket03AcceptanceReporter(runID: launch.ticket03AcceptanceRunID!)
            _model = StateObject(wrappedValue: AppModel(
                recognitionService: Ticket03AcceptanceRecognitionService(),
                history: history,
                usageRecords: UsageRecordStore(inMemory: true),
                defaults: defaults,
                diagnosticLog: DiagnosticLog(rootURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("Ticket03Diagnostics-\(launch.ticket03AcceptanceRunID!.uuidString)", isDirectory: true)),
                ticket03Reporter: reporter,
                registersHotKey: false
            ))
        } else if launch.runsTicket01Acceptance {
            let defaults = UserDefaults(suiteName: "com.byterumi.mymathpix.ticket01.\(ProcessInfo.processInfo.processIdentifier)")!
            let reporter = Ticket01AcceptanceReporter(runID: launch.acceptanceRunID!)
            let resultEditorWindowPresenter = AppKitResultEditorWindowPresenter(
                presentationObservation: { observation in
                    reporter.markResultEditorWindowPresented(observation)
                }
            )
            let permissionObservation: (ScreenCapturePermissionObservation) -> Void = { observation in
                reporter.markPermissionObservation(observation)
            }
            let captureCoordinator: CaptureCoordinator
            switch launch.ticket01Scenario {
            case .permissionNotDetermined, .permissionDenied, .permissionRevoked:
                captureCoordinator = CaptureCoordinator(permissionObservation: permissionObservation)
            case .captureAPIFailure:
                captureCoordinator = CaptureCoordinator(
                    imageCapturer: Ticket01FailingImageCapturer(failure: .captureAPI),
                    permissionObservation: permissionObservation
                )
            case .displayDisappearance:
                captureCoordinator = CaptureCoordinator(
                    imageCapturer: Ticket01FailingImageCapturer(failure: .displayUnavailable),
                    permissionObservation: permissionObservation
                )
            case .cancellation, .tinySelection, nil:
                captureCoordinator = CaptureCoordinator(permissionObservation: permissionObservation)
            }
            _model = StateObject(wrappedValue: AppModel(
                recognitionService: Ticket01RecognitionService(),
                captureCoordinator: captureCoordinator,
                history: HistoryStore(inMemory: true),
                usageRecords: UsageRecordStore(inMemory: true),
                defaults: defaults,
                ticket01Reporter: reporter,
                resultEditorWindowPresenter: resultEditorWindowPresenter
            ))
        } else {
            _model = StateObject(wrappedValue: AppModel())
        }
    }

    var body: some Scene {
        WindowGroup(appDisplayName, id: "main") {
            Group {
                if AppLaunchConfiguration.current(arguments: CommandLine.arguments).runsTicket03Acceptance {
                    if let item = model.selectedItem {
                        ResultEditorView(item: item)
                            .id(item.id)
                            .environmentObject(model)
                            .frame(minWidth: 400, minHeight: 520)
                    }
                } else {
                    ContentView()
                        .environmentObject(model)
                        .frame(minWidth: 920, minHeight: 520)
                }
            }
            .background(MainWindowRegistrationView { window in
                model.registerMainWindow(window)
            })
            .task {
                if CommandLine.arguments.contains("--ticket04-result-editor-window-self-test") {
                    await Ticket04ResultEditorWindowSelfTest.run(model: model)
                }
            }
        }
        .defaultSize(
            width: AppLaunchConfiguration.current(arguments: CommandLine.arguments).runsTicket03Acceptance ? 470 : 1180,
            height: AppLaunchConfiguration.current(arguments: CommandLine.arguments).runsTicket03Acceptance ? 700 : 760
        )

        MenuBarExtra(appDisplayName, systemImage: "function") {
            MenuBarContent()
                .environmentObject(model)
        }

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 540, height: 560)
        }
    }
}

private struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button("Capture Snippet  \(model.hotKeyConfiguration.displayName)") {
            model.startCapture()
        }
        .disabled(model.isProcessing)
        Button("Show MyMathpix") { showMainWindow() }
        Divider()
        Text(model.statusMessage)
        Divider()
        SettingsLink { Text("Settings…") }
        Button("Quit MyMathpix") { NSApplication.shared.terminate(nil) }
            .onAppear {
                model.installMainWindowOpener { openWindow(id: "main") }
            }
    }

    private func showMainWindow() {
        openWindow(id: "main")
        DispatchQueue.main.async { model.showMainWindow() }
    }
}

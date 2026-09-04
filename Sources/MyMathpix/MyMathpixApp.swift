import AppKit
import SwiftUI

@main
struct MyMathpixApp: App {
    @StateObject private var model: AppModel

    init() {
        let launch = AppLaunchConfiguration(arguments: CommandLine.arguments)
        if launch.runsLocalTokenStoreSelfTest {
            let passed = Ticket01LocalTokenStoreSelfTest.run()
            print(passed ? "TICKET01_LOCAL_TOKEN_OK" : "TICKET01_LOCAL_TOKEN_FAIL")
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
                print("TICKET01_MOCK_PROTOCOL_OK submit=1 polls=5 png=yes fields=yes fixture=yes guard=yes result=yes")
            }
            exit(passed ? 0 : 1)
        }
        if launch.runsSelfTest {
            exit(SelfCheck.run() ? 0 : 1)
        }
        if launch.runsTicket01Acceptance {
            let defaults = UserDefaults(suiteName: "com.byterumi.mymathpix.ticket01.\(ProcessInfo.processInfo.processIdentifier)")!
            let reporter = Ticket01AcceptanceReporter()
            let captureCoordinator: CaptureCoordinator
            switch launch.ticket01Scenario {
            case .permissionNotDetermined, .permissionDenied, .permissionRevoked:
                captureCoordinator = CaptureCoordinator(
                    permission: Ticket01FixedScreenCapturePermission(hasAccess: false, requestResult: false)
                )
            case .captureAPIFailure:
                captureCoordinator = CaptureCoordinator(
                    imageCapturer: Ticket01FailingImageCapturer(failure: .captureAPI)
                )
            case .displayDisappearance:
                captureCoordinator = CaptureCoordinator(
                    imageCapturer: Ticket01FailingImageCapturer(failure: .displayUnavailable)
                )
            case .cancellation, .tinySelection, nil:
                captureCoordinator = CaptureCoordinator()
            }
            _model = StateObject(wrappedValue: AppModel(
                recognitionService: Ticket01RecognitionService(),
                captureCoordinator: captureCoordinator,
                history: HistoryStore(inMemory: true),
                defaults: defaults,
                ticket01Reporter: reporter
            ))
        } else {
            _model = StateObject(wrappedValue: AppModel())
        }
    }

    var body: some Scene {
        WindowGroup("MyMathpix") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 920, minHeight: 620)
        }
        .defaultSize(width: 1180, height: 760)

        MenuBarExtra("MyMathpix", systemImage: "function") {
            Button("Capture Snippet  \(model.hotKeyConfiguration.displayName)") {
                model.startCapture()
            }
            .disabled(model.isProcessing)
            Button("Show MyMathpix") { model.showMainWindow() }
            Divider()
            Text(model.statusMessage)
            Divider()
            SettingsLink { Text("Settings…") }
            Button("Quit MyMathpix") { NSApp.terminate(nil) }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 540, height: 560)
        }
    }
}

private struct AppLaunchConfiguration {
    enum Ticket01Scenario: String {
        case permissionNotDetermined = "permission-not-determined"
        case permissionDenied = "permission-denied"
        case permissionRevoked = "permission-revoked"
        case captureAPIFailure = "capture-api-failure"
        case displayDisappearance = "display-disappearance"
        case cancellation
        case tinySelection = "tiny-selection"
    }

    let arguments: [String]

    var runsTicket01MockSelfTest: Bool {
        arguments.contains("--ticket01-mock-recognition-self-test")
    }

    var runsResourceBundleSelfTest: Bool {
        arguments.contains("--ticket01-resource-bundle-self-test")
    }

    var runsOverlayLifecycleSelfTest: Bool {
        arguments.contains("--ticket01-overlay-lifecycle-self-test")
    }

    var runsLocalTokenStoreSelfTest: Bool {
        arguments.contains("--ticket01-local-token-self-test")
    }

    var runsSelfTest: Bool {
        arguments.contains("--self-test")
    }

    var runsTicket01Acceptance: Bool {
        arguments.contains("--ticket01-acceptance")
    }

    var ticket01Scenario: Ticket01Scenario? {
        let prefix = "--ticket01-scenario="
        guard let argument = arguments.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        return Ticket01Scenario(rawValue: String(argument.dropFirst(prefix.count)))
    }
}

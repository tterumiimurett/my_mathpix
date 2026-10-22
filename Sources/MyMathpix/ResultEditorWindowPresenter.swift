import AppKit
import CoreGraphics
import Foundation

@MainActor
protocol ResultEditorWindowPresenting: AnyObject {
    var isMainWindowVisible: Bool { get }
    func registerMainWindow(_ window: NSWindow)
    func installMainWindowOpener(_ opener: @escaping () -> Void)
    func registerResultEditorWindow(_ window: NSWindow)
    func installResultEditorOpener(_ opener: @escaping () -> Void)
    func showMainWindow()
    func presentResultEditor(on displayID: CGDirectDisplayID)
}

struct ResultEditorWindowPresentationObservation: Equatable {
    let requestedDisplayID: CGDirectDisplayID
    let presentedDisplayID: CGDirectDisplayID?
    let usedVisibleAreaTopLeftInset: Bool
}

struct ResultEditorWindowScreen: Equatable {
    let displayID: CGDirectDisplayID
    let visibleFrame: CGRect
}

enum ResultEditorWindowPlacement {
    static let visibleAreaInset: CGFloat = 16

    static func topLeft(
        in visibleFrame: CGRect,
        inset: CGFloat = visibleAreaInset
    ) -> NSPoint {
        NSPoint(x: visibleFrame.minX + inset, y: visibleFrame.maxY - inset)
    }
}

@MainActor
final class AppKitResultEditorWindowPresenter: ResultEditorWindowPresenting {
    private enum PendingPresentation {
        case mainWindow
        case resultEditor(CGDirectDisplayID)
    }

    private let screenProvider: @MainActor () -> [ResultEditorWindowScreen]
    private let activateApplication: @MainActor () -> Void
    private let presentationObservation: ((ResultEditorWindowPresentationObservation) -> Void)?
    private weak var mainWindow: NSWindow?
    private weak var resultEditorWindow: NSWindow?
    private var openResultEditor: (() -> Void)?
    private var openMainWindow: (() -> Void)?
    private var pendingPresentation: PendingPresentation?
    private var didRequestWindowOpen = false

    init(
        screenProvider: @escaping @MainActor () -> [ResultEditorWindowScreen] = {
            NSScreen.screens.compactMap { screen in
                guard let number = screen.deviceDescription[
                    NSDeviceDescriptionKey("NSScreenNumber")
                ] as? NSNumber else { return nil }
                return ResultEditorWindowScreen(
                    displayID: CGDirectDisplayID(number.uint32Value),
                    visibleFrame: screen.visibleFrame
                )
            }
        },
        activateApplication: @escaping @MainActor () -> Void = {
            NSApplication.shared.activate(ignoringOtherApps: true)
        },
        presentationObservation: ((ResultEditorWindowPresentationObservation) -> Void)? = nil
    ) {
        self.screenProvider = screenProvider
        self.activateApplication = activateApplication
        self.presentationObservation = presentationObservation
    }

    var isMainWindowVisible: Bool { mainWindow?.isVisible == true }

    func registerMainWindow(_ window: NSWindow) {
        window.identifier = .myMathpixMainWindow
        mainWindow = window
        didRequestWindowOpen = false
        guard let pendingPresentation else { return }
        present(pendingPresentation)
    }

    func installMainWindowOpener(_ opener: @escaping () -> Void) {
        openMainWindow = opener
        requestWindowIfNeeded()
    }

    func registerResultEditorWindow(_ window: NSWindow) {
        resultEditorWindow = window
        didRequestWindowOpen = false
        if let pendingPresentation { present(pendingPresentation) }
    }

    func installResultEditorOpener(_ opener: @escaping () -> Void) {
        openResultEditor = opener
        requestWindowIfNeeded()
    }

    func showMainWindow() {
        present(.mainWindow)
    }

    func presentResultEditor(on displayID: CGDirectDisplayID) {
        present(.resultEditor(displayID))
    }

    private func present(_ presentation: PendingPresentation) {
        let target: NSWindow?
        switch presentation {
        case .mainWindow:
            resultEditorWindow?.orderOut(nil)
            activateApplication()
            target = mainWindow
        case .resultEditor:
            mainWindow?.orderOut(nil)
            target = resultEditorWindow
        }
        guard let window = target else {
            pendingPresentation = presentation
            requestWindowIfNeeded()
            return
        }

        pendingPresentation = nil
        var presentationScreen: ResultEditorWindowScreen?
        if case .resultEditor(let displayID) = presentation {
            let screens = screenProvider()
            presentationScreen = screens.first(where: { $0.displayID == displayID }) ?? screens.first
            if let presentationScreen {
                // Keep the compact result inside the captured display's usable area,
                // leaving room for the top/left inset even on a small display.
                var frame = window.frame
                frame.size.width = min(470, presentationScreen.visibleFrame.width - 2 * ResultEditorWindowPlacement.visibleAreaInset)
                frame.size.height = min(560, presentationScreen.visibleFrame.height - 2 * ResultEditorWindowPlacement.visibleAreaInset)
                window.setFrame(frame, display: false)
                window.setFrameTopLeftPoint(ResultEditorWindowPlacement.topLeft(
                    in: presentationScreen.visibleFrame
                ))
            }
        }

        window.makeKeyAndOrderFront(nil)
        if case .resultEditor(let displayID) = presentation {
            presentationObservation?(ResultEditorWindowPresentationObservation(
                requestedDisplayID: displayID,
                presentedDisplayID: presentationScreen?.displayID,
                usedVisibleAreaTopLeftInset: presentationScreen.map {
                    window.frame.topLeftApproximatelyEquals(
                        ResultEditorWindowPlacement.topLeft(in: $0.visibleFrame)
                    )
                } ?? false
            ))
        }
    }

    private func requestWindowIfNeeded() {
        guard let pendingPresentation, !didRequestWindowOpen else { return }
        let opener: (() -> Void)?
        switch pendingPresentation {
        case .mainWindow: opener = openMainWindow
        case .resultEditor: opener = openResultEditor
        }
        guard let opener else { return }
        didRequestWindowOpen = true
        opener()
    }
}

private extension NSUserInterfaceItemIdentifier {
    static let myMathpixMainWindow = Self("com.byterumi.mymathpix.main-window")
}

private extension CGRect {
    func topLeftApproximatelyEquals(_ point: NSPoint) -> Bool {
        abs(minX - point.x) < 0.5 && abs(maxY - point.y) < 0.5
    }
}

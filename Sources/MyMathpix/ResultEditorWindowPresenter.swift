import AppKit
import CoreGraphics
import Foundation

@MainActor
protocol ResultEditorWindowPresenting: AnyObject {
    var isMainWindowVisible: Bool { get }
    func registerMainWindow(_ window: NSWindow)
    func installMainWindowOpener(_ opener: @escaping () -> Void)
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

    func showMainWindow() {
        present(.mainWindow)
    }

    func presentResultEditor(on displayID: CGDirectDisplayID) {
        present(.resultEditor(displayID))
    }

    private func present(_ presentation: PendingPresentation) {
        activateApplication()
        guard let window = mainWindow else {
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
                // A restored/default window may fill the display. Moving that
                // frame down by the inset would put its bottom offscreen, so
                // AppKit constrains it back against the menu bar on ordering.
                // Make room for the inset before positioning the real window.
                var frame = window.frame
                frame.size.width = min(frame.width, presentationScreen.visibleFrame.width - ResultEditorWindowPlacement.visibleAreaInset)
                frame.size.height = min(frame.height, presentationScreen.visibleFrame.height - ResultEditorWindowPlacement.visibleAreaInset)
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
        guard pendingPresentation != nil,
              !didRequestWindowOpen,
              let openMainWindow else { return }
        didRequestWindowOpen = true
        openMainWindow()
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

import AppKit
import CoreGraphics
import Foundation

@MainActor
protocol ResultWindowPresenting: AnyObject {
    var isMainWindowVisible: Bool { get }
    func installMainWindowOpener(_ opener: @escaping () -> Void)
    func showMainWindow()
    func presentResult(on displayID: CGDirectDisplayID)
}

struct ResultWindowPresentationObservation: Equatable {
    let requestedDisplayID: CGDirectDisplayID
    let presentedDisplayID: CGDirectDisplayID?
    let usedVisibleAreaTopLeftInset: Bool
}

struct ResultWindowScreen: Equatable {
    let displayID: CGDirectDisplayID
    let visibleFrame: CGRect
}

enum ResultWindowPlacement {
    static let visibleAreaInset: CGFloat = 16

    static func topLeft(
        in visibleFrame: CGRect,
        inset: CGFloat = visibleAreaInset
    ) -> NSPoint {
        NSPoint(x: visibleFrame.minX + inset, y: visibleFrame.maxY - inset)
    }
}

@MainActor
final class AppKitResultWindowPresenter: ResultWindowPresenting {
    private let windowProvider: @MainActor () -> [NSWindow]
    private let screenProvider: @MainActor () -> [ResultWindowScreen]
    private let activateApplication: @MainActor () -> Void
    private let presentationObservation: ((ResultWindowPresentationObservation) -> Void)?
    private var openMainWindow: (() -> Void)?

    init(
        windowProvider: @escaping @MainActor () -> [NSWindow] = { NSApplication.shared.windows },
        screenProvider: @escaping @MainActor () -> [ResultWindowScreen] = {
            NSScreen.screens.compactMap { screen in
                guard let number = screen.deviceDescription[
                    NSDeviceDescriptionKey("NSScreenNumber")
                ] as? NSNumber else { return nil }
                return ResultWindowScreen(
                    displayID: CGDirectDisplayID(number.uint32Value),
                    visibleFrame: screen.visibleFrame
                )
            }
        },
        activateApplication: @escaping @MainActor () -> Void = {
            NSApplication.shared.activate(ignoringOtherApps: true)
        },
        presentationObservation: ((ResultWindowPresentationObservation) -> Void)? = nil
    ) {
        self.windowProvider = windowProvider
        self.screenProvider = screenProvider
        self.activateApplication = activateApplication
        self.presentationObservation = presentationObservation
    }

    var isMainWindowVisible: Bool { mainWindow?.isVisible == true }

    func installMainWindowOpener(_ opener: @escaping () -> Void) {
        openMainWindow = opener
    }

    func showMainWindow() {
        present(displayID: nil, remainingAttempts: 2)
    }

    func presentResult(on displayID: CGDirectDisplayID) {
        present(displayID: displayID, remainingAttempts: 2)
    }

    private func present(displayID: CGDirectDisplayID?, remainingAttempts: Int) {
        activateApplication()
        if let window = mainWindow {
            var presentationScreen: ResultWindowScreen?
            if let displayID {
                let screens = screenProvider()
                presentationScreen = screens.first(where: { $0.displayID == displayID }) ?? screens.first
                if let presentationScreen {
                    window.setFrameTopLeftPoint(ResultWindowPlacement.topLeft(
                        in: presentationScreen.visibleFrame
                    ))
                }
            }
            window.makeKeyAndOrderFront(nil)
            if let displayID {
                presentationObservation?(ResultWindowPresentationObservation(
                    requestedDisplayID: displayID,
                    presentedDisplayID: presentationScreen?.displayID,
                    usedVisibleAreaTopLeftInset: presentationScreen.map {
                        window.frame.topLeftApproximatelyEquals(
                            ResultWindowPlacement.topLeft(in: $0.visibleFrame)
                        )
                    } ?? false
                ))
            }
            return
        }

        guard remainingAttempts > 0 else { return }
        if remainingAttempts == 2 { openMainWindow?() }
        DispatchQueue.main.async { [weak self] in
            self?.present(displayID: displayID, remainingAttempts: remainingAttempts - 1)
        }
    }

    private var mainWindow: NSWindow? {
        windowProvider().first(where: { $0.title == "MyMathpix" })
    }
}

private extension CGRect {
    func topLeftApproximatelyEquals(_ point: NSPoint) -> Bool {
        abs(minX - point.x) < 0.5 && abs(maxY - point.y) < 0.5
    }
}

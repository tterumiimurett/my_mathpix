import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation
import ScreenCaptureKit

protocol ScreenCapturePermissionProviding {
    var hasAccess: Bool { get }
    func requestAccess() -> Bool
}

struct ScreenCapturePermissionObservation: Equatable, Sendable {
    let preflightGranted: Bool
    let requestAttempted: Bool
    let requestGranted: Bool?
}

struct SystemScreenCapturePermission: ScreenCapturePermissionProviding {
    var hasAccess: Bool { CGPreflightScreenCaptureAccess() }

    func requestAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }
}

struct ScreenCaptureRequest: Equatable {
    let displayID: CGDirectDisplayID
    let sourceRect: CGRect
    let geometry: CaptureGeometry

    var pixelWidth: Int { geometry.expectedPixelWidth }
    var pixelHeight: Int { geometry.expectedPixelHeight }

    init?(
        displayID: CGDirectDisplayID,
        selectionInDisplay: CGRect,
        displayFrame: CGRect,
        scale: CGFloat,
        selectedDisplayWasSecondary: Bool = false,
        minimumDimension: CGFloat = 4
    ) {
        let selection = selectionInDisplay.standardized
        guard scale > 0,
              selection.width >= minimumDimension,
              selection.height >= minimumDimension,
              CGRect(origin: .zero, size: displayFrame.size).contains(selection) else {
            return nil
        }

        self.displayID = displayID
        self.sourceRect = CGRect(
            x: selection.minX,
            y: displayFrame.height - selection.maxY,
            width: selection.width,
            height: selection.height
        )
        self.geometry = CaptureGeometry(
            expectedPixelWidth: max(1, Int((selection.width * scale).rounded(.up))),
            expectedPixelHeight: max(1, Int((selection.height * scale).rounded(.up))),
            selectionSizeInPoints: selection.size,
            displayScale: scale,
            selectedDisplayWasSecondary: selectedDisplayWasSecondary
        )
    }
}

struct CaptureGeometry: Equatable {
    let expectedPixelWidth: Int
    let expectedPixelHeight: Int
    let selectionSizeInPoints: CGSize
    let displayScale: CGFloat
    let selectedDisplayWasSecondary: Bool
}

enum DisplayRole {
    static func isSecondary(
        displayID: CGDirectDisplayID,
        mainDisplayID: CGDirectDisplayID = CGMainDisplayID()
    ) -> Bool {
        displayID != mainDisplayID
    }
}

struct CapturedSnippet: Equatable {
    let uploadPayload: UploadPayload
    let geometry: CaptureGeometry
    let displayID: CGDirectDisplayID
}

protocol ScreenImageCapturing: Sendable {
    func capture(request: ScreenCaptureRequest) async throws -> UploadPayload
}

struct ScreenCaptureKitImageCapturer: ScreenImageCapturing {
    func capture(request: ScreenCaptureRequest) async throws -> UploadPayload {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            guard let display = content.displays.first(where: { $0.displayID == request.displayID }) else {
                throw AppError.captureDisplayUnavailable
            }

            let ownProcessID = ProcessInfo.processInfo.processIdentifier
            let ownWindows = content.windows.filter { $0.owningApplication?.processID == ownProcessID }
            let configuration = SCStreamConfiguration()
            configuration.sourceRect = request.sourceRect
            configuration.width = request.pixelWidth
            configuration.height = request.pixelHeight
            configuration.showsCursor = false
            configuration.capturesAudio = false
            let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            guard let data = NSBitmapImageRep(cgImage: image).representation(
                using: .png,
                properties: [:]
            ) else {
                throw AppError.captureFailed
            }
            return UploadPayload(pngData: data)
        } catch {
            throw ScreenCaptureFailureMapper.map(
                error,
                hasScreenCaptureAccess: CGPreflightScreenCaptureAccess()
            )
        }
    }
}

enum ScreenCaptureFailureMapper {
    static func map(_ error: Error, hasScreenCaptureAccess: Bool) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        return hasScreenCaptureAccess ? .captureFailed : .capturePermissionDenied
    }
}

enum ScreenCapturePhase: Equatable {
    case idle
    case selecting
    case capturing
}

struct ScreenCaptureLifecycle {
    private(set) var phase: ScreenCapturePhase = .idle

    mutating func begin() -> Bool {
        guard phase == .idle else { return false }
        phase = .selecting
        return true
    }

    mutating func selectionCompleted() {
        guard phase == .selecting else { return }
        phase = .capturing
    }

    mutating func finish() {
        phase = .idle
    }

    mutating func cancel() {
        phase = .idle
    }
}

@MainActor
final class CaptureCoordinator {
    private var overlays: [CaptureOverlayWindow] = []
    private var completion: ((Result<CapturedSnippet, Error>) -> Void)?
    private var lifecycle = ScreenCaptureLifecycle()
    private let permission: any ScreenCapturePermissionProviding
    private let imageCapturer: any ScreenImageCapturing
    private let permissionObservation: ((ScreenCapturePermissionObservation) -> Void)?
    private var captureTask: Task<Void, Never>?
    private var cursorIsPushed = false
    private var hiddenApplicationWindows: [(window: NSWindow, wasKey: Bool)] = []

    var isActive: Bool { lifecycle.phase != .idle }

    init(
        permission: any ScreenCapturePermissionProviding = SystemScreenCapturePermission(),
        imageCapturer: any ScreenImageCapturing = ScreenCaptureKitImageCapturer(),
        permissionObservation: ((ScreenCapturePermissionObservation) -> Void)? = nil
    ) {
        self.permission = permission
        self.imageCapturer = imageCapturer
        self.permissionObservation = permissionObservation
    }

    var hasPermission: Bool {
        permission.hasAccess
    }

    func requestPermission() {
        _ = permission.requestAccess()
    }

    @discardableResult
    func begin(completion: @escaping (Result<CapturedSnippet, Error>) -> Void) -> Bool {
        guard lifecycle.begin() else {
            completion(.failure(AppError.captureInProgress))
            return false
        }
        let preflightGranted = permission.hasAccess
        let requestGranted = preflightGranted ? nil : permission.requestAccess()
        permissionObservation?(ScreenCapturePermissionObservation(
            preflightGranted: preflightGranted,
            requestAttempted: !preflightGranted,
            requestGranted: requestGranted
        ))
        guard preflightGranted || requestGranted == true else {
            lifecycle.cancel()
            completion(.failure(AppError.capturePermissionDenied))
            return false
        }
        self.completion = completion
        hideApplicationWindows()

        overlays = NSScreen.screens.map { screen in
            let window = CaptureOverlayWindow(screen: screen)
            window.onSelection = { [weak self, weak window] rect in
                guard let self, let window else { return }
                self.finish(selection: rect, on: window.captureScreen)
            }
            window.onCancel = { [weak self] in self?.cancel(notify: true) }
            window.orderFrontRegardless()
            return window
        }
        guard let keyWindow = overlays.first else {
            finishWithFailure(AppError.captureDisplayUnavailable)
            return false
        }
        keyWindow.makeKey()
        keyWindow.makeFirstResponder(keyWindow.contentView)
        pushCursor()
        return true
    }

    func cancel(notify: Bool = false) {
        let callback = completion
        completion = nil
        captureTask?.cancel()
        captureTask = nil
        lifecycle.cancel()
        restoreCaptureUI()
        if notify { callback?(.failure(CancellationError())) }
    }

    private func finish(selection: CGRect, on screen: NSScreen) {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            finishWithFailure(AppError.selectionTooSmall)
            return
        }
        let displayID = CGDirectDisplayID(number.uint32Value)
        guard
              let request = ScreenCaptureRequest(
                  displayID: displayID,
                  selectionInDisplay: selection,
                  displayFrame: screen.frame,
                  scale: screen.backingScaleFactor,
                  selectedDisplayWasSecondary: DisplayRole.isSecondary(displayID: displayID)
              ) else {
            finishWithFailure(AppError.selectionTooSmall)
            return
        }
        let callback = completion
        completion = nil
        lifecycle.selectionCompleted()
        overlays.forEach { $0.orderOut(nil) }
        popCursor()

        captureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            do {
                let uploadPayload = try await imageCapturer.capture(request: request)
                let snippet = CapturedSnippet(
                    uploadPayload: uploadPayload,
                    geometry: request.geometry,
                    displayID: request.displayID
                )
                completeCapture(.success(snippet), callback: callback)
            } catch {
                completeCapture(.failure(error), callback: callback)
            }
        }
    }

    private func finishWithFailure(_ error: Error) {
        let callback = completion
        completion = nil
        lifecycle.cancel()
        restoreCaptureUI()
        callback?(.failure(error))
    }

    private func completeCapture(
        _ result: Result<CapturedSnippet, Error>,
        callback: ((Result<CapturedSnippet, Error>) -> Void)?
    ) {
        lifecycle.finish()
        captureTask = nil
        closeOverlays()
        if case .failure = result {
            restoreApplicationWindows()
        }
        callback?(result)
    }

    func releaseHiddenApplicationWindows() {
        hiddenApplicationWindows.removeAll()
    }

    private func restoreCaptureUI() {
        closeOverlays()
        restoreApplicationWindows()
    }

    private func hideApplicationWindows() {
        hiddenApplicationWindows = NSApp.windows.compactMap { window in
            guard window.isVisible, !(window is CaptureOverlayWindow) else { return nil }
            let state = (window: window, wasKey: window.isKeyWindow)
            window.orderOut(nil)
            return state
        }
    }

    private func restoreApplicationWindows() {
        let windows = hiddenApplicationWindows
        hiddenApplicationWindows.removeAll()
        for state in windows {
            if state.wasKey {
                state.window.makeKeyAndOrderFront(nil)
            } else {
                state.window.orderFront(nil)
            }
        }
    }

    private func closeOverlays() {
        overlays.forEach { $0.close() }
        overlays.removeAll()
        popCursor()
    }

    private func pushCursor() {
        guard !cursorIsPushed else { return }
        NSCursor.crosshair.push()
        cursorIsPushed = true
    }

    private func popCursor() {
        guard cursorIsPushed else { return }
        NSCursor.pop()
        cursorIsPushed = false
    }
}

@MainActor
enum Ticket01OverlayLifecycleSelfTest {
    static func run() -> Bool {
        guard let screen = NSScreen.screens.first else { return false }
        let windowContract = autoreleasepool {
            let window = CaptureOverlayWindow(screen: screen)
            let contract = (
                isOwnedByARC: !window.isReleasedWhenClosed,
                isNonactivatingPanel: window.styleMask.contains(.nonactivatingPanel),
                joinsAllSpaces: window.collectionBehavior.contains(.canJoinAllSpaces),
                supportsFullscreenSpace: window.collectionBehavior.contains(.fullScreenAuxiliary),
                staysOutOfMainWindowRole: !window.canBecomeMain
            )
            window.orderOut(nil)
            window.close()
            return contract
        }
        guard windowContract.isOwnedByARC,
              windowContract.isNonactivatingPanel,
              windowContract.joinsAllSpaces,
              windowContract.supportsFullscreenSpace,
              windowContract.staysOutOfMainWindowRole else { return false }

        let coordinator = CaptureCoordinator(
            permission: Ticket01FixedScreenCapturePermission(
                hasAccess: true,
                requestResult: true
            )
        )
        var cancellationCount = 0
        for _ in 0..<3 {
            let began = coordinator.begin { result in
                if case .failure(let error) = result, error is CancellationError {
                    cancellationCount += 1
                }
            }
            guard began, coordinator.isActive else { return false }
            coordinator.cancel(notify: true)
            guard !coordinator.isActive else { return false }
        }
        return cancellationCount == 3
    }
}

private final class CaptureOverlayWindow: NSPanel {
    let captureScreen: NSScreen
    var onSelection: ((CGRect) -> Void)? {
        didSet { overlayView.onSelection = onSelection }
    }
    var onCancel: (() -> Void)? {
        didSet { overlayView.onCancel = onCancel }
    }
    private let overlayView: CaptureOverlayView

    init(screen: NSScreen) {
        self.captureScreen = screen
        self.overlayView = CaptureOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isReleasedWhenClosed = false
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        worksWhenModal = true
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = overlayView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class CaptureOverlayView: NSView {
    var onSelection: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    private var startPoint: CGPoint?
    private var selection: CGRect = .zero

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        startPoint = event.locationInWindow
        selection = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint else { return }
        selection = rect(from: startPoint, to: event.locationInWindow)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let startPoint else { return }
        selection = rect(from: startPoint, to: event.locationInWindow)
        onSelection?(selection)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) { onCancel?() }
        else { super.keyDown(with: event) }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.30).setFill()
        bounds.fill()
        guard !selection.isEmpty else { return }
        NSGraphicsContext.saveGraphicsState()
        NSColor.clear.setFill()
        selection.fill(using: .copy)
        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(rect: selection.insetBy(dx: 0.5, dy: 0.5))
        path.lineWidth = 2
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }
}

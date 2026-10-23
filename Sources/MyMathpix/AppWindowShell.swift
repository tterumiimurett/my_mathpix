import AppKit
import SwiftUI

/// Owns the compact result window separately from the explicit main workspace.
@MainActor
final class AppWindowShell: NSObject, NSApplicationDelegate {
    private weak var model: AppModel?
    private var resultPanel: CompactResultPanel?
    private var statusItem: NSStatusItem?
    private var handledInitialActivation = false
    private var initiallyShowsResult = false
    private var isolatesWindowState = false
    private var showedInitialResult = false

    func configure(model: AppModel, initiallyShowsResult: Bool = false, isolatesWindowState: Bool = false) {
        guard self.model !== model else { return }
        self.model = model
        self.initiallyShowsResult = initiallyShowsResult
        self.isolatesWindowState = isolatesWindowState
        handledInitialActivation = NSApp.isActive
        model.installResultEditorOpener { [weak self] in self?.createResultPanel() }
        installStatusItem()
    }

    func showInitialResult() {
        guard !showedInitialResult else { return }
        showedInitialResult = true
        model?.showResultEditor()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard let model else { return }
        if !handledInitialActivation && initiallyShowsResult {
            handledInitialActivation = true
            model.showResultEditor()
        } else {
            handledInitialActivation = true
            model.showMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model?.showMainWindow()
        return false
    }

    private func installStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if !isolatesWindowState { item.autosaveName = "MyMathpix.CompactResult" }
        item.isVisible = true
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "function", accessibilityDescription: "MyMathpix")
            button.image?.isTemplate = true
            button.setAccessibilityLabel("MyMathpix")
            button.setAccessibilityIdentifier("mymathpix-status-item")
            button.toolTip = "MyMathpix"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.autoenablesItems = false
            let shortcut = model?.hotKeyConfiguration.displayName ?? ""
            let capture = menu.addItem(withTitle: "Capture Snippet  \(shortcut)", action: #selector(captureSnippet), keyEquivalent: "")
            capture.target = self
            capture.isEnabled = model?.isProcessing == false
            let workspace = menu.addItem(withTitle: "Open MyMathpix", action: #selector(openWorkspace), keyEquivalent: "")
            workspace.target = self
            menu.addItem(.separator())
            let status = menu.addItem(withTitle: model?.statusMessage ?? "Ready", action: nil, keyEquivalent: "")
            status.isEnabled = false
            menu.addItem(.separator())
            let settings = menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
            settings.target = self
            let quit = menu.addItem(withTitle: "Quit MyMathpix", action: #selector(quit), keyEquivalent: "q")
            quit.target = self
            NSMenu.popUpContextMenu(menu, with: event, for: sender)
        } else {
            model?.showResultEditor()
        }
    }

    @objc private func captureSnippet() { model?.startCapture() }
    @objc private func openWorkspace() { model?.showMainWindow() }
    @objc private func openSettings() { model?.showSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func createResultPanel() {
        guard let model else { return }
        if let resultPanel {
            model.registerResultEditorWindow(resultPanel)
            return
        }
        let panel = CompactResultPanel()
        panel.contentView = NSHostingView(rootView: CompactResultContent().environmentObject(model))
        resultPanel = panel
        model.registerResultEditorWindow(panel)
    }
}

private final class CompactResultPanel: NSPanel {
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 470, height: 512),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered, defer: false)
        title = "MyMathpix"
        identifier = NSUserInterfaceItemIdentifier("com.byterumi.mymathpix.compact-result")
        isReleasedWhenClosed = false
        isRestorable = false
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentMinSize = NSSize(width: 400, height: 360)
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        startClickMonitoring()
    }

    override func orderOut(_ sender: Any?) {
        stopClickMonitoring()
        super.orderOut(sender)
    }

    override func close() {
        stopClickMonitoring()
        super.close()
    }

    private func startClickMonitoring() {
        guard localClickMonitor == nil, globalClickMonitor == nil else { return }
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        // The panel does not activate MyMathpix, so application deactivation alone
        // cannot detect a click back into the application that was already active.
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isVisible, self.attachedSheet == nil,
                      !self.frame.contains(NSEvent.mouseLocation) else { return }
                self.orderOut(nil)
            }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: clicks) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, self.isVisible, self.attachedSheet == nil else { return }
                var target = event.window
                while let window = target {
                    if window === self { return }
                    target = window.parent ?? window.sheetParent
                }
                self.orderOut(nil)
            }
            // Let the clicked control or other window receive the original click.
            return event
        }
    }

    private func stopClickMonitoring() {
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        localClickMonitor = nil
        globalClickMonitor = nil
    }
}

private struct CompactResultContent: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if let item = model.selectedItem {
                ResultEditorView(item: item).id(item.id)
            } else {
                ContentUnavailableView("No Snippet yet", systemImage: "viewfinder",
                    description: Text("Use \(model.hotKeyConfiguration.displayName) to capture one."))
            }
        }
        .frame(minWidth: 400, minHeight: 360)
        .alert("MyMathpix", isPresented: Binding(
            get: { model.errorMessage != nil && !model.isMainWindowVisible },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            if model.needsCredentialRecovery || !model.hasToken {
                Button("Open MyMathpix") {
                    model.errorMessage = nil
                    model.showMainWindow()
                }
            }
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

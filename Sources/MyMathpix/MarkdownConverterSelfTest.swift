import AppKit

/// Drives the main window through its accessibility controls and reads a
/// dedicated pasteboard using the same AppKit interface as a Paste Target.
@MainActor
enum MarkdownConverterSelfTest {
    private static var started = false

    static func makeModel(pasteboard: NSPasteboard) -> AppModel {
        AppModel(
            recognitionService: Ticket03AcceptanceRecognitionService(),
            history: HistoryStore(inMemory: true),
            usageRecords: UsageRecordStore(inMemory: true),
            defaults: UserDefaults(suiteName: "com.byterumi.mymathpix.markdown-test.\(UUID().uuidString)")!,
            diagnosticLog: DiagnosticLog(rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("MyMathpixMarkdownTest-\(UUID().uuidString)", isDirectory: true)),
            pasteboard: pasteboard,
            registersHotKey: false
        )
    }

    static func run(pasteboard: NSPasteboard) async {
        guard !started else { return }
        started = true
        do {
            try await verify(pasteboard: pasteboard)
            pasteboard.releaseGlobally()
            print("MARKDOWN_CONVERTER_SELF_TEST_OK")
            exit(0)
        } catch {
            pasteboard.releaseGlobally()
            print("MARKDOWN_CONVERTER_SELF_TEST_FAIL \(error.localizedDescription)")
            exit(1)
        }
    }

    private static func verify(pasteboard: NSPasteboard) async throws {
        let (window, open) = try await waitFor("Convert Markdown in the main window") { () -> (NSWindow, AnyObject)? in
            for window in NSApp.windows where window.isVisible {
                if let button = button("Convert Markdown", in: window) { return (window, button) }
            }
            return nil
        }
        _ = open.accessibilityPerformPress?()
        let sheet = try await waitFor("Markdown converter sheet") { window.attachedSheet }
        for title in ["Copy Markdown", "Copy Lark", "Copy Notion", "Copy Plain Text"] {
            let action = try await waitFor(title) { button(title, in: sheet) }
            try require(action.isAccessibilityEnabled?() == false, "Empty input enabled \(title)")
        }

        let editor = try await waitFor("Markdown Source field") {
            element(in: sheet) {
                $0.accessibilityRole?() == .textArea && $0.accessibilityLabel?() == "Markdown Source"
            } as? NSTextView
        }
        let input = NSPasteboard.withUniqueName()
        defer { input.releaseGlobally() }
        try paste("# Draft\n\n**Value** is $x^2$.", into: editor, from: input)
        _ = try await waitFor("copy actions to enable") { () -> Bool? in
            guard button("Copy Markdown", in: sheet)?.isAccessibilityEnabled?() == true,
                  button("Copy Plain Text", in: sheet)?.isAccessibilityEnabled?() == true else { return nil }
            return true
        }
        let draftTitle = (editor.string as NSString).range(of: "Draft")
        try require(draftTitle.location != NSNotFound, "Initial Markdown was not pasted")
        editor.setSelectedRange(draftTitle)
        try paste("Final", into: editor, from: input)

        try await copy("Copy Markdown", from: sheet, to: pasteboard)
        try require(pasteboard.string(forType: .string) == "# Final\n\n**Value** is $x^2$.",
                    "Markdown copy did not preserve the latest source")

        try await copy("Copy Plain Text", from: sheet, to: pasteboard)
        try require(pasteboard.string(forType: .string) == "Final\n\nValue is x^2.",
                    "Plain Text copy did not contain the converted source")
        try require(pasteboard.pasteboardItems?.map(\.types) == [[.string]],
                    "Plain Text copy included another clipboard format")
    }

    private static func paste(_ text: String, into editor: NSTextView, from input: NSPasteboard) throws {
        input.clearContents()
        try require(input.setString(text, forType: .string) && editor.readSelection(from: input),
                    "Could not paste into Markdown Source")
    }

    private static func copy(_ title: String, from sheet: NSWindow, to pasteboard: NSPasteboard) async throws {
        let action = try await waitFor(title) { button(title, in: sheet) }
        let before = pasteboard.changeCount
        _ = action.accessibilityPerformPress?()
        _ = try await waitFor("\(title) to write to the clipboard") {
            pasteboard.changeCount == before ? nil : pasteboard.pasteboardItems?.first
        }
    }

    private static func button(_ title: String, in window: NSWindow) -> AnyObject? {
        element(in: window) {
            $0.accessibilityRole?() == .button
                && ($0.accessibilityLabel?() == title || $0.accessibilityTitle?() == title)
        }
    }

    private static func element(in root: AnyObject, matching matches: (AnyObject) -> Bool) -> AnyObject? {
        // SwiftUI supplies accessibility elements through Objective-C selectors.
        for child in NSAccessibility.unignoredChildren(from: root.accessibilityChildren?() ?? []) {
            if let found = element(in: child as AnyObject, matching: matches) { return found }
        }
        return matches(root) ? root : nil
    }

    private static func waitFor<Value>(_ description: String, _ probe: () -> Value?) async throws -> Value {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(4))
        repeat {
            if let value = probe() { return value }
            try await Task.sleep(for: .milliseconds(20))
        } while clock.now < deadline
        throw Failure(errorDescription: "Timed out waiting for \(description)")
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure(errorDescription: message) }
    }

    private struct Failure: LocalizedError {
        let errorDescription: String?
    }
}

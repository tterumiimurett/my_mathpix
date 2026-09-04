import Foundation

@MainActor
enum SelfCheck {
    static func run() -> Bool {
        var failures: [String] = []

        check(
            MarkdownNormalizer.normalize("# Result  \r\n\r\n\r\n$x$\t\r\n") == "# Result\n\n$x$",
            "Markdown normalization",
            failures: &failures
        )
        check(
            MarkdownNormalizer.pureFormula(in: "$$ x^2 + y^2 $$") == "x^2 + y^2",
            "display formula detection",
            failures: &failures
        )
        check(
            MarkdownNormalizer.pureFormula(in: "The answer is $x$.") == nil,
            "mixed content is not a pure formula",
            failures: &failures
        )
        check(
            MarkdownNormalizer.pureFormula(in: "$$x$$\n\n$$y$$") == nil,
            "multiple formulas are not a pure formula",
            failures: &failures
        )

        let table = """
        | Name | Value |
        | --- | ---: |
        | x | $1$ |
        | y | 2 |
        """
        check(
            MarkdownNormalizer.markdownTableTSV(from: table) == "Name\tValue\nx\t$1$\ny\t2",
            "Markdown table to TSV",
            failures: &failures
        )

        let preview = MarkdownRenderer.document(for: "$$x^2$$\n\n\(table)")
        check(preview.contains("data-display=\"1\""), "formula preview marker", failures: &failures)
        check(preview.contains("<table>"), "table preview", failures: &failures)
        check(
            !preview.contains("src=\"http") && !preview.contains("href=\"http") && !preview.contains("url(http"),
            "offline preview",
            failures: &failures
        )
        let escaped = MarkdownRenderer.renderBody("<script>alert('x')</script>")
        check(!escaped.contains("<script>alert") && escaped.contains("&lt;script&gt;"), "raw HTML escaping", failures: &failures)

        let secondaryDisplayFrame = CGRect(x: -1_440, y: 200, width: 1_440, height: 900)
        let captureRequest = ScreenCaptureRequest(
            displayID: 42,
            selectionInDisplay: CGRect(x: 100.25, y: 50.5, width: 300.25, height: 120.25),
            displayFrame: secondaryDisplayFrame,
            scale: 2
        )
        check(
            captureRequest?.sourceRect == CGRect(x: 100.25, y: 729.25, width: 300.25, height: 120.25),
            "secondary display coordinate conversion",
            failures: &failures
        )
        check(
            captureRequest?.pixelWidth == 601 && captureRequest?.pixelHeight == 241,
            "Retina selection preserves fractional edge pixels",
            failures: &failures
        )
        check(
            !DisplayRole.isSecondary(displayID: 42, mainDisplayID: 42),
            "CG main display is classified as primary",
            failures: &failures
        )
        check(
            DisplayRole.isSecondary(displayID: 43, mainDisplayID: 42),
            "non-main display remains secondary after key-window changes",
            failures: &failures
        )
        check(
            ScreenCaptureRequest(
                displayID: 42,
                selectionInDisplay: CGRect(x: 10, y: 10, width: 3.9, height: 20),
                displayFrame: secondaryDisplayFrame,
                scale: 2
            ) == nil,
            "tiny selection is rejected before ScreenCaptureKit",
            failures: &failures
        )

        var captureLifecycle = ScreenCaptureLifecycle()
        check(captureLifecycle.begin(), "idle capture can begin", failures: &failures)
        check(
            !captureLifecycle.begin() && captureLifecycle.phase == .selecting,
            "second capture is blocked while selecting",
            failures: &failures
        )
        captureLifecycle.selectionCompleted()
        check(
            !captureLifecycle.begin() && captureLifecycle.phase == .capturing,
            "second capture is blocked while capturing",
            failures: &failures
        )
        captureLifecycle.finish()
        check(
            captureLifecycle.phase == .idle && captureLifecycle.begin(),
            "capture is operable again after completion",
            failures: &failures
        )
        captureLifecycle.cancel()

        let syntheticCaptureError = NSError(domain: "Ticket01Capture", code: 1)
        check(
            ScreenCaptureFailureMapper.map(
                syntheticCaptureError,
                hasScreenCaptureAccess: false
            ).safeDiagnosticCode == "permission_denied",
            "revoked ScreenCaptureKit failure maps to permission explanation",
            failures: &failures
        )
        check(
            ScreenCaptureFailureMapper.map(
                syntheticCaptureError,
                hasScreenCaptureAccess: true
            ).safeDiagnosticCode == "capture_api_failure",
            "ScreenCaptureKit failure maps to capture explanation",
            failures: &failures
        )
        check(
            ScreenCaptureFailureMapper.map(
                AppError.captureDisplayUnavailable,
                hasScreenCaptureAccess: true
            ).safeDiagnosticCode == "display_unavailable",
            "domain capture failures keep their diagnostic code",
            failures: &failures
        )

        do {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("MyMathpix-SelfCheck-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: root) }
            let store = HistoryStore(rootURL: root)
            for index in 0..<21 {
                let item = try store.create(uploadPayload: UploadPayload(pngData: Data("image-\(index)".utf8)))
                var completed = item
                completed.status = .complete
                completed.markdown = "result \(index)"
                try store.update(completed)
            }
            check(store.items.count == 20, "history limit", failures: &failures)
            check(store.items.first?.markdown == "result 20", "newest history first", failures: &failures)
            check(store.items.first(where: { $0.markdown == "result 0" }) == nil, "oldest history deletion", failures: &failures)
        } catch {
            failures.append("history persistence: \(error.localizedDescription)")
        }

        do {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("MyMathpix-LocalToken-SelfCheck-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: root) }
            let tokenStore = LocalTokenStore(rootURL: root)
            check(tokenStore.readToken() == nil, "local token starts empty", failures: &failures)
            try tokenStore.saveToken("  ticket01-local-non-secret  ")
            check(
                tokenStore.readToken() == "ticket01-local-non-secret",
                "local token save and read",
                failures: &failures
            )
            let attributes = try FileManager.default.attributesOfItem(atPath: tokenStore.storageURL.path)
            let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
            check(permissions == 0o600, "local token file permissions", failures: &failures)
            try tokenStore.saveToken("ticket01-local-replacement-non-secret")
            check(
                tokenStore.readToken() == "ticket01-local-replacement-non-secret",
                "local token replacement",
                failures: &failures
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o644))],
                ofItemAtPath: tokenStore.storageURL.path
            )
            check(tokenStore.readToken() == nil, "unsafe local token is rejected", failures: &failures)
            try tokenStore.saveToken("ticket01-local-repaired-non-secret")
            check(
                tokenStore.hasPrivatePermissions,
                "local token replacement repairs permissions",
                failures: &failures
            )
            try tokenStore.saveToken("")
            check(tokenStore.readToken() == nil, "local token clear", failures: &failures)
        } catch {
            failures.append("local token persistence: \(error.localizedDescription)")
        }

        if failures.isEmpty {
            print("MyMathpix self-test passed (31 checks).")
            return true
        }
        print("MyMathpix self-test failed:")
        failures.forEach { print("- \($0)") }
        return false
    }

    private static func check(_ condition: Bool, _ name: String, failures: inout [String]) {
        if !condition { failures.append(name) }
    }
}

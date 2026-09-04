import AppKit
import Foundation

@MainActor
enum Ticket03SelfCheck {
    static func run() -> Bool {
        var failures: [String] = []

        let source = """
        Inline \\(x + 1\\) and code `\\(leave\\)`.

        \\[
        y = x^2
        \\]

        ```text
        \\(leave this too\\)
        ```
        """
        let canonical = """
        Inline $x + 1$ and code `\\(leave\\)`.

        $$
        y = x^2
        $$

        ```text
        \\(leave this too\\)
        ```
        """
        check(
            MarkdownNormalizer.normalize(source) == canonical,
            "canonical formula delimiters outside code",
            failures: &failures
        )
        check(
            MarkdownNormalizer.normalize(canonical) == canonical,
            "normalization is deterministic and idempotent",
            failures: &failures
        )

        let table = """
        | Label | Value |
        | --- | ---: |
        | A \\| B | $2$ |
        """
        check(
            MarkdownNormalizer.markdownTableTSV(from: table) == "Label\tValue\nA | B\t$2$",
            "editable GFM table converts escaped pipes to TSV",
            failures: &failures
        )
        check(
            MarkdownRenderer.renderBody(table).contains("<td>A | B</td>"),
            "editable GFM table preserves escaped pipes in preview",
            failures: &failures
        )
        check(
            MarkdownNormalizer.pureFormula(in: " \n $$x^2 + y^2$$ \n ") == "x^2 + y^2",
            "one formula plus whitespace is pure",
            failures: &failures
        )
        for mixed in [
            "Before $x$",
            "$$x$$\n\n$$y$$",
            "$$x$y$$",
            "| x |\n| --- |\n| $y$ |",
            "`$x$`"
        ] {
            check(
                MarkdownNormalizer.pureFormula(in: mixed) == nil,
                "mixed or ambiguous content is not pure formula",
                failures: &failures
            )
        }

        let unsafeTable = """
        <div>outside</div>
        <table onclick="steal()" style="background:url(https://example.invalid/a)">
          <thead><tr><th scope="col">Name</th><th colspan="2">Value</th></tr></thead>
          <tbody>
            <tr><td rowspan="2">safe &amp; sound</td><td><img src="https://example.invalid/i" onerror="steal()">2</td></tr>
            <tr><td><script>steal()</script><iframe src="https://example.invalid/f"></iframe>text</td></tr>
          </tbody>
        </table>
        """
        if let safeTable = ComplexTableOutputSanitizer.sanitize(unsafeTable) {
            let lowered = safeTable.html.lowercased()
            check(lowered.hasPrefix("<table>"), "safe complex table has one table root", failures: &failures)
            check(lowered.contains("scope=\"col\"") && lowered.contains("colspan=\"2\"") && lowered.contains("rowspan=\"2\""), "safe table attributes are retained", failures: &failures)
            check(
                !lowered.contains("onclick")
                    && !lowered.contains("style=")
                    && !lowered.contains("<script")
                    && !lowered.contains("<iframe")
                    && !lowered.contains("<img")
                    && !lowered.contains("https://"),
                "executable and remote complex-table content is removed",
                failures: &failures
            )
            check(
                safeTable.tabSeparatedText.contains("Name\tValue")
                    && safeTable.tabSeparatedText.contains("safe & sound\t2"),
                "safe complex table provides a TSV fallback",
                failures: &failures
            )
        } else {
            failures.append("safe complex table is retained")
        }
        check(
            ComplexTableOutputSanitizer.sanitize("<div>not a table</div>") == nil,
            "non-table HTML is rejected",
            failures: &failures
        )

        let previewBefore = MarkdownRenderer.document(for: "Value: \\(x\\)")
        let previewAfter = MarkdownRenderer.document(for: "Value: \\(y^2\\)")
        check(previewBefore != previewAfter, "source edits produce a new preview", failures: &failures)
        check(
            previewAfter.contains("Content-Security-Policy")
                && previewAfter.contains("default-src 'none'")
                && !previewAfter.contains("src=\"https://")
                && !previewAfter.contains("href=\"https://")
                && !previewAfter.contains("url(https://")
                && !previewAfter.contains("<iframe"),
            "preview document declares an offline resource policy",
            failures: &failures
        )
        let escapedHTML = MarkdownRenderer.renderBody("<img src=https://example.invalid onerror=steal()>")
        check(
            escapedHTML.contains("&lt;img") && !escapedHTML.contains("<img"),
            "raw HTML is escaped by default",
            failures: &failures
        )
        check(
            OfflinePreviewNavigationPolicy.allows(URL(string: "https://example.invalid")!) == false
                && OfflinePreviewNavigationPolicy.allows(URL(string: "file:///tmp/local-font.woff2")!)
                && OfflinePreviewNavigationPolicy.allows(URL(string: "about:blank")!),
            "preview navigation permits only offline URLs",
            failures: &failures
        )

        check(
            CopyFormat.allCases.map(\.title) == [
                "Formula Output (LaTeX)",
                "Markdown",
                "Combined Output",
                "TSV Table",
                "Rich Table",
                "Original Image"
            ],
            "all six explicit Copy Formats are available",
            failures: &failures
        )
        check(
            CopyFormat.explanation.contains("source")
                && CopyFormat.explanation.contains("Native Paste")
                && CopyFormat.explanation.contains("Notion")
                && CopyFormat.explanation.contains("Feishu")
                && CopyFormat.explanation.contains("does not create native"),
            "Copy Formats are distinguished from Native Paste",
            failures: &failures
        )

        guard let png = makePNG() else {
            failures.append("original image fixture")
            return report(failures)
        }
        let mixedMarkdown = """
        Result: $x + 1$

        | Label | Value |
        | --- | ---: |
        | A | 2 |
        """
        let safeComplexHTML = ComplexTableOutputSanitizer.sanitize(unsafeTable)?.html
        let payload = ClipboardPayload(
            canonicalMarkdown: mixedMarkdown,
            complexTableHTML: safeComplexHTML,
            originalPNG: png
        )
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("Ticket03SelfCheck.\(UUID().uuidString)"))

        assertCopy(.markdown, payload: payload, pasteboard: pasteboard, plainText: mixedMarkdown, failures: &failures)
        assertCopy(.combinedOutput, payload: payload, pasteboard: pasteboard, plainText: mixedMarkdown, failures: &failures)
        assertCopy(.tsvTable, payload: payload, pasteboard: pasteboard, plainText: "Label\tValue\nA\t2", failures: &failures)

        do {
            try ClipboardService.copy(.richTable, payload: payload, to: pasteboard)
            let types = Set(pasteboard.types ?? [])
            check(types.contains(.html), "rich table provides public HTML", failures: &failures)
            check(types.contains(.rtf), "rich table provides public RTF", failures: &failures)
            check(types.contains(.tabularText), "rich table provides public TSV", failures: &failures)
            check(types.contains(.string), "rich table provides public plain text", failures: &failures)
            check(
                pasteboard.data(forType: .html).flatMap { String(data: $0, encoding: .utf8) } == safeComplexHTML,
                "rich table HTML is the sanitized representation",
                failures: &failures
            )
            check(
                pasteboard.string(forType: .string) == pasteboard.string(forType: .tabularText),
                "rich table plain text matches its TSV fallback",
                failures: &failures
            )
            check(!(pasteboard.data(forType: .rtf)?.isEmpty ?? true), "rich table RTF has content", failures: &failures)
        } catch {
            failures.append("rich table Copy Format")
        }

        do {
            let purePayload = ClipboardPayload(canonicalMarkdown: "$$x^2$$", complexTableHTML: nil, originalPNG: png)
            try ClipboardService.copy(.formulaOutput, payload: purePayload, to: pasteboard)
            check(pasteboard.string(forType: .string) == "x^2", "Formula Output is raw LaTeX", failures: &failures)
            check(
                ClipboardService.automaticCopyFormat(for: purePayload.canonicalMarkdown) == .formulaOutput,
                "Pure Formula chooses automatic Formula Output copy",
                failures: &failures
            )
            check(
                ClipboardService.automaticCopyFormat(for: mixedMarkdown) == nil,
                "mixed Combined Output waits for owner copy action",
                failures: &failures
            )
            do {
                try ClipboardService.copy(.formulaOutput, payload: payload, to: pasteboard)
                failures.append("mixed content Formula Output is rejected")
            } catch CopyFormatError.formulaOutputRequiresPureFormula {
                // Expected.
            } catch {
                failures.append("mixed content Formula Output reports the expected reason")
            }
        } catch {
            failures.append("Formula Output Copy Format")
        }

        do {
            try ClipboardService.copy(.originalImage, payload: payload, to: pasteboard)
            check(pasteboard.data(forType: .png) == png, "original PNG bytes are copied", failures: &failures)
            check(!(pasteboard.data(forType: .tiff)?.isEmpty ?? true), "original image offers TIFF compatibility", failures: &failures)
        } catch {
            failures.append("original image Copy Format")
        }

        do {
            let history = HistoryStore(inMemory: true)
            let created = try history.create(uploadPayload: UploadPayload(pngData: png))
            var completed = created
            completed.status = .complete
            completed.markdown = Ticket03AcceptanceFixture.initialMarkdown
            completed.html = safeComplexHTML
            try history.update(completed)
            let journeyPasteboard = NSPasteboard(
                name: NSPasteboard.Name("Ticket03Journey.\(UUID().uuidString)")
            )
            let model = AppModel(
                recognitionService: Ticket03AcceptanceRecognitionService(),
                history: history,
                defaults: UserDefaults(suiteName: "Ticket03Journey.\(UUID().uuidString)")!,
                pasteboard: journeyPasteboard,
                registersHotKey: false
            )
            model.updateMarkdown(Ticket03AcceptanceFixture.editedMarkdown)
            check(
                model.selectedItem?.markdown == Ticket03AcceptanceFixture.editedMarkdown,
                "owner edit is retained as current Canonical Markdown",
                failures: &failures
            )
            check(
                model.selectedItem?.html == nil,
                "owner edit invalidates stale service table HTML",
                failures: &failures
            )
            check(
                MarkdownRenderer.document(for: model.selectedItem?.markdown ?? "").contains("Verified identity"),
                "owner edit flows into offline preview input",
                failures: &failures
            )
            model.copySelected(as: .richTable)
            check(
                Ticket03PasteboardInspector.inspect(.richTable, pasteboard: journeyPasteboard),
                "owner edit flows into public rich-table pasteboard values",
                failures: &failures
            )
            model.copySelected(as: .combinedOutput)
            check(
                Ticket03PasteboardInspector.inspect(.combinedOutput, pasteboard: journeyPasteboard),
                "owner edit flows into Combined Output",
                failures: &failures
            )
        } catch {
            failures.append("complete owner edit-preview-copy journey")
        }

        let acceptanceLaunch = AppLaunchConfiguration(
            arguments: [
                "MyMathpix",
                "--ticket03-acceptance",
                "--ticket03-run-id=00000000-0000-4000-8000-000000000003"
            ]
        )
        let pasteboardInspection = AppLaunchConfiguration(
            arguments: ["MyMathpix", "--ticket03-inspect-pasteboard=richTable"]
        )
        check(acceptanceLaunch.runsTicket03Acceptance, "Ticket 03 signed acceptance launch is explicit", failures: &failures)
        check(
            !AppLaunchConfiguration(
                arguments: ["MyMathpix", "--ticket03-acceptance"]
            ).runsTicket03Acceptance,
            "unbound Ticket 03 acceptance launch is rejected",
            failures: &failures
        )
        check(
            pasteboardInspection.ticket03PasteboardInspection == .richTable,
            "Ticket 03 pasteboard inspection selects one known Copy Format",
            failures: &failures
        )

        return report(failures)
    }

    private static func assertCopy(
        _ format: CopyFormat,
        payload: ClipboardPayload,
        pasteboard: NSPasteboard,
        plainText: String,
        failures: inout [String]
    ) {
        do {
            try ClipboardService.copy(format, payload: payload, to: pasteboard)
            check(pasteboard.string(forType: .string) == plainText, "\(format.title) public plain text", failures: &failures)
        } catch {
            failures.append("\(format.title) Copy Format")
        }
    }

    private static func makePNG() -> Data? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 2,
            pixelsHigh: 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        let color = NSColor(deviceRed: 0.1, green: 0.65, blue: 0.7, alpha: 1)
        for y in 0..<2 {
            for x in 0..<2 {
                bitmap.setColor(color, atX: x, y: y)
            }
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func check(_ condition: Bool, _ name: String, failures: inout [String]) {
        if !condition { failures.append(name) }
    }

    private static func report(_ failures: [String]) -> Bool {
        if failures.isEmpty {
            print("Ticket 03 self-test passed.")
            return true
        }
        print("Ticket 03 self-test failed:")
        failures.forEach { print("- \($0)") }
        return false
    }
}

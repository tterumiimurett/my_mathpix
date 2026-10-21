import AppKit
import Foundation

enum Ticket03AcceptanceFixture {
    static let initialMarkdown = """
    Before $x^2$.

    $$y = x + 1$$

    | <b>Name</b> | Value |
    | --- | --- |
    | <strong>A &amp; B</strong> | &alpha; &copy; &#945; |
    | <code>**literal**</code> | a < b > c |
    | long | Content beyond a single line must remain complete after copying — COMPLETE-CELL-END |

    After the table.
    """

    static let editedMarkdown = """
    $$e^{i\\pi} = -1$$

    | Symbol | Meaning |
    | --- | --- |
    | $\\pi$ | Circle constant |
    | $e$ | Euler's number |
    """

    @MainActor
    static func seed(history: HistoryStore) throws {
        guard let png = makeOriginalSnippetPNG() else {
            throw CopyFormatError.imageUnavailable
        }
        let created = try history.create(uploadPayload: UploadPayload(pngData: png))
        var complete = created
        complete.markdown = initialMarkdown
        complete.status = .complete
        complete.mode = .fast
        complete.runtime = 1.25
        try history.update(complete)
    }

    private static func makeOriginalSnippetPNG() -> Data? {
        let size = NSSize(width: 1100, height: 420)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSColor.systemTeal.setStroke()
        let border = NSBezierPath(roundedRect: NSRect(x: 8, y: 8, width: 1084, height: 404), xRadius: 10, yRadius: 10)
        border.lineWidth = 4
        border.stroke()

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]
        // This synthetic snippet shows the literal input, not an OCR result.
        for (index, line) in initialMarkdown.split(separator: "\n").enumerated() {
            NSString(string: String(line)).draw(
                at: NSPoint(x: 34, y: 374 - index * 38),
                withAttributes: bodyAttributes
            )
        }
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

@MainActor
final class Ticket03AcceptanceRecognitionService: RecognitionService {
    func recognize(uploadPayload: UploadPayload, mode: RecognitionMode) async throws -> DatalabResult {
        throw AppError.service("Recognition is disabled in the isolated Ticket 03 acceptance fixture.")
    }
}

@MainActor
enum Ticket03PasteboardInspector {
    static let pureFormulaSource = "$$x^2 + y^2$$"

    private static func containsFixturePartsInOrder(_ html: String, parts: [String]) -> Bool {
        var cursor = html.startIndex
        for part in parts {
            guard let range = html.range(of: part, range: cursor..<html.endIndex) else { return false }
            cursor = range.upperBound
        }
        return true
    }

    static func inspect(
        _ format: CopyFormat,
        pasteboard: NSPasteboard = .general,
        expectedMarkdown: String? = nil
    ) -> Bool {
        let types = Set(pasteboard.types ?? [])
        switch format {
        case .lark, .notion:
            let expected = expectedMarkdown ?? pasteboard.string(forType: .string)
            guard let expected,
                  expected == Ticket03AcceptanceFixture.initialMarkdown
                    || expected == Ticket03AcceptanceFixture.editedMarkdown,
                  types.contains(.html), types.contains(.string),
                  pasteboard.string(forType: .string) == expected,
                  let html = pasteboard.string(forType: .html),
                  html.components(separatedBy: "<table>").count == 2 else { return false }
            let initial = expected == Ticket03AcceptanceFixture.initialMarkdown
            let initialTable = "<table><thead><tr><th>Name</th><th>Value</th></tr></thead><tbody>"
                + "<tr><td>A &amp; B</td><td>α © α</td></tr>"
                + "<tr><td>**literal**</td><td>a &lt; b &gt; c</td></tr>"
                + "<tr><td>long</td><td>Content beyond a single line must remain complete after copying — COMPLETE-CELL-END</td></tr>"
                + "</tbody></table>"
            let editedLarkTable = "<table><thead><tr><th>Symbol</th><th>Meaning</th></tr></thead><tbody>"
                + "<tr><td>$\\pi$</td><td>Circle constant</td></tr>"
                + "<tr><td>$e$</td><td>Euler&#39;s number</td></tr></tbody></table>"
            // Independent fixed-fixture literals: do not regenerate expected HTML
            // with the clipboard renderer whose output is being inspected.
            if initial && !html.contains(initialTable) { return false }
            if format == .lark {
                return (initial || html.contains(editedLarkTable))
                    && containsFixturePartsInOrder(html, parts: initial
                        ? ["Before $x^2$.", "$$y = x + 1$$", initialTable, "After the table."]
                        : ["$$e^{i\\pi} = -1$$", editedLarkTable])
                    && !types.contains(.init("org.chromium.web-custom-data"))
                    && !types.contains(.init("com.byterumi.mymathpix.notion-blocks-v3"))
            }
            let formulas = initial ? ["x^2", "y = x + 1"] : ["e^{i\\pi} = -1", "\\pi", "e"]
            let annotations = formulas.map { "<annotation encoding=\"application/x-tex\">\($0)</annotation>" }
            guard html.components(separatedBy: "<math").count == formulas.count + 1,
                  html.components(separatedBy: "<annotation encoding=\"application/x-tex\">").count == formulas.count + 1,
                  containsFixturePartsInOrder(html, parts: annotations) else { return false }
            if !initial {
                // Only the two known formula cells vary in MathML markup. Exact
                // row separators and cell counts bind their annotations to the
                // correct cells, preserving the complete fixed grid and order.
                guard let begin = html.range(of: "<table>"),
                      let end = html.range(of: "</table>", range: begin.upperBound..<html.endIndex) else { return false }
                let table = String(html[begin.lowerBound..<end.upperBound])
                guard table.components(separatedBy: "<td>").count == 5,
                      table.components(separatedBy: "<th>").count == 3,
                      table.components(separatedBy: "<tr>").count == 4,
                      containsFixturePartsInOrder(table, parts: [
                        "<table><thead><tr><th>Symbol</th><th>Meaning</th></tr></thead><tbody><tr><td>",
                        annotations[1], "</td><td>Circle constant</td></tr><tr><td>",
                        annotations[2], "</td><td>Euler&#39;s number</td></tr></tbody></table>"
                      ]) else { return false }
            }
            return containsFixturePartsInOrder(html, parts: initial
                ? ["Before ", annotations[0], annotations[1], initialTable, "After the table."]
                : [annotations[0], "<table>", annotations[1], annotations[2]])
                && types.contains(.init("org.chromium.web-custom-data"))
                && types.contains(.init("com.byterumi.mymathpix.notion-blocks-v3"))
        case .formulaOutput:
            return types.contains(.string)
                && pasteboard.string(forType: .string) == "x^2 + y^2"
        case .markdown:
            let expected = expectedMarkdown ?? pasteboard.string(forType: .string)
            return types.contains(.string)
                && (expected == Ticket03AcceptanceFixture.initialMarkdown
                    || expected == Ticket03AcceptanceFixture.editedMarkdown)
                && pasteboard.string(forType: .string) == expected
        case .combinedOutput:
            return types.contains(.string)
                && pasteboard.string(forType: .string) == Ticket03AcceptanceFixture.editedMarkdown
        case .tsvTable:
            let expected = "Symbol\tMeaning\n$\\pi$\tCircle constant\n$e$\tEuler's number"
            return types.contains(.tabularText)
                && types.contains(.string)
                && pasteboard.string(forType: .tabularText) == expected
                && pasteboard.string(forType: .string) == expected
        case .richTable:
            guard types.contains(.html), types.contains(.rtf),
                  types.contains(.tabularText), types.contains(.string),
                  let htmlData = pasteboard.data(forType: .html),
                  let html = String(data: htmlData, encoding: .utf8),
                  let expectedHTML = MarkdownNormalizer.tableHTML(
                    from: Ticket03AcceptanceFixture.editedMarkdown
                  ),
                  let rtf = pasteboard.data(forType: .rtf) else { return false }
            let expectedTSV = MarkdownNormalizer.markdownTableTSV(
                from: Ticket03AcceptanceFixture.editedMarkdown
            )
            return html == expectedHTML
                && !rtf.isEmpty
                && pasteboard.string(forType: .tabularText) == expectedTSV
                && pasteboard.string(forType: .string) == expectedTSV
                && !html.lowercased().contains("http")
                && !html.lowercased().contains("onerror")
        case .originalImage:
            guard types.contains(.png), types.contains(.tiff),
                  let png = pasteboard.data(forType: .png),
                  let tiff = pasteboard.data(forType: .tiff) else { return false }
            return !png.isEmpty && !tiff.isEmpty && NSImage(data: png) != nil
        }
    }
}

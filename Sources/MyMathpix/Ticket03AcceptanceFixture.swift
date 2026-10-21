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

    static func inspect(_ format: CopyFormat, pasteboard: NSPasteboard = .general) -> Bool {
        let types = Set(pasteboard.types ?? [])
        switch format {
        case .notion:
            return types.contains(.html)
                && types.contains(.string)
                && types.contains(.init("org.chromium.web-custom-data"))
                && types.contains(.init("com.byterumi.mymathpix.notion-blocks-v3"))
        case .formulaOutput:
            return types.contains(.string)
                && pasteboard.string(forType: .string) == "x^2 + y^2"
        case .markdown, .combinedOutput:
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

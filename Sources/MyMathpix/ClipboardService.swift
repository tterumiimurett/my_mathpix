import AppKit
import Foundation

enum CopyFormat: String, CaseIterable, Identifiable {
    case formulaOutput
    case markdown
    case combinedOutput
    case tsvTable
    case richTable
    case originalImage
    case notion
    case lark

    static let visibleFormats: [CopyFormat] = [.markdown, .lark, .notion]

    var id: String { rawValue }

    private var descriptor: (title: String, helpText: String) {
        switch self {
        case .formulaOutput:
            ("Formula Output (LaTeX)", "Copy raw LaTeX when the result is one Pure Formula.")
        case .markdown:
            ("Markdown", "Copy the editable Canonical Markdown source.")
        case .combinedOutput:
            ("Combined Output", "Copy all text, formulas, and tables. Currently the same Markdown source as Markdown above.")
        case .tsvTable:
            ("TSV Table (Plain Text)", "Copy the first table as tab-separated plain text.")
        case .richTable:
            ("Rich Table (HTML + RTF)", "Copy safe HTML, RTF, TSV, and plain-text table representations together.")
        case .originalImage:
            ("Original Image", "Copy the original Snippet image without recognized text.")
        case .notion:
            ("Notion", "Copy rich tables with editable inline and display equations.")
        case .lark:
            ("Lark", "Copy editable rich tables and equations, with Markdown source fallback.")
        }
    }

    var title: String { descriptor.title }

    var helpText: String { descriptor.helpText }

    static let explanation = "Markdown copies source. Lark and Notion include experimental Native Paste clipboard data for editable equations and tables. Destination compatibility must be verified. No Notion or Feishu document API writes."
}

struct ClipboardPayload {
    let canonicalMarkdown: String
    let complexTableHTML: String?
    let originalPNG: Data?
}

struct PreparedClipboardCopy {
    enum Content {
        case text(String)
        case table(tsv: String, html: String?)
        case image(png: Data, tiff: Data)
        case notion(NotionClipboardDocument)
        case lark(LarkClipboardDocument)
    }
    let format: CopyFormat
    let content: Content

    var previewText: String? {
        switch content {
        case .text(let text): text
        case .table(let tsv, _): tsv
        case .image: nil
        case .notion(let document): document.source
        case .lark(let document): document.source
        }
    }

    var previewImage: NSImage? {
        guard case .image(let png, _) = content else { return nil }
        return NSImage(data: png)
    }
}

enum CopyFormatError: LocalizedError, Equatable {
    case formulaOutputRequiresPureFormula
    case tableUnavailable
    case imageUnavailable
    case pasteboardWriteFailed

    var shortDescription: String {
        switch self {
        case .formulaOutputRequiresPureFormula: "Pure formula only"
        case .tableUnavailable: "No table"
        case .imageUnavailable: "No original image"
        case .pasteboardWriteFailed: "Copy failed"
        }
    }

    var errorDescription: String? {
        switch self {
        case .formulaOutputRequiresPureFormula:
            "Formula Output is available only when the result is one Pure Formula."
        case .tableUnavailable:
            "No editable Markdown table or safe Complex Table Output is available."
        case .imageUnavailable:
            "The original Snippet image is unavailable."
        case .pasteboardWriteFailed:
            "The selected Copy Format could not be written to the clipboard."
        }
    }
}

@MainActor
enum ClipboardService {
    static func unavailability(of format: CopyFormat, payload: ClipboardPayload) -> CopyFormatError? {
        do { _ = try prepare(format, payload: payload); return nil }
        catch { return error as? CopyFormatError ?? .pasteboardWriteFailed }
    }

    static func automaticCopyFormat(for canonicalMarkdown: String) -> CopyFormat? {
        automaticCopyFormat(for: ClipboardPayload(
            canonicalMarkdown: canonicalMarkdown, complexTableHTML: nil, originalPNG: nil
        ))
    }

    static func automaticCopyFormat(for payload: ClipboardPayload) -> CopyFormat? {
        pureFormula(in: payload) == nil ? nil : .formulaOutput
    }

    private static func pureFormula(in payload: ClipboardPayload) -> String? {
        guard payload.complexTableHTML.flatMap(ComplexTableOutputSanitizer.sanitize) == nil else { return nil }
        return MarkdownNormalizer.pureFormula(in: payload.canonicalMarkdown)
    }

    static func prepare(_ format: CopyFormat, payload: ClipboardPayload) throws -> PreparedClipboardCopy {
        let content: PreparedClipboardCopy.Content
        switch format {
        case .formulaOutput:
            guard let latex = pureFormula(in: payload) else { throw CopyFormatError.formulaOutputRequiresPureFormula }
            content = .text(latex)
        case .markdown, .combinedOutput:
            content = .text(payload.canonicalMarkdown)
        case .lark:
            content = .lark(LarkClipboardDocument(
                markdown: payload.canonicalMarkdown, complexTableHTML: payload.complexTableHTML
            ))
        case .notion:
            content = .notion(try NotionClipboardDocument(
                markdown: payload.canonicalMarkdown, complexTableHTML: payload.complexTableHTML
            ))
        case .tsvTable, .richTable:
            guard let table = tableRepresentations(for: payload) else { throw CopyFormatError.tableUnavailable }
            content = .table(tsv: table.tsv, html: format == .richTable ? table.html : nil)
        case .originalImage:
            guard let png = payload.originalPNG, let image = NSImage(data: png),
                  let tiff = image.tiffRepresentation else { throw CopyFormatError.imageUnavailable }
            content = .image(png: png, tiff: tiff)
        }
        return PreparedClipboardCopy(format: format, content: content)
    }

    static func copy(
        _ format: CopyFormat,
        payload: ClipboardPayload,
        to pasteboard: NSPasteboard = .general
    ) throws {
        try copy(prepare(format, payload: payload), to: pasteboard)
    }

    static func copy(_ prepared: PreparedClipboardCopy, to pasteboard: NSPasteboard = .general) throws {
        let item = NSPasteboardItem()
        var representations: [NSPasteboard.PasteboardType: Data] = [:]
        switch prepared.content {
        case .text(let text):
            representations[.string] = Data(text.utf8)
        case .table(let tsv, let html):
            representations[.string] = Data(tsv.utf8)
            representations[.tabularText] = Data(tsv.utf8)
            if let html {
                let htmlData = Data(html.utf8)
                let attributed = try NSAttributedString(
                    data: htmlData,
                    options: [.documentType: NSAttributedString.DocumentType.html,
                              .characterEncoding: String.Encoding.utf8.rawValue],
                    documentAttributes: nil
                )
                let rtf = try attributed.data(
                    from: NSRange(location: 0, length: attributed.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                )
                guard !rtf.isEmpty else { throw CopyFormatError.tableUnavailable }
                representations[.html] = htmlData
                representations[.rtf] = rtf
            }
        case .image(let png, let tiff):
            representations[.png] = png
            representations[.tiff] = tiff
        case .notion(let document):
            representations[.string] = Data(document.source.utf8)
            representations[.html] = Data(document.html.utf8)
            representations[NotionClipboardDocument.nativeType] = document.nativeData
            representations[NotionClipboardDocument.chromiumType] = document.chromiumData
        case .lark(let document):
            representations[.string] = Data(document.source.utf8)
            representations[.html] = Data(document.html.utf8)
            if let data = document.chromiumData { representations[ChromiumClipboardData.type] = data }
        }
        for (type, data) in representations {
            guard item.setData(data, forType: type) else { throw CopyFormatError.pasteboardWriteFailed }
        }
        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else { throw CopyFormatError.pasteboardWriteFailed }
    }

    // Compatibility wrappers keep the existing capture acceptance seam stable.
    static func copyMarkdown(_ markdown: String) {
        try? copy(
            .markdown,
            payload: ClipboardPayload(canonicalMarkdown: markdown, complexTableHTML: nil, originalPNG: nil)
        )
    }

    static func copyLaTeX(from markdown: String) -> Bool {
        (try? copy(
            .formulaOutput,
            payload: ClipboardPayload(canonicalMarkdown: markdown, complexTableHTML: nil, originalPNG: nil)
        )) != nil
    }

    static func copyTSV(from markdown: String) -> Bool {
        (try? copy(
            .tsvTable,
            payload: ClipboardPayload(canonicalMarkdown: markdown, complexTableHTML: nil, originalPNG: nil)
        )) != nil
    }

    static func copyRichTable(from markdown: String) -> Bool {
        (try? copy(
            .richTable,
            payload: ClipboardPayload(canonicalMarkdown: markdown, complexTableHTML: nil, originalPNG: nil)
        )) != nil
    }

    static func copyImage(_ data: Data) -> Bool {
        (try? copy(
            .originalImage,
            payload: ClipboardPayload(canonicalMarkdown: "", complexTableHTML: nil, originalPNG: data)
        )) != nil
    }

    private struct TableRepresentations {
        let html: String
        let tsv: String
    }

    private static func tableRepresentations(for payload: ClipboardPayload) -> TableRepresentations? {
        if let html = MarkdownNormalizer.tableHTML(from: payload.canonicalMarkdown),
           let tsv = MarkdownNormalizer.markdownTableTSV(from: payload.canonicalMarkdown) {
            return TableRepresentations(html: html, tsv: tsv)
        }
        if let complexTableHTML = payload.complexTableHTML,
           let safe = ComplexTableOutputSanitizer.sanitize(complexTableHTML) {
            return TableRepresentations(html: safe.html, tsv: safe.tabSeparatedText)
        }
        return nil
    }

}

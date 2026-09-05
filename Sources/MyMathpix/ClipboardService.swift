import AppKit
import Foundation

enum CopyFormat: String, CaseIterable, Identifiable {
    case formulaOutput
    case markdown
    case combinedOutput
    case tsvTable
    case richTable
    case originalImage

    var id: String { rawValue }

    private var descriptor: (title: String, helpText: String) {
        switch self {
        case .formulaOutput:
            ("Formula Output (LaTeX)", "Copy raw LaTeX when the result is one Pure Formula.")
        case .markdown:
            ("Markdown", "Copy the editable Canonical Markdown source.")
        case .combinedOutput:
            ("Combined Output", "Copy the complete text, formulas, and tables as one Combined Output.")
        case .tsvTable:
            ("TSV Table (Plain Text)", "Copy the first table as tab-separated plain text.")
        case .richTable:
            ("Rich Table (HTML + RTF)", "Copy safe HTML, RTF, TSV, and plain-text table representations together.")
        case .originalImage:
            ("Original Image", "Copy the original Snippet image without recognized text.")
        }
    }

    var title: String { descriptor.title }

    var helpText: String { descriptor.helpText }

    static let explanation = "Copy source formats only — not Native Paste. Copying does not create native Notion or Feishu blocks."
}

struct ClipboardPayload {
    let canonicalMarkdown: String
    let complexTableHTML: String?
    let originalPNG: Data?
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
        switch format {
        case .formulaOutput:
            return pureFormula(in: payload) == nil
                ? .formulaOutputRequiresPureFormula : nil
        case .markdown, .combinedOutput:
            return nil
        case .tsvTable, .richTable:
            return tableRepresentations(for: payload) == nil ? .tableUnavailable : nil
        case .originalImage:
            guard let png = payload.originalPNG, NSImage(data: png)?.tiffRepresentation != nil else {
                return .imageUnavailable
            }
            return nil
        }
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

    static func copy(
        _ format: CopyFormat,
        payload: ClipboardPayload,
        to pasteboard: NSPasteboard = .general
    ) throws {
        switch format {
        case .formulaOutput:
            guard let latex = pureFormula(in: payload) else {
                throw CopyFormatError.formulaOutputRequiresPureFormula
            }
            try writePlainText(latex, to: pasteboard)
        case .markdown, .combinedOutput:
            try writePlainText(payload.canonicalMarkdown, to: pasteboard)
        case .tsvTable:
            guard let tsv = tabSeparatedText(for: payload) else {
                throw CopyFormatError.tableUnavailable
            }
            pasteboard.clearContents()
            guard pasteboard.setString(tsv, forType: .tabularText),
                  pasteboard.setString(tsv, forType: .string) else {
                throw CopyFormatError.pasteboardWriteFailed
            }
        case .richTable:
            guard let representations = tableRepresentations(for: payload),
                  let htmlData = representations.html.data(using: .utf8),
                  let attributed = try? NSAttributedString(
                    data: htmlData,
                    options: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue
                    ],
                    documentAttributes: nil
                  ),
                  let rtf = try? attributed.data(
                    from: NSRange(location: 0, length: attributed.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                  ),
                  !rtf.isEmpty else {
                throw CopyFormatError.tableUnavailable
            }
            pasteboard.clearContents()
            guard pasteboard.setData(htmlData, forType: .html),
                  pasteboard.setData(rtf, forType: .rtf),
                  pasteboard.setString(representations.tsv, forType: .tabularText),
                  pasteboard.setString(representations.tsv, forType: .string) else {
                throw CopyFormatError.pasteboardWriteFailed
            }
        case .originalImage:
            guard let png = payload.originalPNG,
                  let image = NSImage(data: png),
                  let tiff = image.tiffRepresentation else {
                throw CopyFormatError.imageUnavailable
            }
            pasteboard.clearContents()
            guard pasteboard.setData(png, forType: .png),
                  pasteboard.setData(tiff, forType: .tiff) else {
                throw CopyFormatError.pasteboardWriteFailed
            }
        }
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

    private static func tabSeparatedText(for payload: ClipboardPayload) -> String? {
        if let tsv = MarkdownNormalizer.markdownTableTSV(from: payload.canonicalMarkdown) {
            return tsv
        }
        guard let complexTableHTML = payload.complexTableHTML else { return nil }
        return ComplexTableOutputSanitizer.sanitize(complexTableHTML)?.tabSeparatedText
    }

    private static func writePlainText(_ string: String, to pasteboard: NSPasteboard) throws {
        pasteboard.clearContents()
        guard pasteboard.setString(string, forType: .string) else {
            throw CopyFormatError.pasteboardWriteFailed
        }
    }
}

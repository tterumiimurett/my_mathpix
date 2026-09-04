import AppKit
import Foundation

enum ClipboardService {
    static func copyMarkdown(_ markdown: String) {
        writeString(markdown, type: .string)
    }

    static func copyLaTeX(from markdown: String) -> Bool {
        guard let latex = MarkdownNormalizer.pureFormula(in: markdown) else { return false }
        writeString(latex, type: .string)
        return true
    }

    static func copyTSV(from markdown: String) -> Bool {
        guard let tsv = MarkdownNormalizer.markdownTableTSV(from: markdown) else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(tsv, forType: .tabularText)
        pasteboard.setString(tsv, forType: .string)
        return true
    }

    static func copyRichTable(from markdown: String) -> Bool {
        guard let html = MarkdownNormalizer.tableHTML(from: markdown),
              let htmlData = html.data(using: .utf8),
              let tsv = MarkdownNormalizer.markdownTableTSV(from: markdown) else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(htmlData, forType: .html)
        pasteboard.setString(tsv, forType: .tabularText)
        pasteboard.setString(markdown, forType: .string)
        if let attributed = try? NSAttributedString(
            data: htmlData,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
        ), let rtf = try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) {
            pasteboard.setData(rtf, forType: .rtf)
        }
        return true
    }

    static func copyImage(_ data: Data) -> Bool {
        guard let image = NSImage(data: data) else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects([image])
    }

    private static func writeString(_ string: String, type: NSPasteboard.PasteboardType) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: type)
    }
}

import Foundation

/// Lark native equations/tables, with safe HTML and Markdown source fallbacks.
struct LarkClipboardDocument {
    let html: String
    let source: String
    let chromiumData: Data?

    init(markdown: String, complexTableHTML: String?) {
        let canonical = MarkdownNormalizer.normalize(markdown)
        var body = MarkdownRenderer.renderBody(
            canonical, forClipboard: true, formulaRepresentation: .markdown
        )
        var fallback = markdown
        if complexTableHTML != nil, let root = try? ClipboardHTMLTree.parse(body),
           let layout = try? TableOutputLayout(markdown: canonical, complexTableHTML: complexTableHTML, root: root) {
            if layout.table != nil { body = layout.renderedBody(renderNode: TableOutputLayout.html, renderTable: { $0.html }) }
            fallback = layout.sourceFallback(markdown)
        } else if let table = complexTableHTML.flatMap(ComplexTableOutputSanitizer.sanitize) {
            body += table.html
            fallback += (table.captionText.map { "\n\n" + $0 } ?? "") + "\n\n" + table.tabSeparatedText
        }
        let native = try? LarkNativeClipboardDocument(markdown: canonical, complexTableHTML: complexTableHTML)
        chromiumData = native?.chromiumData
        body += native?.htmlMarker ?? ""
        html = "<html><head><meta charset=\"utf-8\"></head><body>\(body)</body></html>"
        source = fallback
    }
}

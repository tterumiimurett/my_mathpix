import Foundation

/// Rich tables with literal Markdown math. Deliberately excludes Notion's
/// private native-block representations and MathML formula fallback.
struct LarkClipboardDocument {
    let html: String
    let source: String

    init(markdown: String, complexTableHTML: String?) {
        let canonical = MarkdownNormalizer.normalize(markdown)
        var body = MarkdownRenderer.renderBody(
            canonical, forClipboard: true, formulaRepresentation: .markdown
        )
        var fallback = markdown
        if let table = complexTableHTML.flatMap(ComplexTableOutputSanitizer.sanitize),
           !table.isRepresented(in: canonical) {
            body += "\n" + table.html
            if let caption = table.captionText { fallback += "\n\n" + caption }
            fallback += "\n\n" + table.tabSeparatedText
        }
        html = "<html><head><meta charset=\"utf-8\"></head><body>\(body)</body></html>"
        source = fallback
    }
}

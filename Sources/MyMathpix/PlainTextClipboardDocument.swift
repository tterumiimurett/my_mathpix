import Foundation

enum PlainTextClipboardDocument {
    static func render(_ payload: ClipboardPayload) throws -> String {
        let markdown = payload.canonicalMarkdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let body = MarkdownRenderer.renderBody(markdown, forClipboard: true, forPlainText: true)
        let root = try ClipboardHTMLTree.parse(body)
        let layout = try TableOutputLayout(markdown: markdown, complexTableHTML: payload.complexTableHTML, root: root)
        let text = try layout.renderedBody(renderNode: { node in
            guard let tag = node.tag else { return "" }
            let text: String
            switch tag {
            case "ul":
                text = node.children.map(content).joined(separator: "\n")
            case "table":
                text = tableRows(node).joined(separator: "\n")
            default:
                text = content(node)
            }
            return text.isEmpty ? "" : text + "\n\n"
        }, renderTable: { table in
            let rows = try table.cellHTML.map { row in
                try row.map { html in
                    let cell = try ClipboardHTMLTree.parse(html)
                    return tableCell(layout.legacyEquation(cell) ?? content(cell))
                }.joined(separator: "\t")
            }
            return (table.captionText.map { $0 + "\n\n" } ?? "") + rows.joined(separator: "\n") + "\n\n"
        })
        return String(text.dropLast(2))
    }

    private static func content(_ node: ClipboardHTMLTree.Node) -> String {
        if let value = node.tex ?? node.text { return value }
        return node.children.map(content).joined()
    }

    private static func tableRows(_ node: ClipboardHTMLTree.Node) -> [String] {
        guard node.tag == "tr" else { return node.children.flatMap(tableRows) }
        let row = node.children.map { tableCell(content($0)) }
        return [row.joined(separator: "\t")]
    }

    private static func tableCell(_ text: String) -> String {
        text.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
    }
}

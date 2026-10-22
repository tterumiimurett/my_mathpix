import Foundation

/// Combines the two service representations of a table at its original position.
/// Matching is comparison-only: the selected rich table keeps its literal content.
struct TableOutputLayout {
    let root: ClipboardHTMLTree.Node
    let table: SafeComplexTable?
    let replacement: ClipboardHTMLTree.Node?
    let repeatedCaption: ClipboardHTMLTree.Node?
    let canonicalTableMath: Set<String>

    init(markdown: String, complexTableHTML: String?, root: ClipboardHTMLTree.Node) throws {
        self.root = root
        table = complexTableHTML.flatMap(ComplexTableOutputSanitizer.sanitize)
            .flatMap { $0.isRepresented(in: markdown) ? nil : $0 }
        if let table {
            let semanticRoot = try ClipboardHTMLTree.parse(MarkdownRenderer.renderBody(markdown))
            let code = Self.descendants(semanticRoot, tag: "code").map(Self.text)
            canonicalTableMath = Set(Self.descendants(semanticRoot, tag: "table").flatMap(Self.formulae)).filter { tex in
                !code.contains { $0.contains("$\(tex)$") || $0.contains("\\(\(tex)\\)") }
            }
            // Compare every consumer against the same literal cell projection.
            // Preview source keeps Markdown escapes which clipboard cells remove.
            let comparisonRoot = try ClipboardHTMLTree.parse(MarkdownRenderer.renderBody(markdown, forClipboard: true))
            let grid = try table.cellHTML.map { try $0.map { Self.comparisonText(try ClipboardHTMLTree.parse($0)) } }
            replacement = zip(root.children.filter { $0.tag == "table" }, comparisonRoot.children.filter { $0.tag == "table" }).first { _, node in
                let rows = Self.descendants(node, tag: "tr").map { row in
                    row.children.filter { $0.tag == "th" || $0.tag == "td" }.map(Self.comparisonText)
                }
                return rows.count == grid.count && zip(rows, grid).allSatisfy { lhs, rhs in
                    lhs.count == rhs.count && zip(lhs, rhs).allSatisfy(Self.equivalentCell)
                }
            }?.0
        } else {
            canonicalTableMath = []
            replacement = nil
        }
        if let replacement, let index = root.children.firstIndex(where: { $0 === replacement }),
           let previous = root.children[..<index].last(where: { $0.tag != nil }),
           previous.tag == "p", Self.comparisonText(previous) == table?.captionText,
           Self.descendants(previous, tag: "code").isEmpty {
            repeatedCaption = previous
        } else {
            repeatedCaption = nil
        }
    }

    func renderedBody(
        renderNode: (ClipboardHTMLTree.Node) throws -> String,
        renderTable: (SafeComplexTable) throws -> String
    ) rethrows -> String {
        var body = ""
        for node in root.children {
            if node === repeatedCaption { continue }
            if node === replacement, let table { body += try renderTable(table) }
            else { body += try renderNode(node) }
        }
        if replacement == nil, let table { body += try renderTable(table) }
        return body
    }

    func sourceFallback(_ markdown: String) -> String {
        guard let table else { return markdown }
        if replacement != nil {
            return repeatedCaption == nil ? markdown + (table.captionText.map { "\n\n" + $0 } ?? "") : markdown
        }
        return markdown + (table.captionText.map { "\n\n" + $0 } ?? "") + "\n\n" + table.tabSeparatedText
    }

    /// Legacy stored tables lack explicit math metadata. Recover only a whole
    /// cell corroborated by a real equation in a source table, never code text.
    func legacyEquation(_ node: ClipboardHTMLTree.Node) -> String? {
        guard node.children.allSatisfy({ $0.text != nil }) else { return nil }
        let value = Self.text(node)
        guard value.hasPrefix("$"), value.hasSuffix("$"), value.count > 2 else { return nil }
        let tex = String(value.dropFirst().dropLast())
        return canonicalTableMath.contains(tex) ? tex : nil
    }

    func previewHTML(_ table: SafeComplexTable) throws -> String {
        let tree = try ClipboardHTMLTree.parse(table.previewHTML)
        for cell in Self.descendants(tree, tag: "td") + Self.descendants(tree, tag: "th") {
            if let tex = legacyEquation(cell) {
                cell.children = [.init(tag: "span", attributes: ["data-tex": Data(tex.utf8).base64EncodedString()], children: [.init(text: tex)])]
            }
        }
        return tree.children.map(Self.html).joined()
    }

    static func html(_ node: ClipboardHTMLTree.Node) -> String {
        if let value = node.text { return MarkdownNormalizer.escapeHTML(value) }
        guard let tag = node.tag else { return node.children.map(html).joined() }
        let attributes = node.attributes.sorted { $0.key < $1.key }.map {
            " \($0.key)=\"\(MarkdownNormalizer.escapeHTML($0.value))\""
        }.joined()
        if ["br", "hr", "col", "img"].contains(tag) { return "<\(tag)\(attributes)/>" }
        return "<\(tag)\(attributes)>\(node.children.map(html).joined())</\(tag)>"
    }

    private static func descendants(_ node: ClipboardHTMLTree.Node, tag: String) -> [ClipboardHTMLTree.Node] {
        node.children.flatMap { $0.tag == tag ? [$0] : descendants($0, tag: tag) }
    }

    private static func formulae(_ node: ClipboardHTMLTree.Node) -> [String] {
        guard node.tag != "code", node.tag != "pre" else { return [] }
        if let tex = node.tex, node.attributes["data-display"] != "1" { return [tex] }
        return node.children.flatMap(formulae)
    }

    private static func text(_ node: ClipboardHTMLTree.Node) -> String {
        node.text ?? node.children.map(text).joined()
    }

    private static func comparisonText(_ node: ClipboardHTMLTree.Node) -> String {
        if let tex = node.tex { return "$" + tex + "$" }
        return node.text ?? node.children.map(comparisonText).joined()
    }

    private static func equivalentCell(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        // The rich service output can retain Markdown decoration as literal
        // text. Never decode an entity-looking string a second time to match.
        guard rhs.range(of: #"&(?:#[xX]?[0-9a-fA-F]+|[A-Za-z]+);"#, options: .regularExpression) == nil else { return false }
        return lhs == TableCellText.plainText(rhs)
    }
}

/// Parses only generated fragments or sanitized cell HTML, never raw service HTML.
final class ClipboardHTMLTree: NSObject, XMLParserDelegate {
    final class Node {
        let tag: String?
        let text: String?
        let attributes: [String: String]
        var children: [Node]
        var tex: String? {
            attributes["data-tex"].flatMap { Data(base64Encoded: $0) }.flatMap { String(data: $0, encoding: .utf8) }
        }
        init(tag: String? = nil, text: String? = nil, attributes: [String: String] = [:], children: [Node] = []) {
            self.tag = tag; self.text = text; self.attributes = attributes; self.children = children
        }
    }

    private var stack: [Node] = []
    private var root: Node?

    static func parse(_ generatedHTML: String) throws -> Node {
        let delegate = ClipboardHTMLTree()
        let parser = XMLParser(data: Data("<root>\(generatedHTML)</root>".utf8))
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), let root = delegate.root else { throw CopyFormatError.pasteboardWriteFailed }
        return root
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        let node = Node(tag: elementName, attributes: attributes)
        stack.last?.children.append(node)
        if root == nil { root = node }
        stack.append(node)
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.children.append(Node(text: string))
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        _ = stack.popLast()
    }
}

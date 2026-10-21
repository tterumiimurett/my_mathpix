import AppKit
import Foundation
import JavaScriptCore

/// An offline clipboard adapter, not a Notion API integration. Native block
/// data uses Notion's undocumented v3 copy format; destination acceptance is
/// required separately from the public pasteboard serialization tests.
@MainActor
struct NotionClipboardDocument {
    static let nativeMIMEType = "text/_notion-blocks-v3-production"
    // macOS requires a valid UTI; the web MIME belongs inside Chromium's
    // DataTransfer envelope, not directly in NSPasteboard's type list.
    static let nativeType = NSPasteboard.PasteboardType("com.byterumi.mymathpix.notion-blocks-v3")
    static let chromiumType = NSPasteboard.PasteboardType("org.chromium.web-custom-data")

    let html: String
    let source: String
    let nativeData: Data
    let chromiumData: Data

    init(markdown: String, complexTableHTML: String?) throws {
        var fallback = markdown
        let canonical = MarkdownNormalizer.normalize(markdown)
        let root = try ClipboardHTMLTree.parse(MarkdownRenderer.renderBody(canonical, forClipboard: true))
        var blocks = root.children.filter { $0.tag != nil }.flatMap(Self.blocks)
        var body = try root.children.map(Self.html).joined()
        if let table = complexTableHTML.flatMap(ComplexTableOutputSanitizer.sanitize),
           !table.isRepresented(in: canonical) {
            // Notion simple tables have no merged-cell representation. Preserve
            // the safe merged HTML as fallback and occupied grid slots natively.
            if let caption = table.captionText {
                blocks.append(Self.envelope(type: "text", title: [[caption]]))
                fallback += "\n\n" + caption
            }
            let rows = table.tabSeparatedText.components(separatedBy: "\n").map { line in
                // Sanitized HTML projects to literal text, not Markdown source.
                // Re-parsing would turn stars, backticks and currency into markup.
                line.components(separatedBy: "\t").map { [[ $0 ]] as [[Any]] }
            }
            blocks.append(Self.tableBlock(rows: rows, header: false))
            body += table.html
            fallback += "\n\n" + table.tabSeparatedText
        }
        source = fallback
        nativeData = try JSONSerialization.data(withJSONObject: [
            "blocks": blocks, "action": "copy", "wasContiguousSelection": true
        ], options: [.sortedKeys, .withoutEscapingSlashes])
        chromiumData = Self.chromiumCustomData(
            type: Self.nativeMIMEType,
            value: String(decoding: nativeData, as: UTF8.self)
        )
        html = "<html><head><meta charset=\"utf-8\"></head><body>\(body)</body></html>"
    }

    private static func blocks(_ node: ClipboardHTMLTree.Node) -> [[String: Any]] {
        if node.tag == "ul" {
            return node.children.filter { $0.tag == "li" }.map {
                envelope(type: "bulleted_list", title: richText($0))
            }
        }
        if node.tag == "table" {
            let rows = descendants(node, tag: "tr")
            let cells = rows.map { row in
                row.children.filter { $0.tag == "th" || $0.tag == "td" }.map { richText($0) }
            }
            return [tableBlock(rows: cells, header: rows.first?.children.contains { $0.tag == "th" } == true)]
        }
        if node.tag == "p" {
            // The preview places standalone display math inside a paragraph.
            // Split it out without losing ordinary text on either side.
            var result: [[String: Any]] = []
            var inlineNodes: [ClipboardHTMLTree.Node] = []
            func flush() {
                guard !inlineNodes.isEmpty else { return }
                let paragraph = ClipboardHTMLTree.Node(tag: "p", children: inlineNodes)
                result.append(envelope(type: "text", title: richText(paragraph)))
                inlineNodes.removeAll()
            }
            for child in node.children {
                if child.tex != nil, child.attributes["data-display"] == "1" {
                    flush()
                    result.append(envelope(type: "equation", title: [[child.tex!]]))
                } else { inlineNodes.append(child) }
            }
            flush()
            return result
        }
        let type: String
        switch node.tag {
        case "h1": type = "header"
        case "h2": type = "sub_header"
        case "h3", "h4", "h5", "h6": type = "sub_sub_header"
        case "blockquote": type = "quote"
        case "pre": type = "code"
        default: type = node.tex != nil ? "equation" : "text"
        }
        return [envelope(type: type, title: node.tex.map { [[$0]] } ?? richText(node))]
    }

    private static func richText(_ node: ClipboardHTMLTree.Node, marks: [[String]] = []) -> [[Any]] {
        if let tex = node.tex { return [["‣", marks + [["e", tex]]]] }
        if let text = node.text {
            guard !text.isEmpty else { return [] }
            return [marks.isEmpty ? [text] : [text, marks]]
        }
        let mark: String?
        switch node.tag {
        case "strong": mark = "b"
        case "em": mark = "i"
        case "code": mark = "c"
        default: mark = nil
        }
        let next = mark.map { marks + [[$0]] } ?? marks
        return node.children.flatMap { richText($0, marks: next) }
    }

    private static func envelope(type: String, title: [[Any]]) -> [String: Any] {
        let id = UUID().uuidString.lowercased()
        return ["blockId": id, "blockSubtree": ["__version__": 3, "block": [
            id: ["value": value(id: id, type: type, properties: ["title": title])]
        ]]]
    }

    private static func value(id: String, type: String, properties: [String: Any]) -> [String: Any] {
        ["id": id, "type": type, "version": 1, "alive": true,
         "parent_table": "block", "properties": properties]
    }

    private static func tableBlock(rows: [[[[Any]]]], header: Bool) -> [String: Any] {
        let id = UUID().uuidString.lowercased()
        let width = rows.map(\.count).max() ?? 0
        let columns = (0..<width).map { "col\($0)" }
        var values: [String: Any] = [:]
        var rowIDs: [String] = []
        for cells in rows {
            let rowID = UUID().uuidString.lowercased()
            rowIDs.append(rowID)
            var properties: [String: Any] = [:]
            for (index, column) in columns.enumerated() {
                properties[column] = index < cells.count ? cells[index] : [[""]]
            }
            var row = value(id: rowID, type: "table_row", properties: properties)
            row["parent_id"] = id
            values[rowID] = ["value": row]
        }
        var table = value(id: id, type: "table", properties: [:])
        table["content"] = rowIDs
        table["format"] = ["table_block_column_order": columns, "table_block_header_row": header]
        values[id] = ["value": table]
        return ["blockId": id, "blockSubtree": ["__version__": 3, "block": values]]
    }

    private static func descendants(_ node: ClipboardHTMLTree.Node, tag: String) -> [ClipboardHTMLTree.Node] {
        node.children.flatMap { $0.tag == tag ? [$0] : descendants($0, tag: tag) }
    }

    private static func html(_ node: ClipboardHTMLTree.Node) throws -> String {
        if let tex = node.tex {
            guard let render = mathContext?.objectForKeyedSubscript("katex")?.objectForKeyedSubscript("renderToString"),
                  let rendered = render.call(withArguments: [tex, [
                    "displayMode": node.attributes["data-display"] == "1",
                    "output": "mathml", "throwOnError": false, "trust": false,
                    "maxExpand": 1000, "maxSize": 100
                  ]])?.toString(), !rendered.isEmpty else { throw CopyFormatError.pasteboardWriteFailed }
            return rendered
        }
        if let text = node.text { return MarkdownNormalizer.escapeHTML(text) }
        guard let tag = node.tag else { return "" }
        return "<\(tag)>\(try node.children.map(html).joined())</\(tag)>"
    }

    private static let mathContext: JSContext? = {
        guard let resource = AppResources.directoryURL?.appendingPathComponent("katex.min.js"),
              let script = try? String(contentsOf: resource, encoding: .utf8),
              let context = JSContext() else { return nil }
        context.evaluateScript(script)
        return context
    }()

    // Chromium DataTransfer custom MIME values use a Pickle: 32-bit payload
    // length, entry count, then length-prefixed UTF-16LE key/value strings,
    // each padded to a four-byte boundary. No workspace IDs or tokens needed.
    private static func chromiumCustomData(type: String, value: String) -> Data {
        func integer(_ number: Int) -> Data {
            var little = UInt32(number).littleEndian
            return withUnsafeBytes(of: &little) { Data($0) }
        }
        var payload = integer(1)
        for string in [type, value] {
            let units = Array(string.utf16)
            payload.append(integer(units.count))
            for unit in units {
                var little = unit.littleEndian
                withUnsafeBytes(of: &little) { payload.append(contentsOf: $0) }
            }
            while payload.count % 4 != 0 { payload.append(0) }
        }
        return integer(payload.count) + payload
    }
}

/// Parses only our generated, escaped fragment, never service-supplied HTML.
private final class ClipboardHTMLTree: NSObject, XMLParserDelegate {
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

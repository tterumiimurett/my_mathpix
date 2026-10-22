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
    static let chromiumType = ChromiumClipboardData.type

    let html: String
    let source: String
    let nativeData: Data
    let chromiumData: Data

    init(markdown: String, complexTableHTML: String?) throws {
        let canonical = MarkdownNormalizer.normalize(markdown)
        let root = try ClipboardHTMLTree.parse(MarkdownRenderer.renderBody(canonical, forClipboard: true))
        let layout = try TableOutputLayout(markdown: canonical, complexTableHTML: complexTableHTML, root: root)
        func complexBlocks(_ table: SafeComplexTable) throws -> [[String: Any]] {
            var result: [[String: Any]] = []
            if let caption = table.captionText { result.append(Self.envelope(type: "text", title: [[caption]])) }
            // Native Notion tables project occupied slots; the HTML fallback
            // retains the source rowspan/colspan structure.
            let rows = try table.cellHTML.map { row in
                try row.map { source -> [[Any]] in
                    let cell = try ClipboardHTMLTree.parse(source)
                    if let tex = layout.legacyEquation(cell) { return Self.equation(tex) }
                    return Self.richText(cell)
                }
            }
            let structure = try ClipboardHTMLTree.parse(table.html)
            let header = Self.descendants(structure, tag: "tr").first?.children.contains { $0.tag == "th" } == true
            result.append(Self.tableBlock(rows: rows, header: header))
            return result
        }
        var blocks: [[String: Any]] = []
        for node in root.children where node.tag != nil {
            if node === layout.repeatedCaption { continue }
            if node === layout.replacement, let table = layout.table { blocks += try complexBlocks(table) }
            else { blocks += Self.blocks(node) }
        }
        if layout.replacement == nil, let table = layout.table { blocks += try complexBlocks(table) }
        let body = try layout.renderedBody(renderNode: Self.html, renderTable: { $0.html })
        source = layout.sourceFallback(markdown)
        nativeData = try JSONSerialization.data(withJSONObject: [
            "blocks": blocks, "action": "copy", "wasContiguousSelection": true
        ], options: [.sortedKeys, .withoutEscapingSlashes])
        chromiumData = ChromiumClipboardData.encode(
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
        if let tex = node.tex { return equation(tex, marks: marks) }
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

    private static func equation(_ tex: String, marks: [[String]] = []) -> [[Any]] {
        // Notion's native equation character is U+204D, distinct from the
        // visually similar U+2023 bullet, which pastes as ordinary text.
        [["⁍", marks + [["e", tex]]]]
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

}

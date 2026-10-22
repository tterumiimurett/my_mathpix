import Foundation

/// Version-dependent native clipboard format observed in Lark's own synthetic
/// copy. Every identity is generated locally; no workspace or account metadata.
struct LarkNativeClipboardDocument {
    let chromiumData: Data
    let htmlMarker: String

    init(markdown: String, complexTableHTML: String?) throws {
        let root = try ClipboardHTMLTree.parse(MarkdownRenderer.renderBody(markdown, forClipboard: true))
        let layout = try TableOutputLayout(markdown: markdown, complexTableHTML: complexTableHTML, root: root)
        let data = try JSONSerialization.data(withJSONObject: LarkRecordBuilder(layout: layout).document(), options: [.sortedKeys, .withoutEscapingSlashes])
        let json = String(decoding: data, as: UTF8.self)
        chromiumData = ChromiumClipboardData.encode(type: "docx/record", value: json)
        htmlMarker = "<span data-lark-record-data=\"\(MarkdownNormalizer.escapeHTML(json))\" data-lark-record-format=\"docx/record\" class=\"lark-record-clipboard\" style=\"display:none\"></span>"
    }
}

private final class LarkRecordBuilder {
    private struct Run {
        let text: String
        var attributes: [[String]] = []
    }
    private let layout: TableOutputLayout
    private let rootID = UUID().uuidString.lowercased()
    private var records: [String: Any] = [:]

    init(layout: TableOutputLayout) { self.layout = layout }

    func document() throws -> [String: Any] {
        var selected: [String] = []
        for node in layout.root.children where node.tag != nil {
            if node === layout.repeatedCaption { continue }
            if node === layout.replacement, let table = layout.table { selected += try complexTable(table) }
            else { selected += try blocks(node, parent: rootID) }
        }
        if layout.replacement == nil, let table = layout.table { selected += try complexTable(table) }
        records[rootID] = ["id": rootID, "snapshot": ["type": "page", "parent_id": "", "children": selected,
            "text": attributedText([]), "locked": false, "hidden": false, "align": ""]]
        return ["isCut": false, "rootId": rootID, "parentId": rootID,
                "blockIds": selected.indices.map { $0 + 1 }, "recordIds": selected, "recordMap": records, "payloadMap": [:],
                "selection": selected.enumerated().map { ["id": $0.offset + 1, "type": "block", "recordId": $0.element] as [String: Any] },
                "extra": ["channel": "saas"], "pasteFlag": UUID().uuidString.lowercased()]
    }

    @discardableResult
    private func save(_ snapshot: [String: Any], id: String = UUID().uuidString.lowercased()) -> String {
        records[id] = ["id": id, "snapshot": snapshot]; return id
    }

    private func paragraph(_ runs: [Run], parent: String, type: String = "text", extra: [String: Any] = [:]) -> String {
        var snapshot: [String: Any] = ["type": type, "children": [], "text": attributedText(runs), "folded": false, "parent_id": parent]
        snapshot.merge(extra) { _, new in new }
        return save(snapshot)
    }

    private func blocks(_ node: ClipboardHTMLTree.Node, parent: String) throws -> [String] {
        if node.tag == "table" { return [try table(node, parent: parent)] }
        if node.tag == "ul" {
            return node.children.filter { $0.tag == "li" }.map { paragraph(runs($0), parent: parent, type: "bullet", extra: ["level": 1]) }
        }
        if node.tag == "blockquote" {
            let id = UUID().uuidString.lowercased()
            let text = paragraph(runs(node), parent: id)
            return [save(["type": "quote_container", "parent_id": parent, "children": [text]], id: id)]
        }
        if node.tag == "pre" {
            return [paragraph([Run(text: literalText(node))], parent: parent, type: "code", extra: ["language": "Plain Text", "wrap": false])]
        }
        let heading = node.tag.flatMap { tag in ["h1", "h2", "h3", "h4", "h5", "h6"].contains(tag) ? "heading" + tag.dropFirst() : nil }
        return [paragraph(runs(node), parent: parent, type: heading ?? "text")]
    }

    private func complexTable(_ safe: SafeComplexTable) throws -> [String] {
        var result: [String] = []
        if let caption = safe.captionText { result.append(paragraph([Run(text: caption)], parent: rootID)) }
        let tree = try ClipboardHTMLTree.parse(safe.previewHTML)
        guard let node = tree.children.first(where: { $0.tag == "table" }) else { throw CopyFormatError.pasteboardWriteFailed }
        result.append(try table(node, parent: rootID, preferred: layout.replacement))
        return result
    }

    private func table(_ node: ClipboardHTMLTree.Node, parent: String, preferred: ClipboardHTMLTree.Node? = nil) throws -> String {
        let sourceRows = descendants(node, tag: "tr")
        let preferredRows = preferred.map { descendants($0, tag: "tr").map { $0.children.filter { $0.tag == "td" || $0.tag == "th" } } } ?? []
        struct Cell { let node: ClipboardHTMLTree.Node; let rowSpan: Int; let colSpan: Int }
        var anchors: [Int: [Int: Cell]] = [:], occupied: [Int: Int] = [:], width = 0
        for (r, row) in sourceRows.enumerated() {
            occupied = occupied.filter { $0.value > r }
            var c = 0
            for cell in row.children where cell.tag == "td" || cell.tag == "th" {
                let cs = min(100, max(1, Int(cell.attributes["colspan"] ?? "1") ?? 1))
                let rs = min(sourceRows.count - r, min(100, max(1, Int(cell.attributes["rowspan"] ?? "1") ?? 1)))
                while (c..<(c + cs)).contains(where: { occupied[$0] != nil }) { c += 1 }
                anchors[r, default: [:]][c] = Cell(node: cell, rowSpan: rs, colSpan: cs)
                for column in c..<(c + cs) { occupied[column] = r + rs }
                c += cs; width = max(width, c)
            }
        }
        guard width > 0, !sourceRows.isEmpty, width * sourceRows.count <= 10_000 else { throw CopyFormatError.pasteboardWriteFailed }
        let id = UUID().uuidString.lowercased()
        let rows = sourceRows.indices.map { _ in "row" + UUID().uuidString.replacingOccurrences(of: "-", with: "") }
        let cols = (0..<width).map { _ in "col" + UUID().uuidString.replacingOccurrences(of: "-", with: "") }
        var children: [String] = [], cells: [String: Any] = [:]
        for r in rows.indices { for c in cols.indices {
            let cellID = UUID().uuidString.lowercased()
            let anchor = anchors[r]?[c]
            var content: [Run] = []
            if let anchor {
                if let tex = layout.legacyEquation(anchor.node) { content = [equation(tex)] }
                else if r < preferredRows.count, c < preferredRows[r].count,
                        descendants(anchor.node, tag: "span").allSatisfy({ $0.tex == nil }) {
                    // Reuse the matching source's cleaned cells and genuine
                    // formula tokens while retaining the rich table geometry.
                    content = runs(preferredRows[r][c])
                } else { content = runs(anchor.node) }
                if anchor.node.tag == "th" { content = content.map { Run(text: $0.text, attributes: $0.attributes + [["bold", "true"]]) } }
            }
            let textID = paragraph(content, parent: cellID)
            save(["type": "table_cell", "children": [textID], "parent_id": id, "align": "left"], id: cellID)
            children.append(cellID)
            cells[rows[r] + cols[c]] = ["block_id": cellID, "merge_info": ["row_span": anchor?.rowSpan ?? 1, "col_span": anchor?.colSpan ?? 1]]
        } }
        return save(["type": "table", "parent_id": parent, "children": children, "columns_id": cols, "rows_id": rows,
                     "column_set": Dictionary(uniqueKeysWithValues: cols.map { ($0, ["column_width": 200]) }), "cell_set": cells], id: id)
    }

    private func equation(_ tex: String, marks: [[String]] = []) -> Run {
        Run(text: " ", attributes: marks + [["equation", tex], ["objectID", String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8))]])
    }

    private func runs(_ node: ClipboardHTMLTree.Node, marks: [[String]] = []) -> [Run] {
        if let tex = node.tex { return [equation(tex, marks: marks)] }
        if let text = node.text { return [Run(text: text, attributes: marks)] }
        let mark = ["strong": "bold", "em": "italic", "code": "inlineCode"][node.tag ?? ""]
        let next = mark.map { marks + [[$0, "true"]] } ?? marks
        return node.children.flatMap { runs($0, marks: next) }
    }

    private func attributedText(_ runs: [Run]) -> [String: Any] {
        var text = "", attribution = "", pool: [String: [String]] = [:], lookup: [String: Int] = [:]
        for run in runs where !run.text.isEmpty {
            var prefix = ""
            for pair in run.attributes {
                let key = pair.joined(separator: ",")
                let index: Int
                if let existing = lookup[key] { index = existing }
                else { index = pool.count; lookup[key] = index; pool[String(index)] = pair }
                prefix += "*" + String(index, radix: 36)
            }
            let lines = run.text.split(separator: "\n", omittingEmptySubsequences: false)
            for (i, line) in lines.enumerated() {
                let segment = String(line) + (i < lines.count - 1 ? "\n" : "")
                guard !segment.isEmpty else { continue }
                text += segment
                attribution += prefix + (segment.hasSuffix("\n") ? "|1" : "") + "+" + String(segment.utf16.count, radix: 36)
            }
        }
        return ["initialAttributedTexts": ["text": ["0": text], "attribs": ["0": attribution], "rows": [:], "cols": [:]],
                "apool": ["numToAttrib": pool, "nextNum": pool.count, "attribToNum": lookup]]
    }

    private func descendants(_ node: ClipboardHTMLTree.Node, tag: String) -> [ClipboardHTMLTree.Node] {
        node.children.flatMap { $0.tag == tag ? [$0] : descendants($0, tag: tag) }
    }

    private func literalText(_ node: ClipboardHTMLTree.Node) -> String {
        node.text ?? node.children.map(literalText).joined()
    }
}

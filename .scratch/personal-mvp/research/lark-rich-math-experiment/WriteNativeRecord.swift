import AppKit
import Foundation

// Self-contained synthetic native clipboard experiment. No owner/workspace IDs,
// URL/source metadata, credentials, file reads, API calls, or UI automation.
func fresh() -> String { UUID().uuidString.lowercased() }
func escape(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
}
let root = fresh()
var records: [String: Any] = [:]
func record(_ snapshot: [String: Any]) -> String {
    let id = fresh(); records[id] = ["id": id, "snapshot": snapshot]; return id
}
func rich(_ runs: [(String, String?)]) -> [String: Any] {
    var text = "", attributes = "", pool: [String: [String]] = [:], lookup: [String: Int] = [:]
    var index = 0
    for (source, tex) in runs {
        if let tex {
            let object = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8))
            pool[String(index)] = ["equation", tex]; lookup["equation," + tex] = index
            pool[String(index + 1)] = ["objectID", object]; lookup["objectID," + object] = index + 1
            text += " "; attributes += "*\(String(index, radix: 36))*\(String(index + 1, radix: 36))+1"; index += 2
        } else if !source.isEmpty {
            text += source; attributes += "+" + String(source.utf16.count, radix: 36)
        }
    }
    return ["initialAttributedTexts": ["text": ["0": text], "attribs": ["0": attributes], "rows": [:], "cols": [:]],
            "apool": ["numToAttrib": pool, "nextNum": index, "attribToNum": lookup]]
}
func paragraph(_ runs: [(String, String?)], parent: String) -> String {
    record(["type": "text", "children": [], "text": rich(runs), "folded": false, "parent_id": parent])
}
let begin = paragraph([("TCASE RECORD_MIME BEGIN", nil)], parent: root)
let before = paragraph([("Before ", nil), ("", "x^2"), (" and ", nil), ("", #"\frac{a}{b}"#), (".", nil)], parent: root)
let tableID = fresh()
let cols = ["col0", "col1", "col2"], rows = ["row0", "row1", "row2"]
let content: [[[(String, String?)]]] = [
    [[("Group", nil)], [("", nil)], [("Formula", nil)]],
    [[("Keep literal code $5 and $10", nil)], [("Y", nil)], [("", "u^2 + v^2")]],
    [[("", nil)], [("Z", nil)], [("", #"\frac{1}{2}"#)]]
]
var cells: [String: Any] = [:], children: [String] = []
for r in 0..<3 { for c in 0..<3 {
    let cellID = fresh()
    let textID = paragraph(content[r][c], parent: cellID)
    records[cellID] = ["id": cellID, "snapshot": ["type": "table_cell", "children": [textID], "parent_id": tableID, "align": "left"]]
    children.append(cellID)
    cells[rows[r] + cols[c]] = ["block_id": cellID, "merge_info": ["row_span": 1, "col_span": r == 0 && c == 0 ? 2 : 1]]
} }
records[tableID] = ["id": tableID, "snapshot": ["type": "table", "parent_id": root, "children": children,
    "columns_id": cols, "rows_id": rows, "column_set": Dictionary(uniqueKeysWithValues: cols.map { ($0, ["column_width": 200]) }), "cell_set": cells]]
let end = paragraph([("TCASE RECORD_MIME END", nil)], parent: root)
let selected = [begin, before, tableID, end]
records[root] = ["id": root, "snapshot": ["type": "page", "parent_id": "", "children": selected, "text": rich([]), "locked": false, "hidden": false, "align": ""]]
let payload: [String: Any] = ["isCut": false, "rootId": root, "parentId": root,
    "blockIds": Array(1...selected.count), "recordIds": selected, "recordMap": records, "payloadMap": [:],
    "selection": selected.enumerated().map { ["id": $0.offset + 1, "type": "block", "recordId": $0.element] as [String: Any] },
    "extra": ["channel": "saas"], "pasteFlag": fresh()]
let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .withoutEscapingSlashes])
let metadata = escape(String(decoding: data, as: UTF8.self))
let html = "<meta charset=\"utf-8\"><div>TCASE RECORD_MIME BEGIN</div><div>Before $x^2$.</div><div>TCASE RECORD_MIME END</div>"
    + "<span data-lark-record-data=\"\(metadata)\" data-lark-record-format=\"docx/record\" class=\"lark-record-clipboard\" style=\"display:none\"></span>"
let item = NSPasteboardItem()
item.setString("TCASE RECORD_MIME BEGIN\nBefore $x^2$.\nTCASE RECORD_MIME END", forType: .string)
item.setString(html, forType: .html)
func integer(_ number: Int) -> Data {
    var value = UInt32(number).littleEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
var custom = integer(1)
for value in ["docx/record", String(decoding: data, as: UTF8.self)] {
    let units = Array(value.utf16); custom.append(integer(units.count))
    for unit in units { var little = unit.littleEndian; withUnsafeBytes(of: &little) { custom.append(contentsOf: $0) } }
    while custom.count % 4 != 0 { custom.append(0) }
}
item.setData(integer(custom.count) + custom, forType: .init("org.chromium.web-custom-data"))
NSPasteboard.general.clearContents()
guard NSPasteboard.general.writeObjects([item]) else { exit(2) }
print("LARK_SYNTHETIC_RECORD_COPIED records=\(records.count) external_ids=0")

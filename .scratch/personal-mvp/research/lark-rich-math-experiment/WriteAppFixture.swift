import AppKit
import Foundation

// Clipboard data only; refuses input outside the captured synthetic App fixture.
guard CommandLine.arguments.count == 3,
      ["baseline", "double", "document", "equation", "document_double", "native"].contains(CommandLine.arguments[1]),
      let input = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))) as? [String: Any],
      input["fixture"] as? String == "APP-RICH",
      let formats = input["formats"] as? [String: String],
      let source = formats["public.utf8-plain-text"], source.hasPrefix("$$y = x + 1$$"),
      source.contains("RICH MIX END"), source.contains("RICH merged caption α"), source.utf8.count < 20_000,
      var html = formats["public.html"], html.utf8.count < 200_000,
      html.components(separatedBy: "<table>").count == 2 else { exit(2) }
let variant = CommandLine.arguments[1]
if variant == "double" || variant == "document_double" {
    for tex in ["z_0", "u^2 + v^2", #"\frac{1}{2}"#] {
        html = html.replacingOccurrences(of: "$" + tex + "$", with: "$$" + tex + "$$")
    }
}
if ["document", "equation", "document_double", "native"].contains(variant) {
    html = html.replacingOccurrences(of: "<table>", with: "<table class=\"ace-table\" data-ace-table-col-widths=\"200;200;200\">")
}
if variant == "equation" || variant == "native" {
    func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }
    for tex in ["u^2 + v^2", #"\frac{1}{2}"#] {
        let blockID = variant == "native" ? UUID().uuidString.lowercased() : "doxcn" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(22)
        let delimiter = variant == "native" ? "$$" : "$"
        let props: [String: Any] = ["blockId": blockID,
            "blockType": "EQUATION_BLOCK", "initData": [String: String](),
            "props": ["data": ["equation": tex], "displayMode": "inline", "viewType": "inline"]]
        let data = try JSONSerialization.data(withJSONObject: props, options: [.sortedKeys, .withoutEscapingSlashes])
        let metadata = escape(String(decoding: data, as: UTF8.self))
        html = html.replacingOccurrences(of: "$" + tex + "$", with: "<span data-meta-block-props=\"\(metadata)\">\(escape(delimiter + tex + delimiter))</span>")
    }
}
let marker = "TCASE " + variant.uppercased()
html = html.replacingOccurrences(of: "<body>", with: "<body><p>\(marker) BEGIN</p>")
    .replacingOccurrences(of: "</body>", with: "<p>\(marker) END</p></body>")
let item = NSPasteboardItem()
item.setString(marker + " BEGIN\n\n" + source + "\n\n" + marker + " END", forType: .string)
item.setString(html, forType: .html)
NSPasteboard.general.clearContents()
guard NSPasteboard.general.writeObjects([item]) else { exit(3) }
print("LARK_KNOWN_FIXTURE_COPIED variant=\(variant) html_tables=1 source_math_unchanged=yes")

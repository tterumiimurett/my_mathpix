import AppKit

let format = CommandLine.arguments[1]
let source = """
$$e^{i\\pi} = -1$$

| <b>Symbol</b> | Meaning |
| --- | --- |
| <strong>A &amp; B</strong> | **bold** &alpha; and a deliberately long cell that ends with COMPLETE-CELL-END |
| <code>**literal**</code> | a < b > c |
"""
let plain = "Symbol\tMeaning\nA & B\tbold α and a deliberately long cell that ends with COMPLETE-CELL-END\n**literal**\ta < b > c"
let board = NSPasteboard.general
switch format {
case "markdown", "combinedOutput":
    precondition(board.string(forType: .string) == source)
case "tsvTable", "richTable":
    precondition(board.string(forType: .string) == plain)
    precondition(board.string(forType: .tabularText) == plain)
    if format == "richTable" {
        let html = board.string(forType: .html)!
        precondition(html.contains("<td>A &amp; B</td>") && html.contains("<td>**literal**</td>"))
        let rtf = board.data(forType: .rtf)!
        let text = try NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil).string
        precondition(text.contains("A & B") && text.contains("**literal**") && text.contains("COMPLETE-CELL-END"))
    } else {
        precondition(!(board.types ?? []).contains(.html) && !(board.types ?? []).contains(.rtf))
    }
default: fatalError("Unknown fixture format")
}
print("CONTENT_ROW_COPY_OK format=\(format) full_content=yes public_types=yes literal_code=yes")

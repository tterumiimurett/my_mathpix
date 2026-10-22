import AppKit
import Foundation

// Writes only our exported synthetic fixture. UI paste is driven separately.
// No clipboard reads, history, credentials, network or destination APIs.
let raw = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
guard raw.count < 500_000,
      let fixture = try JSONSerialization.jsonObject(with: raw) as? [String: String],
      let source = fixture["source"], let html = fixture["html"],
      var native = fixture["native"],
      source == "Before $x^2$." || source.contains("RICH MIX BEGIN") else {
    print("REFUSED: not an exported synthetic fixture")
    exit(2)
}
let corrected = CommandLine.arguments.dropFirst(2).contains("--correct-equation-marker")
if corrected { native = native.replacingOccurrences(of: "\"‣\"", with: "\"⁍\"") }
func integer(_ number: Int) -> Data {
    var value = UInt32(number).littleEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
var payload = integer(1)
for string in ["text/_notion-blocks-v3-production", native] {
    let units = Array(string.utf16)
    payload.append(integer(units.count))
    for unit in units {
        var value = unit.littleEndian
        withUnsafeBytes(of: &value) { payload.append(contentsOf: $0) }
    }
    while payload.count % 4 != 0 { payload.append(0) }
}
let item = NSPasteboardItem()
let values: [NSPasteboard.PasteboardType: Data] = [
    .string: Data(source.utf8), .html: Data(html.utf8),
    .init("com.byterumi.mymathpix.notion-blocks-v3"): Data(native.utf8),
    .init("org.chromium.web-custom-data"): integer(payload.count) + payload
]
for (type, value) in values {
    guard item.setData(value, forType: type) else { exit(3) }
}
let board = NSPasteboard.general
board.clearContents()
guard board.writeObjects([item]) else { exit(4) }
print("FIXTURE_COPY_WRITTEN variant=\(corrected ? "corrected-marker" : "original") representations=4")

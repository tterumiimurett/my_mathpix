import AppKit
import Foundation

// Data inspection only: no UI automation, clipboard mutation, history access,
// network, credentials or Notion API. Refuses any clipboard outside our fixture.
let board = NSPasteboard.general
let changeCount = board.changeCount
guard let plain = board.string(forType: .string),
      plain.contains("NREF BEGIN"), plain.contains("NREF END"),
      plain.contains("NREF Item"), plain.utf8.count < 10_000 else {
    print("REFUSED: current clipboard is not the bounded NREF fixture")
    exit(2)
}
func readCustom(_ data: Data?) -> [String: String] {
    guard let data, data.count < 1_000_000 else { return [:] }
    let bytes = Array(data)
    var offset = 0
    func integer() -> Int? {
        guard offset + 4 <= bytes.count else { return nil }
        defer { offset += 4 }
        return (0..<4).reduce(0) { $0 | (Int(bytes[offset + $1]) << (8 * $1)) }
    }
    func string() -> String? {
        guard let count = integer(), count <= (bytes.count - offset) / 2 else { return nil }
        let start = offset
        offset += count * 2
        let value = String(data: Data(bytes[start..<offset]), encoding: .utf16LittleEndian)
        offset = (offset + 3) & ~3
        return value
    }
    guard integer() == bytes.count - 4, let count = integer(), count < 100 else { return [:] }
    var entries: [String: String] = [:]
    for _ in 0..<count {
        guard let key = string(), let value = string() else { return [:] }
        if key.hasPrefix("text/_notion-") { entries[key] = value }
    }
    return offset == bytes.count ? entries : [:]
}
let custom = readCustom(board.data(forType: .init("org.chromium.web-custom-data")))
var formats: [String: String] = [:]
for type in [NSPasteboard.PasteboardType.string, .html] {
    if let text = board.string(forType: type), text.utf8.count < 200_000 {
        formats[type.rawValue] = text
    }
}
let uuid = try NSRegularExpression(pattern: "[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}", options: .caseInsensitive)
var identities: [String: String] = [:]
func anonymize(_ text: String) -> String {
    var result = text
    for match in uuid.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
        guard let range = Range(match.range, in: text) else { continue }
        let original = String(text[range])
        if identities[original] == nil {
            identities[original] = String(format: "00000000-0000-4000-8000-%012d", identities.count + 1)
        }
        guard let target = Range(match.range, in: result) else { continue }
        result.replaceSubrange(target, with: identities[original]!)
    }
    return result
}
let result: [String: Any] = [
    "fixture": "NREF", "types": (board.types ?? []).map(\.rawValue),
    "formats": formats.mapValues(anonymize),
    "notionCustomData": custom.mapValues(anonymize),
    "clipboardChanged": false
]
guard board.changeCount == changeCount else {
    print("REFUSED: clipboard changed during fixture inspection")
    exit(3)
}
let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("NREF_FORMATS_CAPTURED types=\(board.types?.count ?? 0) characters=\(plain.count)")

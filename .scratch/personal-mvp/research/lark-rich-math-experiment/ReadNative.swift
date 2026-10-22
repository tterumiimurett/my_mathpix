import AppKit
import Foundation

let board = NSPasteboard.general
let version = board.changeCount
guard let text = board.string(forType: .string), text.contains("TREF BEGIN"),
      text.contains("TREF END"), text.contains("TCASE DOUBLE END"), text.utf8.count < 50_000,
      let html = board.string(forType: .html), html.utf8.count < 2_000_000 else {
    fputs("REFUSED: clipboard is outside the bounded Lark synthetic test\n", stderr); exit(2)
}
guard version == board.changeCount else { exit(3) }
// Raw native HTML goes directly through a pipe to InspectNative.py; never save
// or print it in the tool result. The receiver removes IDs/opaque metadata.
var customKeys: [String] = []
if let custom = board.data(forType: .init("org.chromium.web-custom-data")) {
    let bytes = Array(custom); var offset = 0
    func integer() -> Int? {
        guard offset + 4 <= bytes.count else { return nil }; defer { offset += 4 }
        return (0..<4).reduce(0) { $0 | (Int(bytes[offset + $1]) << (8 * $1)) }
    }
    func string() -> String? {
        guard let length = integer(), length <= (bytes.count - offset) / 2 else { return nil }
        let start = offset; offset += length * 2
        let result = String(data: Data(bytes[start..<offset]), encoding: .utf16LittleEndian)
        offset = (offset + 3) & ~3; return result
    }
    if integer() == bytes.count - 4, let count = integer(), count < 50 {
        for _ in 0..<count { guard let key = string(), string() != nil else { break }; customKeys.append(key) }
    }
}
let data = try JSONSerialization.data(withJSONObject: ["types": (board.types ?? []).map(\.rawValue), "html": html, "customKeys": customKeys])
FileHandle.standardOutput.write(data)

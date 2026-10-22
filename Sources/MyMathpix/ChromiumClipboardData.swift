import AppKit
import Foundation

enum ChromiumClipboardData {
    static let type = NSPasteboard.PasteboardType("org.chromium.web-custom-data")

    /// Chromium's length-prefixed UTF-16LE Pickle, aligned to four-byte boundaries.
    static func encode(type: String, value: String) -> Data {
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

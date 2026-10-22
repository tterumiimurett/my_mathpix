import Foundation

// Throwaway fixture exporter: production adapter sources compile unchanged.
// Does not access the system pasteboard, credentials, or app history.
enum AppResources {
    static var directoryURL: URL? {
        URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    }
}
enum CopyFormatError: Error { case pasteboardWriteFailed }

@main
struct GenerateFixture {
    @MainActor static func main() throws {
        let input: [String: String]
        if CommandLine.arguments.count > 3 {
            let raw = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3]))
            input = try JSONDecoder().decode([String: String].self, from: raw)
        } else { input = ["markdown": "Before $x^2$."] }
        let source = input["markdown"] ?? "Before $x^2$."
        let baseline = try NotionClipboardDocument(markdown: source, complexTableHTML: input["complexTableHTML"])
        let literalMath = LarkClipboardDocument(markdown: source, complexTableHTML: input["complexTableHTML"])
        let data = try JSONSerialization.data(withJSONObject: [
            "source": baseline.source,
            "literalHTML": literalMath.html,
            "literalSource": literalMath.source,
            "html": baseline.html,
            "native": String(decoding: baseline.nativeData, as: UTF8.self),
            "chromiumBase64": baseline.chromiumData.base64EncodedString()
        ], options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
    }
}

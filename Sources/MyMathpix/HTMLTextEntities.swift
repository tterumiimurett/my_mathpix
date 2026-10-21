import Foundation

/// Decode entity tokens only, in one pass. Never interpret their surrounding
/// text as Markdown or turn the decoded result back into executable markup.
enum HTMLTextEntities {
    private static let pattern = try! NSRegularExpression(
        pattern: #"&(?:#[xX][0-9a-fA-F]+|#[0-9]+|[A-Za-z][A-Za-z0-9]+);"#
    )

    static func decode(_ text: String) -> String {
        var result = text
        for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: result),
                  let decoded = try? AttributedString(
                    markdown: String(result[range]),
                    options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                  ) else { continue }
            result.replaceSubrange(range, with: String(decoded.characters))
        }
        return result
    }
}

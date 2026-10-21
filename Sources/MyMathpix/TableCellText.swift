import Foundation

/// Plain-text projection for a table cell. Only recognized formatting tags are
/// consumed; literal comparisons, escaped markup, code and math stay content.
enum TableCellText {
    /// Datalab may wrap a whole header in HTML emphasis even though GFM
    /// already makes it a header. Peel only that inert wrapper; inline code,
    /// math, attributes and all other raw HTML keep their existing treatment.
    static func previewHeaderSource(_ source: String) -> String {
        let wrapper = try! NSRegularExpression(pattern: #"(?is)^\s*<(b|strong)>(.*?)</\1>\s*$"#)
        var result = source
        while let match = wrapper.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)),
              let content = Range(match.range(at: 2), in: result) {
            result = String(result[content])
        }
        return result
    }

    static func plainText(_ source: String) -> String {
        let characters = Array(source)
        var markdown = ""
        var protectedContent: [(String, String)] = []
        var marker = "MMPCELLTOKEN"
        while source.contains(marker) { marker += "X" }
        var index = 0
        while index < characters.count {
            if characters[index] == "\\", index + 1 < characters.count {
                markdown += String(characters[index...index + 1])
                index += 2
                continue
            }
            if characters[index] == "`" || characters[index] == "$" {
                let delimiter = characters[index]
                var start = index
                while start < characters.count, characters[start] == delimiter { start += 1 }
                let length = start - index
                var end = start
                var closing: Int?
                while end < characters.count {
                    if delimiter == "$", characters[end] == "\\" { end += 2; continue }
                    if characters[end] == delimiter {
                        var next = end
                        while next < characters.count, characters[next] == delimiter { next += 1 }
                        if next - end == length { closing = next; break }
                        end = next
                    } else { end += 1 }
                }
                if let closing {
                    let content = String(characters[index..<closing])
                    if delimiter == "$" {
                        let key = "\(marker)\(protectedContent.count)END"
                        protectedContent.append((key, content))
                        markdown += key
                    } else {
                        markdown += content
                    }
                    index = closing
                    continue
                }
            }
            if characters[index] == "<", let tag = formattingTag(in: characters, from: index) {
                if tag.name == "code", characters[index + 1] != "/" {
                    var cursor = tag.end
                    while cursor < characters.count {
                        if characters[cursor] == "<", cursor + 1 < characters.count,
                           characters[cursor + 1] == "/",
                           let closing = formattingTag(in: characters, from: cursor), closing.name == "code" {
                            let key = "\(marker)\(protectedContent.count)END"
                            protectedContent.append((key, HTMLTextEntities.decode(String(characters[tag.end..<cursor]))))
                            markdown += key
                            index = closing.end
                            break
                        }
                        cursor += 1
                    }
                    if index >= tag.end { continue }
                }
                if ["br", "p", "div"].contains(tag.name) { markdown += " " }
                index = tag.end
                continue
            }
            markdown.append(characters[index])
            index += 1
        }
        var text = (try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )).map { String($0.characters) } ?? markdown
        for (key, content) in protectedContent { text = text.replacingOccurrences(of: key, with: content) }
        // A TSV record must keep one physical line per row and one tab per cell boundary.
        return text.replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }


    private static let formattingTags: Set<String> = [
        "b", "strong", "i", "em", "u", "s", "strike", "del", "sup", "sub",
        "small", "mark", "span", "a", "code", "br", "p", "div"
    ]

    private static func formattingTag(in characters: [Character], from start: Int) -> (name: String, end: Int)? {
        var cursor = start + 1
        if cursor < characters.count, characters[cursor] == "/" { cursor += 1 }
        let nameStart = cursor
        while cursor < characters.count, characters[cursor].isASCII, characters[cursor].isLetter { cursor += 1 }
        let name = String(characters[nameStart..<cursor]).lowercased()
        guard formattingTags.contains(name), cursor < characters.count,
              characters[cursor].isWhitespace || characters[cursor] == "/" || characters[cursor] == ">" else { return nil }
        var quote: Character?
        while cursor < characters.count {
            let character = characters[cursor]
            if let current = quote {
                if character == current { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == ">" {
                return (name, cursor + 1)
            } else if character == "<" {
                return nil
            }
            cursor += 1
        }
        return nil
    }
}

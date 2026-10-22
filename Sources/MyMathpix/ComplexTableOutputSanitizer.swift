import Foundation

struct SafeComplexTable: Equatable {
    let html: String
    let tabSeparatedText: String

    var captionText: String? {
        guard let start = html.range(of: "<caption>"),
              let end = html.range(of: "</caption>", range: start.upperBound..<html.endIndex) else { return nil }
        return HTMLTextEntities.decode(String(html[start.upperBound..<end.lowerBound]))
    }

    func isRepresented(in markdown: String) -> Bool {
        // Plain text equality cannot account for merged cells or captions.
        guard !html.contains("<caption>"),
              html.range(of: #"(?:rowspan|colspan)=\"(?:[2-9]|[1-9][0-9]+)\""#, options: .regularExpression) == nil else { return false }
        return MarkdownNormalizer.markdownTableTSVs(from: markdown).contains(tabSeparatedText)
    }
}

enum ComplexTableOutputSanitizer {
    private static let maximumInputBytes = 1_000_000
    private static let allowedTags: Set<String> = [
        "table", "caption", "colgroup", "col", "thead", "tbody", "tfoot", "tr", "th", "td"
    ]
    private static let suppressedContainerTags: Set<String> = [
        "script", "style", "iframe", "object", "embed", "svg", "math", "form", "template", "noscript"
    ]
    private static let discardedVoidTags: Set<String> = [
        "img", "link", "meta", "base", "input", "source", "video", "audio"
    ]

    static func sanitize(_ rawHTML: String) -> SafeComplexTable? {
        guard !rawHTML.isEmpty, rawHTML.utf8.count <= maximumInputBytes else { return nil }
        let tokenPattern = try! NSRegularExpression(pattern: #"<[^>]*>"#)
        let matches = tokenPattern.matches(
            in: rawHTML,
            range: NSRange(rawHTML.startIndex..., in: rawHTML)
        )

        var output = ""
        var cursor = rawHTML.startIndex
        var emittedStack: [String] = []
        var suppressedStack: [String] = []
        var isInsideTable = false
        var completedTable = false
        var emittedRow = false
        var emittedCell = false

        func appendText(_ text: Substring) {
            guard isInsideTable, suppressedStack.isEmpty, !text.isEmpty else { return }
            output += MarkdownNormalizer.escapeHTML(HTMLTextEntities.decode(String(text)))
        }

        func closeTop() {
            guard let tag = emittedStack.popLast(), tag != "col" else { return }
            output += "</\(tag)>"
        }

        for (index, match) in matches.enumerated() {
            guard let range = Range(match.range, in: rawHTML), range.lowerBound >= cursor else { continue }
            appendText(rawHTML[cursor..<range.lowerBound])
            cursor = range.upperBound

            guard let token = parseTag(String(rawHTML[range])) else { continue }

            if !suppressedStack.isEmpty {
                if token.isClosing, token.name == suppressedStack.last {
                    suppressedStack.removeLast()
                } else if !token.isClosing,
                          !token.isSelfClosing,
                          (suppressedContainerTags.contains(token.name) || token.name == "table") {
                    suppressedStack.append(token.name)
                }
                continue
            }

            if !isInsideTable {
                guard !completedTable, !token.isClosing, token.name == "table" else { continue }
                output = "<table>"
                emittedStack = ["table"]
                isInsideTable = true
                continue
            }

            if token.name == "table" {
                if token.isClosing {
                    while emittedStack.last != "table", !emittedStack.isEmpty { closeTop() }
                    guard emittedStack.last == "table" else { return nil }
                    closeTop()
                    isInsideTable = false
                    completedTable = true
                    break
                }
                suppressedStack.append("table")
                continue
            }

            // Hosted Convert HTML uses a text-only <math>TeX</math> form.
            // Preserve that inert source, never attributes or nested markup.
            // Unknown MathML continues through the suppression rule below.
            if token.name == "math", !token.isClosing, !token.isSelfClosing,
               emittedStack.last == "td" || emittedStack.last == "th",
               index + 1 < matches.count,
               let closingRange = Range(matches[index + 1].range, in: rawHTML),
               let closing = parseTag(String(rawHTML[closingRange])),
               closing.name == "math", closing.isClosing {
                let tex = HTMLTextEntities.decode(String(rawHTML[range.upperBound..<closingRange.lowerBound]))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !tex.isEmpty {
                    output += MarkdownNormalizer.escapeHTML("$" + tex + "$")
                    cursor = closingRange.upperBound
                    continue
                }
            }

            if suppressedContainerTags.contains(token.name) {
                if !token.isClosing, !token.isSelfClosing { suppressedStack.append(token.name) }
                continue
            }
            if discardedVoidTags.contains(token.name) { continue }
            guard allowedTags.contains(token.name) else { continue }

            if token.isClosing {
                guard let position = emittedStack.lastIndex(of: token.name), position > 0 else { continue }
                while emittedStack.count > position { closeTop() }
                continue
            }

            autoclose(forOpening: token.name, stack: &emittedStack, output: &output)
            guard isAllowedParent(emittedStack.last, for: token.name) else { continue }

            let attributes = sanitizedAttributes(for: token.name, source: token.attributes)
            output += "<\(token.name)\(attributes)>"
            if token.name == "tr" { emittedRow = true }
            if token.name == "th" || token.name == "td" { emittedCell = true }
            if token.name != "col", !token.isSelfClosing { emittedStack.append(token.name) }
        }

        guard completedTable, emittedRow, emittedCell,
              let tabSeparatedText = tabSeparatedText(fromSanitizedHTML: output) else { return nil }
        return SafeComplexTable(html: output, tabSeparatedText: tabSeparatedText)
    }

    private struct HTMLTag {
        let name: String
        let attributes: String
        let isClosing: Bool
        let isSelfClosing: Bool
    }

    private static func parseTag(_ rawTag: String) -> HTMLTag? {
        guard rawTag.hasPrefix("<"), rawTag.hasSuffix(">") else { return nil }
        var content = String(rawTag.dropFirst().dropLast())
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty,
              !content.hasPrefix("!"),
              !content.hasPrefix("?") else { return nil }

        let isClosing = content.hasPrefix("/")
        if isClosing {
            content.removeFirst()
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let isSelfClosing = content.hasSuffix("/")
        if isSelfClosing { content.removeLast() }

        let name = content.prefix { character in
            character.isLetter || character.isNumber
        }.lowercased()
        guard !name.isEmpty else { return nil }
        let attributes = String(content.dropFirst(name.count))
        return HTMLTag(
            name: name,
            attributes: attributes,
            isClosing: isClosing,
            isSelfClosing: isSelfClosing
        )
    }

    private static func autoclose(forOpening tag: String, stack: inout [String], output: inout String) {
        func closeTop() {
            guard let current = stack.popLast() else { return }
            output += "</\(current)>"
        }

        if tag == "td" || tag == "th" {
            if stack.last == "td" || stack.last == "th" { closeTop() }
        } else if tag == "tr" {
            while stack.last == "td" || stack.last == "th" { closeTop() }
            if stack.last == "tr" { closeTop() }
        } else if ["thead", "tbody", "tfoot"].contains(tag) {
            while ["td", "th", "tr"].contains(stack.last ?? "") { closeTop() }
            if ["thead", "tbody", "tfoot"].contains(stack.last ?? "") { closeTop() }
        }
    }

    private static func isAllowedParent(_ parent: String?, for tag: String) -> Bool {
        switch tag {
        case "caption", "colgroup", "thead", "tbody", "tfoot":
            return parent == "table"
        case "col":
            return parent == "table" || parent == "colgroup"
        case "tr":
            return parent == "table" || parent == "thead" || parent == "tbody" || parent == "tfoot"
        case "th", "td":
            return parent == "tr"
        default:
            return false
        }
    }

    private static func sanitizedAttributes(for tag: String, source: String) -> String {
        let attributePattern = try! NSRegularExpression(
            pattern: #"(?i)(?:^|\s)(rowspan|colspan|scope)\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s\"'=<>`]+))"#
        )
        let matches = attributePattern.matches(
            in: source,
            range: NSRange(source.startIndex..., in: source)
        )
        var values: [String: String] = [:]
        for match in matches {
            guard let nameRange = Range(match.range(at: 1), in: source) else { continue }
            let name = source[nameRange].lowercased()
            let value = (2...4).compactMap { index -> String? in
                guard match.range(at: index).location != NSNotFound,
                      let range = Range(match.range(at: index), in: source) else { return nil }
                return String(source[range])
            }.first ?? ""

            if (name == "rowspan" || name == "colspan"),
               (tag == "th" || tag == "td" || tag == "col"),
               let number = Int(value), (1...100).contains(number) {
                values[name] = String(number)
            } else if name == "scope", tag == "th",
                      ["row", "col", "rowgroup", "colgroup"].contains(value.lowercased()) {
                values[name] = value.lowercased()
            }
        }
        return ["scope", "rowspan", "colspan"].compactMap { name in
            values[name].map { " \(name)=\"\(MarkdownNormalizer.escapeHTML($0))\"" }
        }.joined()
    }

    private static func tabSeparatedText(fromSanitizedHTML html: String) -> String? {
        let rowPattern = try! NSRegularExpression(pattern: #"(?is)<tr>(.*?)</tr>"#)
        let cellPattern = try! NSRegularExpression(pattern: #"(?is)<t[hd]([^>]*)>(.*?)</t[hd]>"#)
        var rows: [[String]] = []
        // Absolute ending row for every column occupied by a preceding span.
        var occupiedUntil: [Int: Int] = [:]
        for match in rowPattern.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let bodyRange = Range(match.range(at: 1), in: html) else { continue }
            let body = String(html[bodyRange])
            let rowIndex = rows.count
            occupiedUntil = occupiedUntil.filter { $0.value > rowIndex }
            var row = Array(repeating: "", count: (occupiedUntil.keys.max() ?? -1) + 1)
            var column = 0
            for cell in cellPattern.matches(in: body, range: NSRange(body.startIndex..., in: body)) {
                guard let attributesRange = Range(cell.range(at: 1), in: body),
                      let textRange = Range(cell.range(at: 2), in: body) else { continue }
                let attributes = String(body[attributesRange])
                let colspan = numericAttribute("colspan", in: attributes) ?? 1
                let rowspan = numericAttribute("rowspan", in: attributes) ?? 1
                while (column..<(column + colspan)).contains(where: { occupiedUntil[$0] != nil }) {
                    column += 1
                }
                if row.count < column + colspan {
                    row += Array(repeating: "", count: column + colspan - row.count)
                }
                row[column] = HTMLTextEntities.decode(String(body[textRange]))
                    .replacingOccurrences(of: "\t", with: " ")
                    .replacingOccurrences(of: "\r", with: " ")
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if rowspan > 1 {
                    for index in column..<(column + colspan) {
                        occupiedUntil[index] = rowIndex + rowspan
                    }
                }
                column += colspan
            }
            rows.append(row)
        }
        guard let width = rows.map(\.count).max(), width > 0 else { return nil }
        return rows.map { row in
            (row + Array(repeating: "", count: width - row.count)).joined(separator: "\t")
        }.joined(separator: "\n")
    }

    private static func numericAttribute(_ name: String, in attributes: String) -> Int? {
        let pattern = try! NSRegularExpression(pattern: "(?i)\\b\(name)=\\\"([0-9]{1,3})\\\"")
        guard let match = pattern.firstMatch(
            in: attributes,
            range: NSRange(attributes.startIndex..., in: attributes)
        ), let range = Range(match.range(at: 1), in: attributes) else { return nil }
        return Int(attributes[range])
    }

}

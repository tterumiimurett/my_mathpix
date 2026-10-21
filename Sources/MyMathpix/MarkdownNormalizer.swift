import Foundation

enum MarkdownNormalizer {
    static func normalize(_ input: String) -> String {
        var text = input
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        text = canonicalizeFormulaDelimiters(in: text)
        text = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in line.replacingOccurrences(of: #"[ \t]+$"#, with: "", options: .regularExpression) }
            .joined(separator: "\n")
        text = text.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func pureFormula(in markdown: String) -> String? {
        let text = normalize(markdown)
        if text.hasPrefix("$$"), text.hasSuffix("$$"), text.count >= 4 {
            let inner = String(text.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !inner.isEmpty, !containsUnescapedDollar(in: inner) else { return nil }
            return inner
        }
        if text.hasPrefix("$"), text.hasSuffix("$"), !text.hasPrefix("$$"), text.count >= 3 {
            let inner = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !inner.isEmpty, !inner.contains("\n"), !containsUnescapedDollar(in: inner) else { return nil }
            return inner
        }
        return nil
    }

    static func markdownTableTSV(from markdown: String) -> String? {
        markdownTableTSVs(from: markdown).first
    }

    static func markdownTableTSVs(from markdown: String) -> [String] {
        let lines = normalize(markdown).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var tables: [String] = []
        var fence: MarkdownCodeFence?
        var index = 0
        while index + 1 < lines.count {
            let line = lines[index]
            if let activeFence = fence {
                if activeFence.closes(line) { fence = nil }
                index += 1
                continue
            }
            if let opening = MarkdownCodeFence.opening(in: line) {
                fence = opening
                index += 1
                continue
            }
            guard line.contains("|"), isDelimiterRow(lines[index + 1]) else {
                index += 1
                continue
            }
            var rows: [[String]] = [tableCells(lines[index])]
            var cursor = index + 2
            while cursor < lines.count, lines[cursor].contains("|") {
                rows.append(tableCells(lines[cursor]))
                cursor += 1
            }
            if rows.allSatisfy({ $0.count == rows[0].count }) {
                tables.append(rows.map { row in row.map(cleanCell).joined(separator: "\t") }.joined(separator: "\n"))
            }
            index = cursor
        }
        return tables
    }

    static func tableHTML(from markdown: String) -> String? {
        guard let tsv = markdownTableTSV(from: markdown) else { return nil }
        let rows = tsv.split(separator: "\n", omittingEmptySubsequences: false).map {
            $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        }
        guard let header = rows.first else { return nil }
        let head = "<thead><tr>" + header.map { "<th>\(escapeHTML($0))</th>" }.joined() + "</tr></thead>"
        let body = rows.dropFirst().map { row in
            "<tr>" + row.map { "<td>\(escapeHTML($0))</td>" }.joined() + "</tr>"
        }.joined()
        return "<table>\(head)<tbody>\(body)</tbody></table>"
    }

    static func markdownTableCells(in line: String) -> [String] {
        tableCells(line).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\|", with: "|")
        }
    }

    private static func isDelimiterRow(_ line: String) -> Bool {
        let cells = tableCells(line)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy {
            $0.trimmingCharacters(in: .whitespaces).range(of: #"^:?-{3,}:?$"#, options: .regularExpression) != nil
        }
    }

    private static func tableCells(_ line: String) -> [String] {
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("|") { text.removeFirst() }
        if text.hasSuffix("|"), !text.hasSuffix("\\|") { text.removeLast() }

        let characters = Array(text)
        var cells: [String] = []
        var cell = ""
        var index = 0
        while index < characters.count {
            if characters[index] == "\\", index + 1 < characters.count, characters[index + 1] == "|" {
                cell.append("\\|")
                index += 2
                continue
            }
            if characters[index] == "|" {
                cells.append(cell)
                cell = ""
            } else {
                cell.append(characters[index])
            }
            index += 1
        }
        cells.append(cell)
        return cells
    }

    private static func cleanCell(_ cell: String) -> String {
        TableCellText.plainText(cell)
    }

    static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func canonicalizeFormulaDelimiters(in text: String) -> String {
        var fence: MarkdownCodeFence?
        var formula: FormulaDelimiter?
        return text.split(separator: "\n", omittingEmptySubsequences: false).map { substring in
            let line = String(substring)
            if let marker = fence {
                if marker.closes(line) { fence = nil }
                return line
            }
            if let opening = MarkdownCodeFence.opening(in: line) {
                fence = opening
                return line
            }
            return canonicalizeFormulaDelimitersOutsideCodeSpans(in: line, formula: &formula)
        }.joined(separator: "\n")
    }

    private enum FormulaDelimiter {
        case inlineDollar, displayDollar, parentheses, brackets
    }

    private static func canonicalizeFormulaDelimitersOutsideCodeSpans(
        in line: String, formula: inout FormulaDelimiter?
    ) -> String {
        let characters = Array(line)
        var result = ""
        var codeDelimiterLength: Int?
        var index = 0

        while index < characters.count {
            if formula == nil, characters[index] == "`" {
                var end = index
                while end < characters.count, characters[end] == "`" { end += 1 }
                let count = end - index
                result += String(repeating: "`", count: count)
                if let openLength = codeDelimiterLength {
                    if count == openLength { codeDelimiterLength = nil }
                } else {
                    codeDelimiterLength = count
                }
                index = end
                continue
            }

            if codeDelimiterLength == nil,
               characters[index] == "\\",
               index + 1 < characters.count {
                switch characters[index + 1] {
                case "(" where formula == nil:
                    formula = .parentheses
                    result.append("$")
                case ")" where formula == .parentheses:
                    formula = nil
                    result.append("$")
                case "[" where formula == nil:
                    formula = .brackets
                    result.append("$$")
                case "]" where formula == .brackets:
                    formula = nil
                    result.append("$$")
                default:
                    // Consume an escape pair together: the second slash in
                    // a TeX row break (\\[4pt]) is not a formula delimiter.
                    result += String(characters[index...index + 1])
                }
                index += 2
                continue
            }

            if codeDelimiterLength == nil, characters[index] == "$" {
                let isDisplay = index + 1 < characters.count && characters[index + 1] == "$"
                let delimiter: FormulaDelimiter = isDisplay ? .displayDollar : .inlineDollar
                if formula == nil, isDisplay || hasClosingInlineDollar(in: characters, after: index) {
                    formula = delimiter
                }
                else if formula == delimiter { formula = nil }
                result += isDisplay ? "$$" : "$"
                index += isDisplay ? 2 : 1
                continue
            }

            result.append(characters[index])
            index += 1
        }
        return result
    }

    private static func hasClosingInlineDollar(in characters: [Character], after opening: Int) -> Bool {
        var index = opening + 1
        while index < characters.count {
            if characters[index] == "\\" { index += 2; continue }
            if characters[index] == "$" {
                var end = index + 1
                while end < characters.count, characters[end] == "$" { end += 1 }
                if end == index + 1 { return true }
                index = end
            } else { index += 1 }
        }
        return false
    }

    private static func containsUnescapedDollar(in text: String) -> Bool {
        let characters = Array(text)
        for index in characters.indices where characters[index] == "$" {
            var slashCount = 0
            var cursor = index
            while cursor > characters.startIndex {
                cursor = characters.index(before: cursor)
                guard characters[cursor] == "\\" else { break }
                slashCount += 1
            }
            if slashCount.isMultiple(of: 2) { return true }
        }
        return false
    }
}

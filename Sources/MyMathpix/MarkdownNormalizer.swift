import Foundation

enum MarkdownNormalizer {
    static func normalize(_ input: String) -> String {
        var text = input
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
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
            guard !inner.isEmpty, !inner.contains("$$") else { return nil }
            return inner
        }
        if text.hasPrefix("\\["), text.hasSuffix("\\]"), text.count >= 4 {
            let inner = String(text.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            return inner.isEmpty ? nil : inner
        }
        if text.hasPrefix("$"), text.hasSuffix("$"), !text.hasPrefix("$$"), text.count >= 3 {
            let inner = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !inner.isEmpty, !inner.contains("\n"), !inner.contains("$") else { return nil }
            return inner
        }
        return nil
    }

    static func markdownTableTSV(from markdown: String) -> String? {
        let lines = normalize(markdown).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 2 else { return nil }
        for index in 0..<(lines.count - 1) where isDelimiterRow(lines[index + 1]) {
            var rows: [[String]] = [tableCells(lines[index])]
            var cursor = index + 2
            while cursor < lines.count, lines[cursor].contains("|") {
                rows.append(tableCells(lines[cursor]))
                cursor += 1
            }
            guard !rows.isEmpty, rows.allSatisfy({ $0.count == rows[0].count }) else { return nil }
            return rows.map { row in row.map(cleanCell).joined(separator: "\t") }.joined(separator: "\n")
        }
        return nil
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
        if text.hasSuffix("|") { text.removeLast() }
        return text.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
    }

    private static func cleanCell(_ cell: String) -> String {
        cell.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "\\|", with: "|")
    }

    static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

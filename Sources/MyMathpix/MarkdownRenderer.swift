import Foundation

enum OfflinePreviewNavigationPolicy {
    static func allows(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "about" || scheme == "file"
    }
}

enum MarkdownRenderer {
    enum FormulaRepresentation {
        case preview
        case markdown
    }
    static func document(
        for markdown: String,
        complexTableHTML: String? = nil
    ) -> String {
        let canonicalMarkdown = MarkdownNormalizer.normalize(markdown)
        var body = renderBody(canonicalMarkdown)
        if complexTableHTML != nil {
            do {
                let root = try ClipboardHTMLTree.parse(body)
                let layout = try TableOutputLayout(markdown: canonicalMarkdown, complexTableHTML: complexTableHTML, root: root)
                if layout.table != nil {
                    body = try layout.renderedBody(renderNode: TableOutputLayout.html, renderTable: {
                        "<section aria-label=\"Complex Table Output\">\(try layout.previewHTML($0))</section>"
                    })
                }
            } catch {
                // Preserve safe content if an unusual generated fragment cannot
                // be compared; a failed parse must not discard a service table.
                if let table = complexTableHTML.flatMap(ComplexTableOutputSanitizer.sanitize) {
                    body += "<section aria-label=\"Complex Table Output\">\(table.html)</section>"
                }
            }
        }
        let resources = AppResources.directoryURL
        let css = resources.flatMap { try? String(contentsOf: $0.appendingPathComponent("katex.min.css"), encoding: .utf8) } ?? ""
        let js = resources.flatMap { try? String(contentsOf: $0.appendingPathComponent("katex.min.js"), encoding: .utf8) } ?? ""

        return """
        <!doctype html>
        <html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; navigate-to 'none'; img-src data:; font-src file: data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'">
        <style>
        \(css)
        :root { color-scheme: light dark; }
        body { font: 15px -apple-system, BlinkMacSystemFont, sans-serif; margin: 22px; line-height: 1.55; overflow-wrap: anywhere; }
        table { border-collapse: collapse; margin: 12px 0; width: 100%; }
        th, td { border: 1px solid color-mix(in srgb, currentColor 25%, transparent); padding: 6px 8px; text-align: left; vertical-align: top; }
        th { background: color-mix(in srgb, currentColor 8%, transparent); }
        code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; background: color-mix(in srgb, currentColor 8%, transparent); border-radius: 4px; padding: 1px 4px; }
        pre { padding: 12px; border-radius: 8px; background: color-mix(in srgb, currentColor 8%, transparent); overflow-x: auto; }
        blockquote { border-left: 3px solid color-mix(in srgb, currentColor 30%, transparent); margin-left: 0; padding-left: 12px; opacity: .85; }
        .math-display { overflow-x: auto; padding: 8px 0; }
        </style></head><body>\(body)<script>
        \(js)
        document.querySelectorAll('[data-tex]').forEach(function(el) {
          try {
            var tex = new TextDecoder().decode(Uint8Array.from(atob(el.dataset.tex), c => c.charCodeAt(0)));
            katex.render(tex, el, {displayMode: el.dataset.display === '1', throwOnError: false, strict: false});
          } catch (e) { el.textContent = 'Formula preview failed'; }
        });
        </script></body></html>
        """
    }

    static func renderBody(
        _ markdown: String,
        forClipboard: Bool = false,
        formulaRepresentation: FormulaRepresentation = .preview
    ) -> String {
        let extracted = extractMath(markdown, representation: formulaRepresentation)
        let lines = extracted.text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var output: [String] = []
        var paragraph: [String] = []
        var index = 0
        var codeFence: MarkdownCodeFence?
        var codeLines: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            output.append("<p>\(inline(paragraph.joined(separator: " "), math: extracted.math))</p>")
            paragraph.removeAll()
        }

        while index < lines.count {
            let line = lines[index]
            if let activeFence = codeFence {
                if activeFence.closes(line) {
                    output.append("<pre><code>\(MarkdownNormalizer.escapeHTML(codeLines.joined(separator: "\n")))</code></pre>")
                    codeLines.removeAll()
                    codeFence = nil
                } else {
                    codeLines.append(line)
                }
                index += 1
                continue
            }
            if let openingFence = MarkdownCodeFence.opening(in: line) {
                flushParagraph()
                codeFence = openingFence
                index += 1
                continue
            }
            if index + 1 < lines.count, isTableDelimiter(lines[index + 1]), line.contains("|") {
                flushParagraph()
                var tableLines = [line, lines[index + 1]]
                index += 2
                while index < lines.count, lines[index].contains("|"), !lines[index].isEmpty {
                    tableLines.append(lines[index])
                    index += 1
                }
                output.append(renderTable(tableLines, math: extracted.math, forClipboard: forClipboard))
                continue
            }
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flushParagraph()
            } else if let heading = heading(line) {
                flushParagraph()
                output.append("<h\(heading.level)>\(inline(heading.text, math: extracted.math))</h\(heading.level)>")
            } else if line.hasPrefix("> ") {
                flushParagraph()
                output.append("<blockquote>\(inline(String(line.dropFirst(2)), math: extracted.math))</blockquote>")
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph()
                var items: [String] = []
                while index < lines.count, lines[index].hasPrefix("- ") || lines[index].hasPrefix("* ") {
                    items.append("<li>\(inline(String(lines[index].dropFirst(2)), math: extracted.math))</li>")
                    index += 1
                }
                output.append("<ul>\(items.joined())</ul>")
                continue
            } else if line.hasPrefix("@@MATH") && line.hasSuffix("@@"), let token = extracted.math[line] {
                flushParagraph()
                output.append(mathHTML(token))
            } else {
                paragraph.append(line)
            }
            index += 1
        }
        flushParagraph()
        if codeFence != nil, !codeLines.isEmpty {
            output.append("<pre><code>\(MarkdownNormalizer.escapeHTML(codeLines.joined(separator: "\n")))</code></pre>")
        }
        return output.joined(separator: "\n")
    }

    private struct MathToken {
        let tex: String
        let display: Bool
        let representation: FormulaRepresentation
    }

    private struct ProtectedCode {
        let text: String
        let replacements: [String: String]
    }

    private static func extractMath(
        _ source: String,
        representation: FormulaRepresentation
    ) -> (text: String, math: [String: MathToken]) {
        let protectedCode = protectCode(in: source)
        var text = protectedCode.text
        var tokens: [String: MathToken] = [:]
        var tokenIndex = 0
        let patterns: [(String, Bool)] = [
            (#"\$\$([\s\S]*?)\$\$"#, true),
            (#"\\\[([\s\S]*?)\\\]"#, true),
            // Match math delimiters rather than adjacent currency amounts.
            // Code is already protected; escaped dollars remain ordinary text.
            (#"(?<![\\$])\$(?!\s)((?:\\[^\n]|[^$\n\\])+?)(?<!\s)\$(?![$0-9])"#, false),
            (#"\\\(([^\n]*?)\\\)"#, false)
        ]
        for (pattern, display) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()
            for match in matches {
                guard let range = Range(match.range(at: 0), in: text),
                      let contentRange = Range(match.range(at: 1), in: text) else { continue }
                let key = uniquePlaceholder(
                    kind: "MATH",
                    index: &tokenIndex,
                    avoiding: source
                )
                tokens[key] = MathToken(tex: String(text[contentRange]), display: display, representation: representation)
                text.replaceSubrange(range, with: key)
            }
        }
        for (key, code) in protectedCode.replacements {
            text = text.replacingOccurrences(of: key, with: code)
        }
        return (text, tokens)
    }

    private static func protectCode(in source: String) -> ProtectedCode {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var output: [String] = []
        var replacements: [String: String] = [:]
        var tokenIndex = 0
        var index = 0

        while index < lines.count {
            if let openingFence = MarkdownCodeFence.opening(in: lines[index]) {
                var block = [lines[index]]
                index += 1
                while index < lines.count {
                    block.append(lines[index])
                    let isClosing = openingFence.closes(lines[index])
                    index += 1
                    if isClosing { break }
                }
                let key = uniquePlaceholder(
                    kind: "CODE",
                    index: &tokenIndex,
                    avoiding: source
                )
                replacements[key] = block.joined(separator: "\n")
                output.append(key)
            } else {
                output.append(protectInlineCode(
                    in: lines[index],
                    originalSource: source,
                    replacements: &replacements,
                    tokenIndex: &tokenIndex
                ))
                index += 1
            }
        }
        return ProtectedCode(text: output.joined(separator: "\n"), replacements: replacements)
    }

    private static func protectInlineCode(
        in line: String,
        originalSource: String,
        replacements: inout [String: String],
        tokenIndex: inout Int
    ) -> String {
        let characters = Array(line)
        var output = ""
        var index = 0

        while index < characters.count {
            guard characters[index] == "`" else {
                output.append(characters[index])
                index += 1
                continue
            }

            let openingStart = index
            while index < characters.count, characters[index] == "`" { index += 1 }
            let delimiterLength = index - openingStart
            var closingStart = index
            var closingEnd: Int?
            while closingStart < characters.count {
                guard characters[closingStart] == "`" else {
                    closingStart += 1
                    continue
                }
                var runEnd = closingStart
                while runEnd < characters.count, characters[runEnd] == "`" { runEnd += 1 }
                if runEnd - closingStart == delimiterLength {
                    closingEnd = runEnd
                    break
                }
                closingStart = runEnd
            }

            guard let closingEnd else {
                output += String(characters[openingStart...])
                break
            }
            let key = uniquePlaceholder(
                kind: "CODE",
                index: &tokenIndex,
                avoiding: originalSource
            )
            replacements[key] = String(characters[openingStart..<closingEnd])
            output += key
            index = closingEnd
        }
        return output
    }

    private static func uniquePlaceholder(
        kind: String,
        index: inout Int,
        avoiding source: String
    ) -> String {
        while true {
            let candidate = "\u{E000}MYMATHPIX_\(kind)_\(index)\u{E001}"
            index += 1
            if !source.contains(candidate) { return candidate }
        }
    }

    private static func inline(_ source: String, math: [String: MathToken]) -> String {
        var code: [String: String] = [:]
        var index = 0
        let protected = protectInlineCode(
            in: source, originalSource: source, replacements: &code, tokenIndex: &index
        )
        var text = MarkdownNormalizer.escapeHTML(protected)
        text = replace(pattern: #"\*\*([^*]+)\*\*"#, in: text, template: "<strong>$1</strong>")
        text = replace(pattern: #"(?<!\*)\*([^*]+)\*(?!\*)"#, in: text, template: "<em>$1</em>")
        for (key, token) in math {
            text = text.replacingOccurrences(of: key, with: mathHTML(token))
        }
        for (key, literal) in code {
            let delimiterLength = literal.prefix { $0 == "`" }.count
            let content = String(literal.dropFirst(delimiterLength).dropLast(delimiterLength))
            text = text.replacingOccurrences(of: key, with: "<code>\(MarkdownNormalizer.escapeHTML(content))</code>")
        }
        return text
    }

    private static func mathHTML(_ token: MathToken) -> String {
        if token.representation == .markdown {
            let delimiter = token.display ? "$$" : "$"
            return MarkdownNormalizer.escapeHTML(delimiter + token.tex + delimiter)
        }
        let encoded = Data(token.tex.utf8).base64EncodedString()
        let className = token.display ? "math-display" : "math-inline"
        return "<span class=\"\(className)\" data-tex=\"\(encoded)\" data-display=\"\(token.display ? "1" : "0")\"></span>"
    }

    private static func renderTable(_ lines: [String], math: [String: MathToken], forClipboard: Bool) -> String {
        guard lines.count >= 2 else { return "" }
        let rows = lines.enumerated().compactMap { offset, line -> [String]? in
            if offset == 1 { return nil }
            return cells(line)
        }
        guard let header = rows.first else { return "" }
        func cellHTML(_ source: String) -> String {
            guard forClipboard else { return inline(source, math: math) }
            var html = MarkdownNormalizer.escapeHTML(TableCellText.plainText(source))
            for (key, token) in math {
                html = html.replacingOccurrences(of: key, with: mathHTML(token))
            }
            return html
        }
        let head = "<thead><tr>" + header.map {
            let source = forClipboard ? $0 : TableCellText.previewHeaderSource($0)
            return "<th>\(cellHTML(source))</th>"
        }.joined() + "</tr></thead>"
        let body = rows.dropFirst().map { row in
            "<tr>" + row.map { "<td>\(cellHTML($0))</td>" }.joined() + "</tr>"
        }.joined()
        return "<table>\(head)<tbody>\(body)</tbody></table>"
    }

    private static func cells(_ line: String) -> [String] {
        MarkdownNormalizer.markdownTableCells(in: line)
    }

    private static func isTableDelimiter(_ line: String) -> Bool {
        let values = cells(line)
        return !values.isEmpty && values.allSatisfy {
            $0.range(of: #"^:?-{3,}:?$"#, options: .regularExpression) != nil
        }
    }

    private static func heading(_ line: String) -> (level: Int, text: String)? {
        let count = line.prefix { $0 == "#" }.count
        guard (1...6).contains(count), line.dropFirst(count).hasPrefix(" ") else { return nil }
        return (count, String(line.dropFirst(count + 1)))
    }

    private static func replace(pattern: String, in string: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return string }
        return regex.stringByReplacingMatches(in: string, range: NSRange(string.startIndex..., in: string), withTemplate: template)
    }
}

import AppKit
import Foundation

@MainActor
enum Ticket03SelfCheck {
    static func run() -> Bool {
        var failures: [String] = []

        let source = """
        Inline \\(x + 1\\) and code `\\(leave\\)`.

        \\[
        y = x^2
        \\]

        ```text
        \\(leave this too\\)
        ```
        """
        let canonical = """
        Inline $x + 1$ and code `\\(leave\\)`.

        $$
        y = x^2
        $$

        ```text
        \\(leave this too\\)
        ```
        """
        check(
            MarkdownNormalizer.normalize(source) == canonical,
            "canonical formula delimiters outside code",
            failures: &failures
        )
        check(
            MarkdownNormalizer.normalize(canonical) == canonical,
            "normalization is deterministic and idempotent",
            failures: &failures
        )
        let spacedFormula = #"$$\begin{aligned}a&=b\\[4pt]c&=d\end{aligned}$$"#
        check(
            MarkdownNormalizer.normalize(spacedFormula) == spacedFormula
                && MarkdownNormalizer.pureFormula(in: spacedFormula) == #"\begin{aligned}a&=b\\[4pt]c&=d\end{aligned}"#,
            "normalization and raw Formula Output preserve LaTeX row spacing",
            failures: &failures
        )
        check(
            MarkdownNormalizer.normalize(#"\[\begin{aligned}a&=b\\[4pt]c&=d\end{aligned}\]"#) == spacedFormula
                && MarkdownNormalizer.normalize(#"$$\text{literal \(x\)}$$"#) == #"$$\text{literal \(x\)}$$"#
                && MarkdownNormalizer.normalize(#"literal \\[brackets]"#) == #"literal \\[brackets]"#,
            "delimiter conversion respects existing math context and escaped backslashes",
            failures: &failures
        )
        check(
            MarkdownNormalizer.normalize(#"Cost $5; value \(x+1\)"#) == "Cost $5; value $x+1$",
            "an unmatched currency dollar does not disable later formula normalization",
            failures: &failures
        )

        let table = """
        | Label | Value |
        | --- | ---: |
        | A \\| B | $2$ |
        """
        let formattedTable = """
        | <b>Name</b> | Value |
        | --- | --- |
        | <STRONG title="a > b">A &amp; B</STRONG> | **bold** &alpha; &#x3B2; |
        | a < b > c | `$x$ <b>literal</b>` |
        | &lt;b&gt;literal&lt;/b&gt; | $a_b + c_d$<br/>next |
        """
        check(
            MarkdownNormalizer.markdownTableTSV(from: formattedTable)
                == "Name\tValue\nA & B\tbold α β\na < b > c\t$x$ <b>literal</b>\n<b>literal</b>\t$a_b + c_d$ next",
            "TSV converts formatting and entities without stripping literal comparisons, code or formulas",
            failures: &failures
        )
        check(
            MarkdownNormalizer.markdownTableTSV(from: "| Code |\n| --- |\n| <code>**literal** &amp; &#945;</code> |")
                == "Code\n**literal** & α",
            "HTML code cells retain literal Markdown characters and decode entities",
            failures: &failures
        )
        check(
            MarkdownNormalizer.markdownTableTSV(from: table) == "Label\tValue\nA | B\t$2$",
            "editable GFM table converts escaped pipes to TSV",
            failures: &failures
        )
        check(
            MarkdownRenderer.renderBody(table).contains("<td>A | B</td>"),
            "editable GFM table preserves escaped pipes in preview",
            failures: &failures
        )
        check(
            MarkdownNormalizer.pureFormula(in: " \n $$x^2 + y^2$$ \n ") == "x^2 + y^2",
            "one formula plus whitespace is pure",
            failures: &failures
        )
        for mixed in [
            "Before $x$",
            "$$x$$\n\n$$y$$",
            "$$x$y$$",
            "| x |\n| --- |\n| $y$ |",
            "`$x$`"
        ] {
            check(
                MarkdownNormalizer.pureFormula(in: mixed) == nil,
                "mixed or ambiguous content is not pure formula",
                failures: &failures
            )
        }

        let spanningTable = "<table><tr><th>A</th><th>B</th><th>C</th></tr><tr><td rowspan=\"2\" colspan=\"2\">group</td><td>x</td></tr><tr><td>y</td></tr><tr><td>z</td><td>w</td><td>v</td></tr></table>"
        do {
            let board = NSPasteboard(name: .init("Ticket03Spans.\(UUID().uuidString)"))
            let payload = ClipboardPayload(canonicalMarkdown: "", complexTableHTML: spanningTable, originalPNG: nil)
            for format in [CopyFormat.tsvTable, .richTable] {
                try ClipboardService.copy(format, payload: payload, to: board)
                check(
                    board.string(forType: .tabularText) == "A\tB\tC\ngroup\t\tx\n\t\ty\nz\tw\tv"
                        && board.string(forType: .string) == "A\tB\tC\ngroup\t\tx\n\t\ty\nz\tw\tv",
                    "\(format.title) retains rowspan and colspan column positions",
                    failures: &failures
                )
            }
        } catch { failures.append("spanning table clipboard representations") }

        let entityTable = "<table><tr><td>&alpha; &copy; &#945; &#x3B1; &#X3B1;</td><td>&amp;alpha; &lt;script&gt;safe&lt;/script&gt;</td></tr></table>"
        do {
            let board = NSPasteboard(name: .init("Ticket03Entities.\(UUID().uuidString)"))
            let payload = ClipboardPayload(canonicalMarkdown: "", complexTableHTML: entityTable, originalPNG: nil)
            for format in [CopyFormat.tsvTable, .richTable] {
                try ClipboardService.copy(format, payload: payload, to: board)
                check(
                    board.string(forType: .string) == "α © α α α\t&alpha; <script>safe</script>"
                        && board.string(forType: .tabularText) == "α © α α α\t&alpha; <script>safe</script>",
                    "\(format.title) decodes entities once while preserving literal entity text",
                    failures: &failures
                )
            }
            check(
                board.string(forType: .html)?.contains("&lt;script&gt;safe&lt;/script&gt;") == true
                    && board.string(forType: .html)?.contains("<script>") == false,
                "decoded entity content stays escaped in rich HTML",
                failures: &failures
            )
            if let rtf = board.data(forType: .rtf) {
                let text = try NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil).string
                check(text.contains("α © α α α") && text.contains("&alpha; <script>safe</script>"),
                      "rich RTF preserves decoded entities and escaped literal text", failures: &failures)
            } else { failures.append("entity-rich table offers RTF") }
            if let safe = ComplexTableOutputSanitizer.sanitize(entityTable) {
                check(ComplexTableOutputSanitizer.sanitize(safe.html)?.html == safe.html,
                      "re-sanitizing entity-bearing HTML does not recursively decode content", failures: &failures)
            }
        } catch { failures.append("complex-table entity clipboard representations") }

        let unsafeTable = """
        <div>outside</div>
        <table onclick="steal()" style="background:url(https://example.invalid/a)">
          <thead><tr><th scope="col">Name</th><th colspan="2">Value</th></tr></thead>
          <tbody>
            <tr><td rowspan="2">safe &amp; sound</td><td><img src="https://example.invalid/i" onerror="steal()">2</td></tr>
            <tr><td><script>steal()</script><iframe src="https://example.invalid/f"></iframe>text</td></tr>
          </tbody>
        </table>
        """
        if let safeTable = ComplexTableOutputSanitizer.sanitize(unsafeTable) {
            let lowered = safeTable.html.lowercased()
            check(lowered.hasPrefix("<table>"), "safe complex table has one table root", failures: &failures)
            check(lowered.contains("scope=\"col\"") && lowered.contains("colspan=\"2\"") && lowered.contains("rowspan=\"2\""), "safe table attributes are retained", failures: &failures)
            check(
                !lowered.contains("onclick")
                    && !lowered.contains("style=")
                    && !lowered.contains("<script")
                    && !lowered.contains("<iframe")
                    && !lowered.contains("<img")
                    && !lowered.contains("https://"),
                "executable and remote complex-table content is removed",
                failures: &failures
            )
            check(
                safeTable.tabSeparatedText.contains("Name\tValue")
                    && safeTable.tabSeparatedText.contains("safe & sound\t2"),
                "safe complex table provides a TSV fallback",
                failures: &failures
            )
        } else {
            failures.append("safe complex table is retained")
        }
        check(
            ComplexTableOutputSanitizer.sanitize("<div>not a table</div>") == nil,
            "non-table HTML is rejected",
            failures: &failures
        )

        let previewBefore = MarkdownRenderer.document(for: "Value: \\(x\\)")
        let previewAfter = MarkdownRenderer.document(for: "Value: \\(y^2\\)")
        check(previewBefore != previewAfter, "source edits produce a new preview", failures: &failures)
        let inlineCodePreview = MarkdownRenderer.renderBody("Literal `$x$` stays code.")
        check(
            inlineCodePreview.contains("<code>$x$</code>")
                && !inlineCodePreview.contains("data-tex"),
            "inline code keeps formula delimiters literal",
            failures: &failures
        )
        let fencedCodePreview = MarkdownRenderer.renderBody("""
        ```text
        $$x^2$$
        ```
        """)
        check(
            fencedCodePreview.contains("<pre><code>$$x^2$$</code></pre>")
                && !fencedCodePreview.contains("data-tex"),
            "fenced code keeps formula delimiters literal",
            failures: &failures
        )
        check(
            previewAfter.contains("Content-Security-Policy")
                && previewAfter.contains("default-src 'none'")
                && previewAfter.contains("navigate-to 'none'")
                && !previewAfter.contains("src=\"https://")
                && !previewAfter.contains("href=\"https://")
                && !previewAfter.contains("url(https://")
                && !previewAfter.contains("<iframe"),
            "preview document declares an offline resource policy",
            failures: &failures
        )
        let escapedHTML = MarkdownRenderer.renderBody("<img src=https://example.invalid onerror=steal()>")
        check(
            escapedHTML.contains("&lt;img") && !escapedHTML.contains("<img"),
            "raw HTML is escaped by default",
            failures: &failures
        )
        let complexPreview = MarkdownRenderer.document(
            for: "Complex structure:",
            complexTableHTML: unsafeTable
        ).lowercased()
        check(
            complexPreview.contains("<table>")
                && complexPreview.contains("colspan=\"2\"")
                && !complexPreview.contains("onclick")
                && !complexPreview.contains("steal()")
                && !complexPreview.contains("<iframe")
                && !complexPreview.contains("src=\"http")
                && !complexPreview.contains("href=\"http")
                && !complexPreview.contains("url(http"),
            "Complex Table Output is sanitized before offline preview",
            failures: &failures
        )
        let editableTablePreview = MarkdownRenderer.document(
            for: table,
            complexTableHTML: "<table><tr><th>Label</th><th>Value</th></tr><tr><td>A | B</td><td>$2$</td></tr></table>"
        ).lowercased()
        check(
            editableTablePreview.components(separatedBy: "<table>").count - 1 == 1,
            "editable GFM table does not duplicate its Complex Table fallback",
            failures: &failures
        )
        let distinctTablePreview = MarkdownRenderer.document(for: table, complexTableHTML: spanningTable)
        check(
            distinctTablePreview.components(separatedBy: "<table>").count - 1 == 2
                && distinctTablePreview.contains("rowspan=\"2\"")
                && distinctTablePreview.contains("group"),
            "an unrelated editable table does not hide Complex Table Output",
            failures: &failures
        )
        let spanningMarkdown = "| A | B | C |\n| --- | --- | --- |\n| group | | x |\n| | | y |\n| z | w | v |"
        check(
            MarkdownRenderer.document(for: spanningMarkdown, complexTableHTML: spanningTable)
                .contains("rowspan=\"2\""),
            "matching plain cell values do not discard merged HTML structure",
            failures: &failures
        )
        let otherTable = "| Other |\n| --- |\n| value |"
        let otherHTML = "<table><tr><th>Other</th></tr><tr><td>value</td></tr></table>"
        check(
            MarkdownRenderer.document(for: table + "\n\n" + otherTable, complexTableHTML: otherHTML)
                .components(separatedBy: "<table>").count - 1 == 2,
            "matching a later Markdown table suppresses only its own duplicate",
            failures: &failures
        )
        check(
            MarkdownRenderer.document(for: "```\n" + otherTable + "\n```", complexTableHTML: otherHTML)
                .contains("aria-label=\"Complex Table Output\""),
            "a table example inside code cannot hide real Complex Table Output",
            failures: &failures
        )
        check(
            MarkdownRenderer.document(for: otherTable, complexTableHTML: "<table><caption>Keep this caption</caption><tr><th>Other</th></tr><tr><td>value</td></tr></table>")
                .contains("<caption>Keep this caption</caption>"),
            "table de-duplication preserves captions absent from Markdown",
            failures: &failures
        )
        check(
            OfflinePreviewNavigationPolicy.allows(URL(string: "https://example.invalid")!) == false
                && OfflinePreviewNavigationPolicy.allows(URL(string: "file:///tmp/local-font.woff2")!)
                && OfflinePreviewNavigationPolicy.allows(URL(string: "about:blank")!),
            "preview navigation permits only offline URLs",
            failures: &failures
        )

        check(
            CopyFormat.allCases.map(\.title) == [
                "Formula Output (LaTeX)",
                "Markdown",
                "Combined Output",
                "TSV Table (Plain Text)",
                "Rich Table (HTML + RTF)",
                "Original Image",
                "Notion",
                "Lark"
            ],
            "legacy Copy Format seams remain available alongside Notion",
            failures: &failures
        )
        check(
            CopyFormat.explanation.contains("source")
                && CopyFormat.explanation.contains("Native Paste")
                && CopyFormat.explanation.contains("Notion")
                && CopyFormat.explanation.contains("Feishu")
                && CopyFormat.explanation.contains("experimental")
                && CopyFormat.explanation.contains("must be verified"),
            "Notion clipboard adapter has an explicit unverified Native Paste boundary",
            failures: &failures
        )

        guard let png = makePNG() else {
            failures.append("original image fixture")
            return report(failures)
        }
        do {
            let source = """
            Before $x^2$.

            $$y = x + 1$$

            | Name | Value |
            | --- | --- |
            | <b>A &amp; B</b> | $\\alpha$ |
            | <code>**literal**</code> | &alpha; &copy; &#945; |

            After COMPLETE-CELL-END.
            """
            let board = NSPasteboard(name: .init("Ticket03Lark.\(UUID().uuidString)"))
            try ClipboardService.copy(.lark, payload: ClipboardPayload(
                canonicalMarkdown: source, complexTableHTML: nil, originalPNG: nil
            ), to: board)
            let html = board.string(forType: .html) ?? ""
            check(
                html.contains("Before $x^2$.")
                    && html.contains("$$y = x + 1$$")
                    && html.contains("<table>")
                    && html.contains("<td>A &amp; B</td>")
                    && html.contains("<td>$\\alpha$</td>")
                    && html.contains("<td>**literal**</td>")
                    && html.contains("<td>α © α</td>")
                    && html.contains("After COMPLETE-CELL-END.")
                    && !html.contains("<math") && !html.contains("data-tex")
                    && board.data(forType: .init("org.chromium.web-custom-data")) == nil
                    && board.data(forType: .init("com.byterumi.mymathpix.notion-blocks-v3")) == nil
                    && board.string(forType: .string) == source,
                "Lark copies complete rich tables with Markdown inline/display math and no Notion native placeholders",
                failures: &failures
            )
            try ClipboardService.copy(.markdown, payload: ClipboardPayload(
                canonicalMarkdown: source, complexTableHTML: nil, originalPNG: nil
            ), to: board)
            check(board.string(forType: .string) == source && board.data(forType: .html) == nil,
                  "adding Lark leaves Markdown source-only copying unchanged", failures: &failures)
        } catch { failures.append("Lark mixed-content copy: \(error)") }
        do {
            let source = """
            Keep `**literal** $notMath$` and $a < b$.

            $$\\begin{aligned}a&=b\\\\[4pt]c&=d\\end{aligned}$$

            <img src="https://example.invalid/pixel" onerror="evil()">

            | A | B |
            | --- | --- |
            | one | two |

            | C | D |
            | --- | --- |
            | 完整 🧮 | end |
            """
            let board = NSPasteboard(name: .init("Ticket03LarkSafety.\(UUID().uuidString)"))
            let payload = ClipboardPayload(canonicalMarkdown: source, complexTableHTML: nil, originalPNG: nil)
            try ClipboardService.copy(.notion, payload: payload, to: board)
            try ClipboardService.copy(.lark, payload: payload, to: board)
            let html = board.string(forType: .html) ?? ""
            check(
                html.contains("<code>**literal** $notMath$</code>")
                    && html.contains("$a &lt; b$")
                    && html.contains("$$\\begin{aligned}a&amp;=b\\\\[4pt]c&amp;=d\\end{aligned}$$")
                    && html.components(separatedBy: "<table>").count == 3
                    && html.contains("完整 🧮")
                    && !html.contains("<img") && !html.contains("<script")
                    && !html.contains("<math") && !html.contains("‣")
                    && board.data(forType: .init("org.chromium.web-custom-data")) == nil
                    && board.string(forType: .string) == source,
                "Lark retains literal code, TeX spacing, all tables and safe text without stale Notion clipboard data",
                failures: &failures
            )
            let complex = "<table><caption>Keep α caption</caption><tr><th>A</th><th>B</th></tr><tr><td rowspan=\"2\">**literal**</td><td>Y</td></tr><tr><td>Z</td></tr></table>"
            try ClipboardService.copy(.lark, payload: ClipboardPayload(
                canonicalMarkdown: "Keep $x$.", complexTableHTML: complex, originalPNG: nil
            ), to: board)
            let expected = "Keep $x$.\n\nKeep α caption\n\nA\tB\n**literal**\tY\n\tZ"
            check(
                board.string(forType: .string) == expected
                    && board.string(forType: .html)?.contains("rowspan=\"2\"") == true
                    && board.string(forType: .html)?.contains("<caption>Keep α caption</caption>") == true,
                "Lark preserves complex table captions, merged HTML and complete literal source fallback",
                failures: &failures
            )
        } catch { failures.append("Lark safety and complex table copy: \(error)") }
        do {
            let notionSource = """
            Before $x^2$.

            $$y = x + 1$$

            | Name | Value |
            | --- | --- |
            | A & B | $\\alpha$ |

            After COMPLETE-CELL-END.
            """
            let board = NSPasteboard(name: .init("Ticket03Notion.\(UUID().uuidString)"))
            try ClipboardService.copy(
                .notion,
                payload: ClipboardPayload(canonicalMarkdown: notionSource, complexTableHTML: nil, originalPNG: nil),
                to: board
            )
            let html = board.string(forType: .html) ?? ""
            let json = board.data(forType: .init("com.byterumi.mymathpix.notion-blocks-v3")) ?? Data()
            let document = try JSONSerialization.jsonObject(with: json) as? [String: Any]
            let blocks = document?["blocks"] as? [[String: Any]] ?? []
            let nativeText = String(data: json, encoding: .utf8) ?? ""
            let values: [[String: Any]] = blocks.compactMap { block in
                guard let id = block["blockId"] as? String,
                      let subtree = block["blockSubtree"] as? [String: Any],
                      let records = subtree["block"] as? [String: Any],
                      let record = records[id] as? [String: Any] else { return nil }
                return record["value"] as? [String: Any]
            }
            let display = values.first { $0["type"] as? String == "equation" }
            let displayTitle = (display?["properties"] as? [String: Any])?["title"] as? [[String]]
            let firstTitle = (values.first?["properties"] as? [String: Any])?["title"] as? [[Any]] ?? []
            let hasInlineEquation = firstTitle.contains { run in
                guard run.first as? String == "‣", run.count == 2,
                      let marks = run[1] as? [[String]] else { return false }
                return marks.contains(["e", "x^2"])
            }
            let nativeEnvelope = readChromiumCustomData(board.data(forType: .init("org.chromium.web-custom-data")))
            check(
                CopyFormat.visibleFormats.map(\.title) == ["Markdown", "Lark", "Notion"]
                    && blocks.count == 4
                    && values.compactMap { $0["type"] as? String } == ["text", "equation", "table", "text"]
                    && displayTitle == [["y = x + 1"]]
                    && hasInlineEquation
                    && nativeEnvelope?["text/_notion-blocks-v3-production"] == String(decoding: json, as: UTF8.self)
                    && nativeText.contains("equation")
                    && nativeText.contains("table_row")
                    && nativeText.contains("COMPLETE-CELL-END")
                    && nativeText.contains("x^2")
                    && html.contains("<table>")
                    && html.contains("<math")
                    && html.contains("Before") && html.contains("After")
                    && !html.contains("<script") && !html.contains("data-tex")
                    && board.string(forType: .string) == notionSource
                    && board.data(forType: .init("org.chromium.web-custom-data")) != nil,
                "Notion copies complete mixed content with native equations, rich tables, and lossless source fallback",
                failures: &failures
            )
        } catch {
            failures.append("Notion complete mixed-content pasteboard: \(error)")
        }
        do {
            let source = """
            Keep `**literal** $notMath$` and $\\alpha$.

            | <b>Name</b> | Value |
            | --- | --- |
            | <code>**literal**</code> | &alpha; &copy; &#945; |

            <img src="https://example.invalid/pixel" onerror="evil()">

            | Second | Table |
            | --- | --- |
            | end | 完整 🧮 |
            """
            let board = NSPasteboard(name: .init("Ticket03NotionLiterals.\(UUID().uuidString)"))
            try ClipboardService.copy(.notion, payload: ClipboardPayload(
                canonicalMarkdown: source, complexTableHTML: nil, originalPNG: nil
            ), to: board)
            let html = board.string(forType: .html) ?? ""
            let data = board.data(forType: .init("com.byterumi.mymathpix.notion-blocks-v3")) ?? Data()
            let envelope = readChromiumCustomData(board.data(forType: .init("org.chromium.web-custom-data")))
            check(
                html.contains("<code>**literal** $notMath$</code>")
                    && html.contains("<th>Name</th>")
                    && html.contains("<td>**literal**</td>")
                    && html.contains("<td>α © α</td>")
                    && html.components(separatedBy: "<table>").count == 3
                    && !html.contains("<img") && !html.contains("<script")
                    && !html.contains("<iframe") && !html.contains("<a ")
                    && envelope?["text/_notion-blocks-v3-production"] == String(decoding: data, as: UTF8.self)
                    && String(decoding: data, as: UTF8.self).contains("完整 🧮"),
                "Notion preserves literal code, cleaned table cells, Unicode, all tables, and inert HTML",
                failures: &failures
            )
        } catch {
            failures.append("Notion literal and security pasteboard: \(error)")
        }
        do {
            let source = "$$x^2 + y^2$$"
            let payload = ClipboardPayload(canonicalMarkdown: source, complexTableHTML: nil, originalPNG: nil)
            let board = NSPasteboard(name: .init("Ticket03NotionFormula.\(UUID().uuidString)"))
            try ClipboardService.copy(.notion, payload: payload, to: board)
            let json = board.data(forType: .init("com.byterumi.mymathpix.notion-blocks-v3")) ?? Data()
            let document = try JSONSerialization.jsonObject(with: json) as? [String: Any]
            let blocks = document?["blocks"] as? [[String: Any]] ?? []
            check(
                blocks.count == 1
                    && String(decoding: json, as: UTF8.self).contains("x^2 + y^2")
                    && board.string(forType: .html)?.contains("<math") == true
                    && ClipboardService.automaticCopyFormat(for: payload) == .formulaOutput,
                "pure formula Notion copy offers equation data without changing conservative automatic raw-LaTeX copy",
                failures: &failures
            )
        } catch { failures.append("Notion pure formula copy: \(error)") }
        do {
            let board = NSPasteboard(name: .init("Ticket03NotionComplex.\(UUID().uuidString)"))
            let complex = "<table><caption>Keep α caption</caption><tr><th>A</th><th>B</th></tr><tr><td rowspan=\"2\">**literal** `code` $5 and $10</td><td>Y</td></tr><tr><td>Z</td></tr></table>"
            try ClipboardService.copy(.notion, payload: ClipboardPayload(
                canonicalMarkdown: "Keep surrounding text.", complexTableHTML: complex, originalPNG: nil
            ), to: board)
            let native = String(decoding: board.data(forType: .init("com.byterumi.mymathpix.notion-blocks-v3")) ?? Data(), as: UTF8.self)
            check(
                native.contains("Keep α caption") && native.contains("Z")
                    && native.contains("**literal** `code` $5 and $10")
                    && board.string(forType: .string)?.contains("\n\tZ") == true
                    && board.string(forType: .html)?.contains("rowspan=\"2\"") == true,
                "Notion retains distinct complex table captions, merged HTML, and projected fallback cell positions",
                failures: &failures
            )
        } catch { failures.append("Notion complex table copy: \(error)") }
        do {
            let formattedPayload = ClipboardPayload(canonicalMarkdown: formattedTable, complexTableHTML: nil, originalPNG: png)
            let output = try ClipboardService.prepare(.tsvTable, payload: formattedPayload)
            let board = NSPasteboard(name: .init("Ticket03Prepared.\(UUID().uuidString)"))
            try ClipboardService.copy(output, to: board)
            check(
                output.previewText == board.string(forType: .string)
                    && board.string(forType: .tabularText) == "Name\tValue\nA & B\tbold α β\na < b > c\t$x$ <b>literal</b>\n<b>literal</b>\t$a_b + c_d$ next",
                "row preview and full TSV pasteboard share the same prepared content",
                failures: &failures
            )
            let rich = try ClipboardService.prepare(.richTable, payload: formattedPayload)
            try ClipboardService.copy(rich, to: board)
            check(
                rich.previewText == output.previewText
                    && board.string(forType: .string) == output.previewText
                    && board.string(forType: .tabularText) == output.previewText
                    && board.string(forType: .html)?.contains("<td>A &amp; B</td>") == true,
                "rich table HTML and plain representations preserve the same cell text",
                failures: &failures
            )
            if let rtf = board.data(forType: .rtf) {
                let richText = try NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil).string
                check(richText.contains("A & B") && richText.contains("bold α β") && !richText.contains("<STRONG"),
                      "rich RTF renders the same cleaned cell semantics", failures: &failures)
            } else { failures.append("rich RTF is present") }
            let longSource = String(repeating: "content beyond the one-line viewport ", count: 30) + "END-OF-COMPLETE-CONTENT"
            let longPrepared = try ClipboardService.prepare(.markdown, payload: .init(canonicalMarkdown: longSource, complexTableHTML: nil, originalPNG: nil))
            try ClipboardService.copy(longPrepared, to: board)
            check(longPrepared.previewText == longSource && board.string(forType: .string) == longSource,
                  "one-line preview model retains every character of copied content", failures: &failures)
        } catch { failures.append("prepared copy and row preview contract") }
        let mixedMarkdown = """
        Result: $x + 1$

        | Label | Value |
        | --- | ---: |
        | A | 2 |
        """
        let safeComplexHTML = ComplexTableOutputSanitizer.sanitize(unsafeTable)?.html
        let payload = ClipboardPayload(
            canonicalMarkdown: mixedMarkdown,
            complexTableHTML: safeComplexHTML,
            originalPNG: png
        )
        check(
            ClipboardService.unavailability(of: .formulaOutput, payload: payload) == .formulaOutputRequiresPureFormula
                && ClipboardService.unavailability(of: .richTable, payload: payload) == nil
                && ClipboardService.unavailability(of: .originalImage, payload: payload) == nil,
            "copy rows distinguish mixed content from available table and image formats",
            failures: &failures
        )
        let formulaOnly = ClipboardPayload(canonicalMarkdown: "$$x^2$$", complexTableHTML: nil, originalPNG: nil)
        check(
            ClipboardService.unavailability(of: .formulaOutput, payload: formulaOnly) == nil
                && ClipboardService.unavailability(of: .tsvTable, payload: formulaOnly) == .tableUnavailable
                && ClipboardService.unavailability(of: .richTable, payload: formulaOnly) == .tableUnavailable
                && ClipboardService.unavailability(of: .originalImage, payload: formulaOnly) == .imageUnavailable,
            "copy rows explain unavailable table and original image without writing to pasteboard",
            failures: &failures
        )
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("Ticket03SelfCheck.\(UUID().uuidString)"))

        assertCopy(.markdown, payload: payload, pasteboard: pasteboard, plainText: mixedMarkdown, failures: &failures)
        assertCopy(.combinedOutput, payload: payload, pasteboard: pasteboard, plainText: mixedMarkdown, failures: &failures)
        assertCopy(.tsvTable, payload: payload, pasteboard: pasteboard, plainText: "Label\tValue\nA\t2", failures: &failures)
        let tsvTypes = Set(pasteboard.types ?? [])
        check(
            !tsvTypes.contains(.html) && !tsvTypes.contains(.rtf),
            "TSV Table does not claim rich clipboard representations",
            failures: &failures
        )

        do {
            try ClipboardService.copy(.richTable, payload: payload, to: pasteboard)
            let types = Set(pasteboard.types ?? [])
            check(types.contains(.html), "rich table provides public HTML", failures: &failures)
            check(types.contains(.rtf), "rich table provides public RTF", failures: &failures)
            check(types.contains(.tabularText), "rich table provides public TSV", failures: &failures)
            check(types.contains(.string), "rich table provides public plain text", failures: &failures)
            check(
                pasteboard.data(forType: .html).flatMap { String(data: $0, encoding: .utf8) }
                    == MarkdownNormalizer.tableHTML(from: mixedMarkdown),
                "rich table follows the editable Markdown table",
                failures: &failures
            )
            check(
                pasteboard.string(forType: .string) == pasteboard.string(forType: .tabularText),
                "rich table plain text matches its TSV fallback",
                failures: &failures
            )
            check(!(pasteboard.data(forType: .rtf)?.isEmpty ?? true), "rich table RTF has content", failures: &failures)
        } catch {
            failures.append("rich table Copy Format")
        }

        do {
            let complexOnlyPayload = ClipboardPayload(
                canonicalMarkdown: "Complex table fallback",
                complexTableHTML: safeComplexHTML,
                originalPNG: png
            )
            try ClipboardService.copy(.richTable, payload: complexOnlyPayload, to: pasteboard)
            check(
                pasteboard.data(forType: .html).flatMap { String(data: $0, encoding: .utf8) }
                    == safeComplexHTML,
                "rich table retains sanitized Complex Table Output as its fallback",
                failures: &failures
            )
        } catch {
            failures.append("Complex Table Output rich-copy fallback")
        }

        do {
            let purePayload = ClipboardPayload(canonicalMarkdown: "$$x^2$$", complexTableHTML: nil, originalPNG: png)
            try ClipboardService.copy(.formulaOutput, payload: purePayload, to: pasteboard)
            check(pasteboard.string(forType: .string) == "x^2", "Formula Output is raw LaTeX", failures: &failures)
            let formulaAndHTMLTable = ClipboardPayload(
                canonicalMarkdown: "$$x^2$$", complexTableHTML: safeComplexHTML, originalPNG: png
            )
            check(
                ClipboardService.unavailability(of: .formulaOutput, payload: formulaAndHTMLTable)
                    == .formulaOutputRequiresPureFormula
                    && ClipboardService.automaticCopyFormat(for: formulaAndHTMLTable) == nil,
                "formula plus retained HTML table is not Pure Formula",
                failures: &failures
            )
            do {
                try ClipboardService.copy(.formulaOutput, payload: formulaAndHTMLTable, to: pasteboard)
                failures.append("formula copy must not omit a retained HTML table")
            } catch CopyFormatError.formulaOutputRequiresPureFormula {
                check(pasteboard.string(forType: .string) == "x^2", "rejected formula plus table preserves clipboard", failures: &failures)
            }
            check(
                ClipboardService.automaticCopyFormat(for: purePayload.canonicalMarkdown) == .formulaOutput,
                "Pure Formula chooses automatic Formula Output copy",
                failures: &failures
            )
            check(
                ClipboardService.automaticCopyFormat(for: mixedMarkdown) == nil,
                "mixed Combined Output waits for owner copy action",
                failures: &failures
            )
            do {
                try ClipboardService.copy(.formulaOutput, payload: payload, to: pasteboard)
                failures.append("mixed content Formula Output is rejected")
            } catch CopyFormatError.formulaOutputRequiresPureFormula {
                // Expected.
            } catch {
                failures.append("mixed content Formula Output reports the expected reason")
            }
        } catch {
            failures.append("Formula Output Copy Format")
        }

        do {
            try ClipboardService.copy(.originalImage, payload: payload, to: pasteboard)
            check(pasteboard.data(forType: .png) == png, "original PNG bytes are copied", failures: &failures)
            check(!(pasteboard.data(forType: .tiff)?.isEmpty ?? true), "original image offers TIFF compatibility", failures: &failures)
        } catch {
            failures.append("original image Copy Format")
        }

        do {
            let history = HistoryStore(inMemory: true)
            let created = try history.create(uploadPayload: UploadPayload(pngData: png))
            var completed = created
            completed.status = .complete
            completed.markdown = Ticket03AcceptanceFixture.initialMarkdown
            completed.html = safeComplexHTML
            try history.update(completed)
            let journeyPasteboard = NSPasteboard(
                name: NSPasteboard.Name("Ticket03Journey.\(UUID().uuidString)")
            )
            let model = AppModel(
                recognitionService: Ticket03AcceptanceRecognitionService(),
                history: history,
                usageRecords: UsageRecordStore(inMemory: true),
                defaults: UserDefaults(suiteName: "Ticket03Journey.\(UUID().uuidString)")!,
                diagnosticLog: DiagnosticLog(rootURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("Ticket03JourneyDiagnostics-\(UUID().uuidString)", isDirectory: true)),
                pasteboard: journeyPasteboard,
                registersHotKey: false,
                appInteractionEnabled: false
            )
            model.updateMarkdown(Ticket03AcceptanceFixture.editedMarkdown)
            check(
                model.selectedItem?.markdown == Ticket03AcceptanceFixture.editedMarkdown,
                "owner edit is retained as current Canonical Markdown",
                failures: &failures
            )
            check(
                model.selectedItem?.html == safeComplexHTML,
                "owner edit retains sanitized Complex Table Output alongside Markdown",
                failures: &failures
            )
            check(
                MarkdownRenderer.document(for: model.selectedItem?.markdown ?? "").contains(
                    Data("e^{i\\pi} = -1".utf8).base64EncodedString()
                ),
                "owner edit flows into offline preview input",
                failures: &failures
            )
            model.copySelected(as: .richTable)
            check(
                Ticket03PasteboardInspector.inspect(.richTable, pasteboard: journeyPasteboard),
                "owner edit flows into public rich-table pasteboard values",
                failures: &failures
            )
            check(model.copySelected(as: .combinedOutput), "copy action reports success for row feedback", failures: &failures)
            check(
                Ticket03PasteboardInspector.inspect(.combinedOutput, pasteboard: journeyPasteboard),
                "owner edit flows into Combined Output",
                failures: &failures
            )
            check(
                !model.copySelected(as: .formulaOutput)
                    && Ticket03PasteboardInspector.inspect(.combinedOutput, pasteboard: journeyPasteboard),
                "unavailable formula copy reports failure and preserves mixed content on pasteboard",
                failures: &failures
            )
            var failedRecord = history.item(id: created.id)!
            failedRecord.status = .failed
            try history.update(failedRecord)
            check(
                model.copySelected(as: .originalImage)
                    && journeyPasteboard.data(forType: .png) == png
                    && !(journeyPasteboard.data(forType: .tiff)?.isEmpty ?? true),
                "Failed Record retains original-image recovery copying without recapture",
                failures: &failures
            )
        } catch {
            failures.append("complete owner edit-preview-copy journey")
        }

        let acceptanceLaunch = AppLaunchConfiguration(
            arguments: [
                "MyMathpix",
                "--ticket03-acceptance",
                "--ticket03-run-id=00000000-0000-4000-8000-000000000003"
            ]
        )
        let pasteboardInspection = AppLaunchConfiguration(
            arguments: ["MyMathpix", "--ticket03-inspect-pasteboard=richTable"]
        )
        check(acceptanceLaunch.runsTicket03Acceptance, "Ticket 03 signed acceptance launch is explicit", failures: &failures)
        check(
            !AppLaunchConfiguration(
                arguments: ["MyMathpix", "--ticket03-acceptance"]
            ).runsTicket03Acceptance,
            "unbound Ticket 03 acceptance launch is rejected",
            failures: &failures
        )
        check(
            pasteboardInspection.ticket03PasteboardInspection == .richTable,
            "Ticket 03 pasteboard inspection selects one known Copy Format",
            failures: &failures
        )
        check(
            !Ticket03AcceptanceFixture.initialMarkdown.contains("Recognition Result")
                && !Ticket03AcceptanceFixture.editedMarkdown.contains("Edited Result")
                && !Ticket03AcceptanceFixture.initialMarkdown.contains("Euler identity")
                && !Ticket03AcceptanceFixture.editedMarkdown.contains("Verified identity"),
            "acceptance fixture does not inject synthetic result labels",
            failures: &failures
        )

        return report(failures)
    }

    private static func assertCopy(
        _ format: CopyFormat,
        payload: ClipboardPayload,
        pasteboard: NSPasteboard,
        plainText: String,
        failures: inout [String]
    ) {
        do {
            try ClipboardService.copy(format, payload: payload, to: pasteboard)
            check(pasteboard.string(forType: .string) == plainText, "\(format.title) public plain text", failures: &failures)
        } catch {
            failures.append("\(format.title) Copy Format")
        }
    }

    /// Independent consumer of Chromium's public DataTransfer wire format.
    private static func readChromiumCustomData(_ data: Data?) -> [String: String]? {
        guard let data else { return nil }
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
            let result = String(data: Data(bytes[start..<offset]), encoding: .utf16LittleEndian)
            offset = (offset + 3) & ~3
            return result
        }
        guard integer() == bytes.count - 4, let count = integer(), count < 100 else { return nil }
        var entries: [String: String] = [:]
        for _ in 0..<count {
            guard let key = string(), let value = string() else { return nil }
            entries[key] = value
        }
        return offset == bytes.count ? entries : nil
    }

    private static func makePNG() -> Data? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 2,
            pixelsHigh: 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        let color = NSColor(deviceRed: 0.1, green: 0.65, blue: 0.7, alpha: 1)
        for y in 0..<2 {
            for x in 0..<2 {
                bitmap.setColor(color, atX: x, y: y)
            }
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func check(_ condition: Bool, _ name: String, failures: inout [String]) {
        if !condition { failures.append(name) }
    }

    private static func report(_ failures: [String]) -> Bool {
        if failures.isEmpty {
            print("Ticket 03 self-test passed.")
            return true
        }
        print("Ticket 03 self-test failed:")
        failures.forEach { print("- \($0)") }
        return false
    }
}

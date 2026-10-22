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
                    && readChromiumCustomData(board.data(forType: .init("org.chromium.web-custom-data")))?.keys.sorted() == ["docx/record"]
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
                    && readChromiumCustomData(board.data(forType: .init("org.chromium.web-custom-data")))?.keys.sorted() == ["docx/record"]
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
                guard run.first as? String == "⁍", run.count == 2,
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
            let board = NSPasteboard(name: .init("Ticket07Mixed.\(UUID().uuidString)"))
            let source = """
            Before $x^2$ and $\\frac{a}{b}$.

            | Formula | Literal |
            | --- | --- |
            | $\\sqrt{x+1}$ | `**literal** $not_math$` |
            | $2$ | prices $5 and $10 |

            $$y=x+1$$

            After $z_0$.
            """
            let complex = #"<table><caption>Caption α</caption><tr><th colspan="2">Group</th><th>Formula</th></tr><tr><td rowspan="2">Keep **literal** `code` $5 and $10 &amp; &lt;b&gt;</td><td>Y</td><td><math>u^2+v^2</math></td></tr><tr><td>Z</td><td><math>\frac{1}{2}</math><math><mi>discard</mi></math><script>evil()</script></td></tr></table>"#
            try ClipboardService.copy(.notion, payload: ClipboardPayload(
                canonicalMarkdown: source, complexTableHTML: complex, originalPNG: nil
            ), to: board)
            let data = board.data(forType: NotionClipboardDocument.nativeType) ?? Data()
            let object = try JSONSerialization.jsonObject(with: data)
            func equations(_ value: Any) -> [String] {
                if let dictionary = value as? [String: Any] { return dictionary.values.flatMap(equations) }
                guard let array = value as? [Any] else { return [] }
                if array.first as? String == "⁍", array.count == 2,
                   let marks = array[1] as? [[String]] {
                    return marks.filter { $0.count == 2 && $0[0] == "e" }.map { $0[1] }
                }
                return array.flatMap(equations)
            }
            check(
                equations(object).sorted() == ["x^2", #"\frac{a}{b}"#, #"\sqrt{x+1}"#, "2", "z_0", "u^2+v^2", #"\frac{1}{2}"#].sorted(),
                "Notion mixed pasteboard has all seven native inline equations, including Complex Table Output, without currency or code equations",
                failures: &failures
            )
            func textRuns(_ value: Any) -> [String] {
                if let dictionary = value as? [String: Any] { return dictionary.values.flatMap(textRuns) }
                if let runs = value as? [[Any]], !runs.isEmpty,
                   runs.allSatisfy({ $0.first is String }) {
                    return [runs.compactMap { $0.first as? String }.joined()]
                }
                return (value as? [Any])?.flatMap(textRuns) ?? []
            }
            let native = String(decoding: data, as: UTF8.self)
            let html = board.string(forType: .html) ?? ""
            check(
                native.contains("prices $5 and $10") && textRuns(object).contains("Keep **literal** `code` $5 and $10 & <b>")
                    && native.contains("**literal** $not_math$")
                    && native.contains("y=x+1") && native.contains("Caption α")
                    && !native.contains("discard") && !native.contains("evil()")
                    && html.contains("rowspan=\"2\"") && html.contains("colspan=\"2\"")
                    && board.string(forType: .string)?.contains("\n\tZ\t$\\frac{1}{2}$") == true,
                "Notion rich mixed copy preserves literal cells, caption, span HTML, projected columns and display math while suppressing active or nested MathML",
                failures: &failures
            )
        } catch { failures.append("Notion inline rich mixed regression: \(error)") }
        do {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("Ticket07Storage-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: root) }
            let suite = "Ticket07Storage.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let historyURL = root.appendingPathComponent("History")
            let history = HistoryStore(rootURL: historyURL)
            let board = NSPasteboard(name: .init(suite))
            func model(_ history: HistoryStore) -> AppModel {
                AppModel(recognitionService: Ticket07StoredMathRecognitionService(), history: history,
                         usageRecords: UsageRecordStore(inMemory: true), defaults: defaults,
                         diagnosticLog: DiagnosticLog(rootURL: root.appendingPathComponent("Diagnostics")),
                         pasteboard: board, registersHotKey: false, appInteractionEnabled: false)
            }
            func equations(_ value: Any) -> [String] {
                if let dictionary = value as? [String: Any] { return dictionary.values.flatMap(equations) }
                guard let array = value as? [Any] else { return [] }
                if array.first as? String == "⁍", array.count == 2,
                   let marks = array[1] as? [[String]] {
                    return marks.filter { $0.count == 2 && $0[0] == "e" }.map { $0[1] }
                }
                return array.flatMap(equations)
            }
            let recognitionModel = model(history)
            recognitionModel.recognizeCapturedSnippet(UploadPayload(pngData: png))
            let deadline = Date().addingTimeInterval(3)
            while recognitionModel.isProcessing && Date() < deadline {
                _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
            }
            check(!recognitionModel.isProcessing && recognitionModel.selectedItem?.status == .complete,
                  "offline stored-math fixture completes through the real recognition model", failures: &failures)
            let reloaded = model(HistoryStore(rootURL: historyURL))
            check(reloaded.copySelected(as: .notion), "reloaded recognition output copies through the normal model action", failures: &failures)
            let native = board.data(forType: NotionClipboardDocument.nativeType) ?? Data()
            let object = try JSONSerialization.jsonObject(with: native)
            check(equations(object).sorted() == ["x^2", "u^2+v^2", #"\frac{1}{2}"#].sorted(),
                  "Notion retains explicit complex-cell equations after recognition, disk storage, relaunch and public model copy", failures: &failures)
            check(reloaded.copySelected(as: .lark), "reloaded recognition output copies through the normal Lark model action", failures: &failures)
            let larkJSON = readChromiumCustomData(board.data(forType: ChromiumClipboardData.type))?["docx/record"] ?? "{}"
            let larkObject = try JSONSerialization.jsonObject(with: Data(larkJSON.utf8)) as? [String: Any] ?? [:]
            let larkRecords = larkObject["recordMap"] as? [String: [String: Any]] ?? [:]
            let larkPools = larkRecords.values.compactMap { (($0["snapshot"] as? [String: Any])?["text"] as? [String: Any])?["apool"] as? [String: Any] }
            let larkEquations = larkPools.flatMap { (($0["numToAttrib"] as? [String: [String]]) ?? [:]).values }.filter { $0.first == "equation" }.compactMap { $0.last }
            check(larkEquations.sorted() == ["x^2", "u^2+v^2", #"\frac{1}{2}"#].sorted(),
                  "Lark retains explicit complex-cell equations after recognition, disk storage, relaunch and public model copy", failures: &failures)

            // Previously saved records have lost <math> provenance. Recover only
            // whole-cell formulas corroborated by the actual Canonical Markdown.
            var legacy = history.items[0]
            legacy.markdown = #"After $z_0$; code `$not_math$`; prices $5 and $10."# + "\n\n| A | Formula |\n| --- | --- |\n| U | $u^2+v^2$ |\n| F | $\\frac{1}{2}$ |"
            legacy.html = #"<table><caption>Legacy</caption><tr><td rowspan="2">**literal** `code` $5 and $10</td><td>$u^2+v^2$</td></tr><tr><td>$\frac{1}{2}$</td></tr><tr><td>$not_math$</td><td>$unrelated$</td></tr></table>"#
            try history.update(legacy)
            let legacyModel = model(HistoryStore(rootURL: historyURL))
            _ = legacyModel.copySelected(as: .notion)
            let legacyData = board.data(forType: NotionClipboardDocument.nativeType) ?? Data()
            check(equations(try JSONSerialization.jsonObject(with: legacyData)).sorted()
                    == ["z_0", "u^2+v^2", #"\frac{1}{2}"#, "u^2+v^2", #"\frac{1}{2}"#].sorted()
                    && String(decoding: legacyData, as: UTF8.self).contains("**literal** `code` $5 and $10")
                    && String(decoding: legacyData, as: UTF8.self).contains("$unrelated$")
                    && String(decoding: legacyData, as: UTF8.self).contains("$not_math$"),
                  "legacy complex cells recover only canonical whole-cell formulas while preserving code, currency and unrelated literal math", failures: &failures)
            legacy.markdown = "| Math | Code |\n| --- | --- |\n| $u^2+v^2$ | `$u^2+v^2$` |"
            legacy.html = #"<table><caption>Legacy code ambiguity</caption><tr><td>$u^2+v^2$</td></tr></table>"#
            try history.update(legacy)
            let ambiguousModel = model(HistoryStore(rootURL: historyURL))
            _ = ambiguousModel.copySelected(as: .notion)
            let ambiguous = board.data(forType: NotionClipboardDocument.nativeType) ?? Data()
            check(equations(try JSONSerialization.jsonObject(with: ambiguous)) == ["u^2+v^2"],
                  "legacy recovery declines formulas also used as literal code in Canonical Markdown", failures: &failures)
        } catch { failures.append("recognition-to-stored-Notion-copy: \(error)") }
        do {
            let source = """
            Before $x^2$.

            Caption α

            | Group | | Formula |
            | --- | --- | --- |
            | Keep **literal** `code` $5 and $10 | Y | $u^2+v^2$ |
            | | Z | $\\frac{1}{2}$ |

            After $z_0$.
            """
            let rich = #"<table><caption>Caption α</caption><tr><th colspan="2">Group</th><th>Formula</th></tr><tr><td rowspan="2">Keep **literal** `code` $5 and $10</td><td>Y</td><td><math>u^2+v^2</math></td></tr><tr><td>Z</td><td><math>\frac{1}{2}</math></td></tr></table>"#
            let preview = MarkdownRenderer.document(for: source, complexTableHTML: rich)
            check(preview.components(separatedBy: "<table>").count - 1 == 1
                    && preview.components(separatedBy: "Caption α").count - 1 == 1
                    && preview.contains("rowspan=\"2\"") && preview.contains("colspan=\"2\"")
                    && preview.contains(Data("u^2+v^2".utf8).base64EncodedString()),
                  "preview shows one matching rich table, one caption and rendered math while retaining merged structure", failures: &failures)
            let board = NSPasteboard(name: .init("Ticket11.\(UUID().uuidString)"))
            for format in [CopyFormat.lark, .notion] {
                try ClipboardService.copy(format, payload: ClipboardPayload(canonicalMarkdown: source, complexTableHTML: rich, originalPNG: nil), to: board)
                let html = board.string(forType: .html) ?? ""
                let visibleHTML = html.components(separatedBy: "<span data-lark-record-data=").first ?? html
                check(visibleHTML.components(separatedBy: "<table>").count - 1 == 1
                        && visibleHTML.components(separatedBy: "Caption α").count - 1 == 1
                        && html.contains("rowspan=\"2\"") && html.contains("colspan=\"2\"")
                        && board.string(forType: .string) == source,
                      "\(format.title) replaces the matching Markdown table with its rich representation without duplicate table or source fallback", failures: &failures)
                if format == .notion {
                    let data = board.data(forType: NotionClipboardDocument.nativeType) ?? Data()
                    let json = String(decoding: data, as: UTF8.self)
                    check(json.components(separatedBy: "\"type\":\"table\"").count - 1 == 1
                            && json.components(separatedBy: "\"⁍\"").count - 1 == 4,
                          "Notion native copy has exactly one table and preserves before/table/after equations", failures: &failures)
                }
            }
            let legacy = rich.replacingOccurrences(of: "<math>u^2+v^2</math>", with: "$u^2+v^2$")
                .replacingOccurrences(of: #"<math>\frac{1}{2}</math>"#, with: #"$\frac{1}{2}$"#)
            let legacySource = source.replacingOccurrences(of: "$5 and $10", with: #"\$5 and \$10"#)
            let legacyPreview = MarkdownRenderer.document(for: legacySource, complexTableHTML: legacy)
            check(legacyPreview.components(separatedBy: "<table>").count - 1 == 1
                    && legacyPreview.contains(Data("u^2+v^2".utf8).base64EncodedString())
                    && legacyPreview.range(of: "Before")!.lowerBound < legacyPreview.range(of: "<caption>")!.lowerBound
                    && legacyPreview.range(of: "<caption>")!.lowerBound < legacyPreview.range(of: "After")!.lowerBound,
                  "existing saved rich tables render once, recover corroborated math and keep source reading order", failures: &failures)
            try ClipboardService.copy(.notion, payload: ClipboardPayload(canonicalMarkdown: legacySource, complexTableHTML: legacy, originalPNG: nil), to: board)
            let legacyData = board.data(forType: NotionClipboardDocument.nativeType) ?? Data()
            let native = try JSONSerialization.jsonObject(with: legacyData) as? [String: Any]
            let blocks = native?["blocks"] as? [[String: Any]] ?? []
            let types = blocks.compactMap { envelope -> String? in
                guard let id = envelope["blockId"] as? String,
                      let subtree = envelope["blockSubtree"] as? [String: Any],
                      let values = subtree["block"] as? [String: [String: Any]],
                      let value = values[id]?["value"] as? [String: Any] else { return nil }
                return value["type"] as? String
            }
            check(types == ["text", "text", "table", "text"]
                    && String(decoding: legacyData, as: UTF8.self).components(separatedBy: "\"⁍\"").count - 1 == 4
                    && board.string(forType: .string) == legacySource,
                  "normal copy of an old record retains one caption/table at its source position and all four equations", failures: &failures)
            let twice = source + "\n\n" + source
            check(MarkdownRenderer.document(for: twice, complexTableHTML: rich)
                    .components(separatedBy: "<table>").count - 1 == 2,
                  "matching one rich representation does not collapse two intentional source tables", failures: &failures)
        } catch { failures.append("single rich table across preview and copy: \(error)") }
        do {
            let source = #"Before $x^2$."# + "\n\nCaption α\n\n| Group | | Formula |\n| --- | --- | --- |\n| Keep <b>literal</b> `code` \\$5 and \\$10 | Y | $u^2+v^2$ |\n| | Z | $\\frac{1}{2}$ |\n\nAfter $z_0$."
            let complex = #"<table><caption>Caption α</caption><tr><th colspan="2">Group</th><th>Formula</th></tr><tr><td rowspan="2">Keep literal `code` $5 and $10</td><td>Y</td><td>$u^2+v^2$</td></tr><tr><td>Z</td><td>$\frac{1}{2}$</td></tr></table>"#
            let board = NSPasteboard(name: .init("Ticket12.\(UUID().uuidString)"))
            try ClipboardService.copy(.lark, payload: ClipboardPayload(canonicalMarkdown: source, complexTableHTML: complex, originalPNG: nil), to: board)
            if let native = readChromiumCustomData(board.data(forType: .init("org.chromium.web-custom-data")))?["docx/record"],
               let data = native.data(using: .utf8),
               let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let records = object["recordMap"] as? [String: [String: Any]] {
                let snapshots = records.values.compactMap { $0["snapshot"] as? [String: Any] }
                let tables = snapshots.filter { $0["type"] as? String == "table" }
                let pools = snapshots.compactMap { ($0["text"] as? [String: Any])?["apool"] as? [String: Any] }
                let pairs = pools.flatMap { (($0["numToAttrib"] as? [String: [String]]) ?? [:]).values }
                let equations = pairs.filter { $0.first == "equation" }.compactMap { $0.last }
                let texts = snapshots.compactMap { ((($0["text"] as? [String: Any])?["initialAttributedTexts"] as? [String: Any])?["text"] as? [String: String])?["0"] }
                let cells = (tables.first?["cell_set"] as? [String: [String: Any]]) ?? [:]
                let merges = cells.values.compactMap { $0["merge_info"] as? [String: Int] }
                check(tables.count == 1 && equations.sorted() == ["x^2", "u^2+v^2", #"\frac{1}{2}"#, "z_0"].sorted()
                        && merges.contains { $0["col_span"] == 2 } && merges.contains { $0["row_span"] == 2 }
                        && texts.contains("Keep literal code $5 and $10")
                        && !texts.joined().contains("<b>") && !texts.joined().contains(#"\$5"#)
                        && board.data(forType: NotionClipboardDocument.nativeType) == nil
                        && board.string(forType: .html)?.contains("lark-record-clipboard") == true,
                      "Lark native clipboard combines one merged table, four editable equations and cleaned literal/code/price cells without Notion data", failures: &failures)
                let ids = object["recordIds"] as? [String] ?? []
                check(ids.compactMap { records[$0]?["snapshot"] as? [String: Any] }.compactMap { $0["type"] as? String } == ["text", "text", "table", "text"],
                      "Lark native copy preserves before/caption/table/after source order", failures: &failures)
            } else { failures.append("Lark normal copy lacks self-contained native docx/record formula-table data") }
        } catch { failures.append("Lark native formula-table copy: \(error)") }
        do {
            let source = "# Title 🧮\n\n**bold** and *italic* and `literal $not_math$`.\n\n> Quoted 中文 $x^2$.\n\n- Bullet $y_0$\n\n```text\n$code_only$\n第二行 🧮\n```"
            let board = NSPasteboard(name: .init("Ticket12Wire.\(UUID().uuidString)"))
            try ClipboardService.copy(.lark, payload: ClipboardPayload(canonicalMarkdown: source, complexTableHTML: nil, originalPNG: nil), to: board)
            let json = readChromiumCustomData(board.data(forType: ChromiumClipboardData.type))?["docx/record"] ?? "{}"
            let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] ?? [:]
            let records = object["recordMap"] as? [String: [String: Any]] ?? [:]
            let snapshots = records.values.compactMap { $0["snapshot"] as? [String: Any] }
            let op = try NSRegularExpression(pattern: #"((?:\*[0-9a-z]+)*)(?:\|([0-9a-z]+))?\+([0-9a-z]+)"#)
            let mark = try NSRegularExpression(pattern: #"\*([0-9a-z]+)"#)
            var valid = true, equationCount = 0
            var styles = Set<String>(), content = [String]()
            for snapshot in snapshots {
                guard let text = snapshot["text"] as? [String: Any],
                      let initial = text["initialAttributedTexts"] as? [String: Any],
                      let value = (initial["text"] as? [String: String])?["0"],
                      let encoded = (initial["attribs"] as? [String: String])?["0"],
                      let pool = (text["apool"] as? [String: Any])?["numToAttrib"] as? [String: [String]] else { continue }
                content.append(value)
                let ns = value as NSString
                var cursor = 0, opCursor = 0
                for match in op.matches(in: encoded, range: NSRange(encoded.startIndex..., in: encoded)) {
                    let length = Int((encoded as NSString).substring(with: match.range(at: 3)), radix: 36) ?? -1
                    guard match.range.location == opCursor, length > 0, cursor + length <= ns.length else { valid = false; break }
                    let segment = ns.substring(with: NSRange(location: cursor, length: length))
                    let lines = match.range(at: 2).location == NSNotFound ? 0 : Int((encoded as NSString).substring(with: match.range(at: 2)), radix: 36) ?? -1
                    valid = valid && lines == segment.filter { $0 == "\n" }.count
                    let attributes = (encoded as NSString).substring(with: match.range(at: 1))
                    for atom in mark.matches(in: attributes, range: NSRange(attributes.startIndex..., in: attributes)) {
                        let number = Int((attributes as NSString).substring(with: atom.range(at: 1)), radix: 36) ?? -1
                        guard let pair = pool[String(number)], pair.count == 2 else { valid = false; continue }
                        styles.insert(pair[0])
                        if pair[0] == "equation" { equationCount += 1; valid = valid && segment == " " }
                    }
                    cursor += length; opCursor += match.range.length
                }
                valid = valid && cursor == ns.length && opCursor == encoded.utf16.count
            }
            let types = snapshots.compactMap { $0["type"] as? String }
            check(valid && equationCount == 2 && styles.isSuperset(of: ["bold", "italic", "inlineCode"])
                    && types.contains("heading1") && types.contains("quote_container") && types.contains("bullet") && types.contains("code")
                    && content.contains("Title 🧮") && content.contains("Quoted 中文  .")
                    && content.contains("$code_only$\n第二行 🧮")
                    && snapshots.allSatisfy { $0["author"] == nil && $0["doc_info"] == nil },
                  "Lark native text decodes with valid UTF-16/line attributes, keeps styles/quotes/code and equations, and carries no account metadata", failures: &failures)
        } catch { failures.append("Lark native text protocol: \(error)") }
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
            let acceptanceBoard = NSPasteboard.withUniqueName()
            defer { acceptanceBoard.releaseGlobally() }
            try ClipboardService.copy(
                .markdown,
                payload: ClipboardPayload(
                    canonicalMarkdown: Ticket03AcceptanceFixture.initialMarkdown,
                    complexTableHTML: nil, originalPNG: nil
                ),
                to: acceptanceBoard
            )
            check(
                Ticket03PasteboardInspector.inspect(.markdown, pasteboard: acceptanceBoard),
                "initial accepted Markdown clipboard is inspectable before editing",
                failures: &failures
            )
            try ClipboardService.copy(
                .lark,
                payload: ClipboardPayload(
                    canonicalMarkdown: Ticket03AcceptanceFixture.editedMarkdown,
                    complexTableHTML: nil, originalPNG: nil
                ),
                to: acceptanceBoard
            )
            check(
                Ticket03PasteboardInspector.inspect(.lark, pasteboard: acceptanceBoard),
                "edited accepted Lark clipboard is inspectable after correction",
                failures: &failures
            )
            try ClipboardService.copy(
                .notion,
                payload: ClipboardPayload(
                    canonicalMarkdown: "Unrelated partial result.",
                    complexTableHTML: nil, originalPNG: nil
                ),
                to: acceptanceBoard
            )
            check(
                !Ticket03PasteboardInspector.inspect(.notion, pasteboard: acceptanceBoard),
                "Notion acceptance inspection rejects matching types with unrelated content",
                failures: &failures
            )
            for source in [Ticket03AcceptanceFixture.initialMarkdown, Ticket03AcceptanceFixture.editedMarkdown] {
                for format in CopyFormat.visibleFormats {
                    try ClipboardService.copy(
                        format,
                        payload: ClipboardPayload(canonicalMarkdown: source, complexTableHTML: nil, originalPNG: nil),
                        to: acceptanceBoard
                    )
                    check(
                        Ticket03PasteboardInspector.inspect(format, pasteboard: acceptanceBoard, expectedMarkdown: source),
                        "accepted three-format clipboard preserves its declared fixture stage",
                        failures: &failures
                    )
                    if format == .lark || format == .notion {
                        let originalHTML = acceptanceBoard.string(forType: .html) ?? ""
                        let partialHTML = source == Ticket03AcceptanceFixture.initialMarkdown
                            ? "Before $x^2$. $$y = x + 1$$ COMPLETE-CELL-END After the table.<table></table><math>WRONG</math>"
                            : "$$e^{i\\pi} = -1$$ $\\pi$ Circle constant Euler<table></table><math>WRONG</math>"
                        acceptanceBoard.setString(partialHTML, forType: .html)
                        check(
                            !Ticket03PasteboardInspector.inspect(format, pasteboard: acceptanceBoard, expectedMarkdown: source),
                            "acceptance inspector rejects truncated HTML despite correct full source and native types",
                            failures: &failures
                        )
                        let header = source == Ticket03AcceptanceFixture.initialMarkdown
                            ? "<th>Name</th><th>Value</th>" : "<th>Symbol</th><th>Meaning</th>"
                        let swapped = source == Ticket03AcceptanceFixture.initialMarkdown
                            ? "<th>Value</th><th>Name</th>" : "<th>Meaning</th><th>Symbol</th>"
                        acceptanceBoard.setString(originalHTML.replacingOccurrences(of: header, with: swapped), forType: .html)
                        check(
                            !Ticket03PasteboardInspector.inspect(format, pasteboard: acceptanceBoard, expectedMarkdown: source),
                            "acceptance inspector rejects reordered fixture columns",
                            failures: &failures
                        )
                        if format == .notion {
                            let formulas = source == Ticket03AcceptanceFixture.initialMarkdown
                                ? ["x^2", "y = x + 1"] : ["e^{i\\pi} = -1", "\\pi", "e"]
                            for formula in formulas {
                                let annotation = "<annotation encoding=\"application/x-tex\">\(formula)</annotation>"
                                check(originalHTML.contains(annotation), "known Notion fixture formula has a public TeX annotation", failures: &failures)
                                acceptanceBoard.setString(originalHTML.replacingOccurrences(of: annotation, with: "<annotation encoding=\"application/x-tex\">WRONG</annotation>"), forType: .html)
                                check(
                                    !Ticket03PasteboardInspector.inspect(format, pasteboard: acceptanceBoard, expectedMarkdown: source),
                                    "acceptance inspector rejects wrong Notion formula annotation",
                                    failures: &failures
                                )
                            }
                        }
                        acceptanceBoard.setString(originalHTML, forType: .html)
                    }
                    let differentStage = source == Ticket03AcceptanceFixture.initialMarkdown
                        ? Ticket03AcceptanceFixture.editedMarkdown : Ticket03AcceptanceFixture.initialMarkdown
                    check(
                        !Ticket03PasteboardInspector.inspect(format, pasteboard: acceptanceBoard, expectedMarkdown: differentStage),
                        "acceptance clipboard cannot satisfy a different fixture stage",
                        failures: &failures
                    )
                }
            }
        } catch {
            failures.append("initial acceptance clipboard inspection")
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

        let serviceHeaderMarkdown = """
        | <b>Method</b> | <strong>Value</strong> |
        | --- | --- |
        | Baseline | $x^2$ |
        """
        let serviceHeaderPreview = MarkdownRenderer.document(for: serviceHeaderMarkdown)
        check(
            serviceHeaderPreview.contains("<th>Method</th>")
                && serviceHeaderPreview.contains("<th>Value</th>"),
            "service bold wrappers do not become literal markup in preview table headers",
            failures: &failures
        )
        let literalHeaderPreview = MarkdownRenderer.document(for: """
        Outside <b>literal</b>.

        | `<b>literal</b>` | $x^2$ |
        | --- | --- |
        | A < B | x<sup>2</sup> |
        """)
        check(
            literalHeaderPreview.contains("Outside &lt;b&gt;literal&lt;/b&gt;.")
                && literalHeaderPreview.contains("<code>&lt;b&gt;literal&lt;/b&gt;</code>")
                && literalHeaderPreview.contains("x&lt;sup&gt;2&lt;/sup&gt;")
                && literalHeaderPreview.contains("data-tex="),
            "table header cleanup preserves literal code, math and default raw-HTML escape",
            failures: &failures
        )

        // Literal service fixtures captured from the authored T04/T13 PNGs.
        let serviceMathTables: [(String, String, String)] = [
            (
                "Greek table",
                #"""
                | <b>Symbol</b> | <b>Meaning</b> |
                |---------------|----------------|
                | $\alpha$      | Learning rate  |
                | $\beta$       | Momentum       |
                """#,
                #"""
                <!DOCTYPE html>
                <html>
                 <head>
                  <meta charset="utf-8"/>
                 </head>
                 <body>
                  <table>
                   <tr>
                    <th data-bbox="84 130 994 304"><b>Symbol</b></th>
                    <th data-bbox="994 130 2318 304"><b>Meaning</b></th>
                   </tr>
                   <tr>
                    <td data-bbox="84 304 994 476"><math>\alpha</math></td>
                    <td data-bbox="994 304 2318 476">Learning rate</td>
                   </tr>
                   <tr>
                    <td data-bbox="84 476 994 647"><math>\beta</math></td>
                    <td data-bbox="994 476 2318 647">Momentum</td>
                   </tr>
                  </table>
                 </body>
                </html>
                """#
            ),
            (
                "Power table",
                #"""
                | <b>Name</b> | <b>Expression</b> |
                |-------------|-------------------|
                | Square      | $x^2$             |
                | Cube        | $x^3$             |
                """#,
                #"""
                <!DOCTYPE html>
                <html>
                 <head>
                  <meta charset="utf-8"/>
                 </head>
                 <body>
                  <table>
                   <tr>
                    <th data-bbox="86 131 975 304"><b>Name</b></th>
                    <th data-bbox="975 131 2318 304"><b>Expression</b></th>
                   </tr>
                   <tr>
                    <td data-bbox="86 304 975 476">Square</td>
                    <td data-bbox="975 304 2318 476"><math>x^2</math></td>
                   </tr>
                   <tr>
                    <td data-bbox="86 476 975 647">Cube</td>
                    <td data-bbox="975 476 2318 647"><math>x^3</math></td>
                   </tr>
                  </table>
                 </body>
                </html>
                """#
            )
        ]
        for (name, source, rawHTML) in serviceMathTables {
            let canonical = MarkdownNormalizer.normalize(source)
            let preview = MarkdownRenderer.document(for: canonical, complexTableHTML: rawHTML)
            check(
                preview.components(separatedBy: "<table>").count == 2,
                "\(name) preview omits only the fully represented math fallback table",
                failures: &failures
            )
            do {
                let board = NSPasteboard(name: .init("Ticket03ServiceMath.\(UUID().uuidString)"))
                defer { board.releaseGlobally() }
                let payload = ClipboardPayload(canonicalMarkdown: canonical, complexTableHTML: rawHTML, originalPNG: nil)
                for format in [CopyFormat.lark, .notion] {
                    try ClipboardService.copy(format, payload: payload, to: board)
                    check(
                        board.string(forType: .html)?.components(separatedBy: "<table>").count == 2
                            && board.string(forType: .string) == canonical,
                        "\(name) \(format.title) copies one complete table without a lossy duplicate",
                        failures: &failures
                    )
                }
            } catch { failures.append("\(name) whole-table clipboard recovery") }
        }

        let otherMathTable = #"<table><tr><th>Symbol</th><th>Meaning</th></tr><tr><td><math>\gamma</math></td><td>Different</td></tr></table>"#
        let originalGreekTable = #"| Symbol | Meaning |\n| --- | --- |\n| $\alpha$ | Learning rate |"#
            .replacingOccurrences(of: #"\n"#, with: "\n")
        check(
            MarkdownRenderer.document(for: originalGreekTable, complexTableHTML: otherMathTable)
                .components(separatedBy: "<table>").count == 3,
            "a different math fallback table is retained rather than broadly suppressed",
            failures: &failures
        )
        do {
            let board = NSPasteboard(name: .init("Ticket03MathSafety.\(UUID().uuidString)"))
            defer { board.releaseGlobally() }
            let hostileMathTable = "<table onclick='evil()'><tr><td><math onmouseover='evil()'>x &lt; y</math></td><td><math><script>UNSAFE_MATH_FIXTURE</script>x</math></td></tr></table>"
            try ClipboardService.copy(.richTable, payload: ClipboardPayload(
                canonicalMarkdown: "", complexTableHTML: hostileMathTable, originalPNG: nil
            ), to: board)
            let html = board.string(forType: .html) ?? ""
            check(
                board.string(forType: .string)?.contains("$x < y$") == true
                    && html.contains("$x &lt; y$")
                    && !html.contains("<math") && !html.contains("<script")
                    && !html.contains("onclick") && !html.contains("onmouseover")
                    && !html.contains("UNSAFE_MATH_FIXTURE"),
                "text-only math is inert and decoded once while nested executable markup remains suppressed",
                failures: &failures
            )
        } catch { failures.append("math fallback clipboard safety") }

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


@MainActor
private final class Ticket07StoredMathRecognitionService: RecognitionService {
    func recognize(uploadPayload: UploadPayload, mode: RecognitionMode) async throws -> DatalabResult {
        DatalabResult(markdown: "Before $x^2$.",
                      html: #"<table><caption>Stored α</caption><tr><td rowspan="2">**literal** `code` $5 and $10</td><td><math>u^2+v^2</math></td></tr><tr><td><math>\frac{1}{2}</math></td></tr></table>"#,
                      runtime: 0.01, costSummary: nil, costValue: nil, parseQualityScore: nil, automaticRetryCount: 0)
    }
}

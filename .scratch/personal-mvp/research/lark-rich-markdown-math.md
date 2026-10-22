# Lark rich tables with Markdown-compatible math

Research date: 2026-10-22. Public primary sources only; no owner data,
credentials, authenticated API calls, UI actions or destination writes.

## Result

The smallest justified next experiment is to keep the existing sanitized rich
table HTML and change **actual Lark formula tokens only** from `$TeX$` to
`$$TeX$$`. This is a candidate, not a verified clipboard solution. Do not change
literal prices/code or the accepted Markdown/Notion Copy Formats.

## Verified primary-source facts

1. Feishu's official Markdown syntax table lists formulas as `$$文字$$`.
   The same help article says Markdown from third-party platforms can be
   copied into Docs, with conversion depending on the supported destination
   format. It does not specify an HTML clipboard math contract or guarantee
   parsing inside HTML table cells.
   [Feishu Help: 在文档中使用 Markdown](https://www.feishu.cn/hc/zh-CN/articles/118804574721-%E5%9C%A8%E6%96%87%E6%A1%A3%E4%B8%AD%E4%BD%BF%E7%94%A8-markdown)

2. That article's statement that Markdown cannot insert tables concerns
   in-editor Markdown input shortcuts. It must not be generalized to reject
   the owner's already-observed Markdown table paste behavior.
   [Same official Markdown help article](https://www.feishu.cn/hc/zh-CN/articles/118804574721-%E5%9C%A8%E6%96%87%E6%A1%A3%E4%B8%AD%E4%BD%BF%E7%94%A8-markdown)

3. Docs supports KaTeX equations, including equations in **document table**
   cells through the native equation editor. Spreadsheet cells are a different
   surface and do not support these LaTeX insertions. Therefore tables and
   native formulas are not inherently incompatible in Feishu Docs.
   [Feishu Help: 在文档中使用公式](https://www.feishu.cn/hc/zh-CN/articles/894598450617-%E5%9C%A8%E6%96%87%E6%A1%A3%E4%B8%AD%E4%BD%BF%E7%94%A8%E5%85%AC%E5%BC%8F)

## Unknowns and inference

- Public official sources searched did not establish a supported MIME or
  `data-lark-html-role`/math metadata schema for third-party clipboard producers.
  This is a search limitation, not proof that no private format exists.
- Identical math strings in plain Markdown and HTML do not prove identical
  destination behavior. HTML import may skip Markdown conversion; this remains
  an inference until compared in the actual editor.
- A Docs OpenAPI equation/block schema is not a clipboard schema. An API-based
  write would add account access and a different workflow, and is unnecessary
  for the first experiment.

## Minimal controlled experiment

Use one synthetic private-page sample containing a paragraph formula, a rich
table formula, literal code, `<b>` formatting text, and prices `$5 and $10`.

- A: current sanitized HTML with `$x^2$` and `$\frac{1}{2}$`.
- B: identical HTML except recognized equation tokens use `$$x^2$$` and
  `$$\frac{1}{2}$$`; keep table spans/caption and existing literal cleanup.
- Control: the already-working plain Markdown math path.

Check editable formulas in both positions, preserved backslashes and literal
prices/code, one table, and merged-cell behavior separately. Test B through
the real normal App copy path before declaring it fixed. Use parsed token
metadata rather than a global dollar replacement.

If A/B both remain text while the control works, capture a **bounded synthetic
native Feishu copy** containing one actual equation plus one simple table and
inspect its clipboard formats/HTML. Do not collect unrelated clipboard data,
document identities, owner credentials or inferred API authorization. Compare
that first-party artifact before constructing any private clipboard payload.

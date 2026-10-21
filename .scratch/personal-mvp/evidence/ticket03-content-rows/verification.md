# Ticket 03 follow-up — plain table text and content preview rows

2026-09-06. Worktree `/private/tmp/my_mathpix-ticket03`, branch `ticket03-edit-preview-copy`; baseline `5527b3579a3c3b883b9206df88c522b7e67047c0`.

## Changes

Reproduced the owner-reported GFM-to-TSV formatting-tag leak independently with an offline public `MarkdownNormalizer.markdownTableTSV` test. The new cell projection recognizes a bounded set of inline formatting tags with quote-aware scanning, then uses Foundation's offline inline Markdown parser. Code spans, HTML code contents, formulas, literal comparisons, escaped markup, and entities retain their text semantics. Line breaks/tabs inside cells become spaces so they cannot invent TSV rows or columns. Raw HTML handling in the rendered Markdown preview is unchanged: it remains escaped by default.

Simple-table rich HTML is regenerated from the same plain cell projection; it preserves table structure and cell text, without promising to retain source bold/italic styling. Rich RTF derives from that HTML; plain text and TSV use the exact same table text.

Each available row now displays one line of its prepared text (tail ellipsis at the view boundary) or the prepared original-image thumbnail. Names remain in accessibility labels/IDs and hover help. `PreparedClipboardCopy` is the common immutable conversion result for display and the actual click: truncation/whitespace folding is only a visual projection, never the clipboard input. Availability comes from preparation errors. Mode and runtime remain in the existing bottom footer.

## Actual signed-window verification

Built `dist/MyMathpixTicket03Acceptance.app`, bundle ID `com.byterumi.mymathpix.ticket03acceptance`; launched process 47533. `codesign --verify --deep --strict` passed. CDHash `5bff6e9f8c3145ac964a333ba48a250da0be8247`. This is the actual native production ResultEditorView in the isolated fixture host.

Through Computer Use, opened Edit and entered the source fixture in [inspect-copy.swift](inspect-copy.swift). Visually confirmed long rows stay single-line and end with an ellipsis; names are not visible row titles. Clicked the TSV row, observed Copied, then independently read `.string` and `.tabularText` and compared every character, including the off-screen `COMPLETE-CELL-END` and final code/comparison row. Formatting tags were absent while `**literal**` and `a < b > c` remained.

Clicked Rich Table, Markdown, and Combined Output separately. After each click, ran the standalone AppKit pasteboard inspector, which does not use production conversion code. All passed:

```text
CONTENT_ROW_COPY_OK format=tsvTable full_content=yes public_types=yes literal_code=yes
CONTENT_ROW_COPY_OK format=richTable full_content=yes public_types=yes literal_code=yes
CONTENT_ROW_COPY_OK format=markdown full_content=yes public_types=yes literal_code=yes
CONTENT_ROW_COPY_OK format=combinedOutput full_content=yes public_types=yes literal_code=yes
TICKET03_PASTEBOARD_OK format=originalImage values=yes public_types=yes
TICKET03_PASTEBOARD_OK format=formulaOutput values=yes public_types=yes
```

Rich inspection checked HTML and decoded RTF cell semantics as well as exact TSV/plain values. TSV-only inspection checked absence of HTML/RTF. Original Image was clicked through the thumbnail row and checked with the existing signed inspector. Edited to `$$x^2 + y^2$$`, confirmed the raw formula row became available and both table rows showed No table, clicked the formula row, and independently verified `x^2 + y^2`. Observed Copied disappear. Restored the initial mixed fixture and collapsed Edit, leaving the App open for review.

This is a targeted six-format regression run with a new formatted/long fixture. The historical all-in-one scalar acceptance script was not rerun for its old exact source sequence; no new claim is made that this run completed that historical reporter sequence.

## Screenshots

- [Default content-only rows](default.png)
- [TSV long-row ellipsis and success feedback](tsv-copied.png)
- [Formula content and unavailable table rows](formula.png)

These are actual native window captures. The TSV regression screenshot intentionally shows literal HTML in the top preview because that preview still escapes raw HTML; the copy rows below show their independently converted representations.

## Tests and reviews

- Red → green: GFM formatting tags/entities/literal comparisons/code/formulas; shared prepared preview-to-pasteboard values; HTML code preservation after the Spec finding.
- Regression: RTF and HTML semantics agree with plain cell text; a long prepared source copies every character; existing offline security, normalization, six clipboard formats, and edit/copy tests pass.
- `./scripts/ticket03_test.sh`: passed.
- `./scripts/test.sh`: passed, 45 checks.
- Swift debug/release compilation and `git diff --check`: passed.

### Standards

Initial review found duplicate eligibility dispatch. UI now retains the preparation result/error; compatibility availability delegates to preparation. Re-review: **0 remaining findings**.

### Spec

Initial review found HTML `<code>**literal**</code>` was reinterpreted as Markdown. Protected HTML code plus entity decoding fixes the loss; regression passed. Re-review: **0 remaining findings**.

## Scope and remaining integration

No user token access, credential migration, real recognition request, other-ticket worktree read, main-branch modification, or full-content LaTeX extension. Existing UI layout and bottom mode/runtime placement remain. The original Ticket 03 branch is ready for the coordinator's integration workflow. Destination-app paste behavior remains separate from the verified macOS pasteboard contract; no Notion/Feishu native blocks are promised.

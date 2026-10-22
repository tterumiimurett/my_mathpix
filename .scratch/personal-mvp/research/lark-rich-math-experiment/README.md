# Lark formula and rich-table clipboard experiment — 2026-10-22

## Scope

Owner explicitly opened the private `MyMathpix paste test` document for
synthetic testing. No other document/chat, credentials, authenticated API,
recognition request, source URL spoofing or workspace identity reuse is used.
Raw native HTML is piped directly through the bounded inspector; only anonymous
schema/known fixture content is retained. The native `recordMap`, source URL and
browser internal token are never saved or reused.

## Actual destination results

| Sample | Table kind | Table equations | Literal/price behavior |
| --- | --- | --- | --- |
| Plain Markdown / TREF | Docs table | Render | Raw `<b>` and price backslashes remain |
| App rich HTML baseline | Embedded sheet | Literal `$...$` | HTML tag/price cleanup retained |
| Same HTML, double dollars | Embedded sheet | Literal `$$...$$` | Cleanup retained |
| `ace-table` class | Docs table | Literal `$...$` | Cleanup retained |
| Docs table + double dollars | Docs table | Literal `$$...$$` | Cleanup retained |
| Docs table + isolated equation span metadata | Docs table | Literal fallback | Cleanup retained |
| Synthetic native record, HTML only | Fallback text | No native table imported | Not a working solution |
| Synthetic native record + `docx/record` Chromium MIME and hidden marker | **Docs table** | **Render** | **Clean text, `$5 and $10`** |

The last sample visibly rendered paragraph x² and a/b, table u²+v² and 1/2,
with a merged two-column header. Accessibility also reports `Columns: 0-1`.
The table is editable, with native cells and equation atoms rather than a
flattened image. The payload has 23 locally generated records and zero external
identities. This proves the synthetic protocol experiment; normal installed-App
copy must still be checked separately.

## Observed first-party format

- Chromium custom MIME key: `docx/record`.
- HTML marker: `span.lark-record-clipboard` with `data-lark-record-format` and
  JSON `data-lark-record-data`.
- Self-contained page/text/table/table_cell snapshots and locally linked IDs.
- `text.initialAttributedTexts` uses UTF-16 lengths and base-36 attribute ops.
- Equation atoms are spaces carrying `equation` (TeX) and random `objectID`
  attributes in the text pool. Code uses `inlineCode`; bold/italic are boolean
  attributes. A standalone source equation remains on its own paragraph.
- Tables carry row/column sets, cell references and `merge_info` spans.
- None of the owner's author/editor IDs, root page IDs, sheet tokens, cookies,
  source URL or browser security tokens are needed in generated output.

This is an observed private clipboard contract, not an official public API.
Compatibility is bounded to the tested current macOS Feishu client. Public
help findings are in `../lark-rich-markdown-math.md`; shortcut documentation
alone did not establish the working transport.

## Production candidate and remaining check

`LarkNativeClipboardDocument` generates this structure from the production
Markdown/tree and shared table layout. It preserves rich geometry, uses matching
cleaned source cells, and carries genuine formulas as native equation attributes.
Safe rich HTML and original Markdown remain fallback representations. The
Notion Chromium encoder was moved unchanged into a shared helper.

`checks/red.log` reproduces the missing native Copy Lark payload.
`checks/green.log` covers the normal clipboard boundary, one table/caption,
row/column spans, code/prices, UTF-16/line attributes, styles, reading order,
Notion/Markdown regressions and recognition → disk → reload → model copy.
`checks/basic.log` passes 48 basic checks plus daily-workflow checks.
`checks/build.log` is the signed release build.

Candidate executable SHA256:
`d1a143db9dd4a6554892e2111dd50bb1e5feb739a1c6f5188b96a2dd44fce544`.
It is built at `dist/MyMathpix.app`; installation/actual App-button destination
acceptance is pending because the desktop is locked. The currently installed
`abb2215a...` artifact is the Notion/Markdown owner-accepted version. Do not
confuse the successful native fixture with final App acceptance.


### Installed App checkpoint after unlock

Candidate d1a143db is installed at `/Applications/MyMathpix.app` and strict
signature/hash verified. Prior accepted abb2215a is backed up in
`dist/backups/MyMathpix-before-lark-native-abb2215a.zip`. Actual App Copy Lark
from the existing 17:40 RICH record was captured with the bounded inspector:
`../notion-inline-math-experiment/app-lark-native-records.json`. The clipboard
contains native docx/record plus HTML/Markdown. Coordinate clicks in Feishu
fail noWindowsAvailable; keyboard paste produced no insertion. Owner has been
asked for one manual paste. Destination acceptance and current-artifact screen
capture permission are still unverified. Earlier locked-device note above is historical.


## Final installed-App owner acceptance

2026-10-22 — Owner tested all three installed App formats and accepted them:
“无敌棒! 三个都测试了, 没问题.” This supersedes the pending/failure checkpoints
above for the current d1a143db clipboard implementation. Owner authorized
GitHub publication. No claim is made about other destination versions, and
Issue 09 remains open.

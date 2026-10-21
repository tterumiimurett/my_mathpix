# Ticket 03 — Markdown / Notion copy follow-up

Status: implemented candidate; destination paste acceptance pending.

## Owner's current direction

Only two visible immediate-copy rows: Markdown and Notion. Each has one small secondary-color title on the left and a one-line preview on the right. No persistent explanatory prose. Markdown continues to copy the complete canonical source unchanged. Notion copies the complete mixed result with rich tables and equation representations intended to remain editable, not just the first table or a screenshot. This supersedes the earlier six-row/source-only UI. Existing legacy public copy seams and conservative Pure Formula automatic copying remain for baseline compatibility.

## Implementation and evidence

- `ClipboardService.copy(.notion, …)` writes complete HTML, a complete source fallback, v3 structured blocks under a valid macOS UTI, and the structured MIME payload inside Chromium DataTransfer custom data. No document API calls, credentials, external renderer, browser injection, or another worktree are involved.
- The adapter shares the existing escaped Markdown rendering pipeline, cleans table cells at the existing `TableCellText` boundary, emits static MathML from bundled KaTeX through JavaScriptCore, and provides native inline equation decorations and standalone equation blocks. No scripts, remote fonts/images, or renderer resources enter the copied document.
- Every real Markdown table is copied, in order, with surrounding text. Unrepresented safe Complex Table Output is retained, including its caption. Merged HTML is kept as HTML; native simple-table and source fallbacks use the existing occupied-cell grid projection, with empty slots for merged cells. Native merge fidelity is not promised.
- Fixed code-span rendering so literal stars and dollar signs do not become emphasis or equations. This is covered through the actual Notion pasteboard output.
- The initial isolated App fixture now contains an inline formula, standalone formula, table, and surrounding text, so the owner can test the Notion button directly without replacing source by hand.

Red-capable tests are in the existing `--ticket03-self-test` public pasteboard seam. The old text-only implementation failed the mixed-content test; new code/literal coverage exposed emphasis parsing inside code spans; a complex-table test exposed lost captions/source fallback. Each received its corresponding fix. Tests read actual pasteboard values, independently decode Chromium's binary envelope, inspect equation block order and inline decorations, compare a literal display equation, and cover all-table copying, entities, Unicode, inert raw HTML, literal code, complete content, and unchanged automatic-copy semantics.

## Protocol provenance and limitations

- [Chromium custom clipboard serialization](https://chromium.googlesource.com/chromium/src/+/HEAD/ui/base/clipboard/custom_data_helper.cc) defines the Pickle entry count and UTF-16 key/value records. Our encoder is independently consumed in tests, rather than tested against its own output helper.
- [NotionX block types](https://github.com/NotionX/react-notion-x/blob/master/packages/notion-types/src/block.ts) and [rich-text decorations](https://github.com/NotionX/react-notion-x/blob/master/packages/notion-types/src/core.ts) describe the unofficial equation/table shapes. These are not a supported Notion clipboard API.
- [REA's Notion clipboard investigation](https://rea.vaked.dev/showcase/notion/) records the v3 MIME and desktop virtual-clipboard ID mechanism. A third-party native clipboard payload may be ignored by a particular Notion release, especially when desktop paste expects a locally cached copy ID. No synthetic cache ID, user identity, or workspace ID is fabricated to bypass that mechanism.
- [Notion's equation documentation](https://www.notion.com/help/math-equations) does not guarantee that ordinary HTML/LaTeX paste creates editable native equations. Static MathML is a fallback, not proof of native editability.

## Acceptance still required

In the rebuilt `my_mathpix_ticket3` App, click **Notion**, paste with ordinary Command-V into an empty Notion paragraph, and check:

1. Both surrounding text paragraphs survive, in order.
2. The inline `x^2` and standalone `y = x + 1` display as equations and can each be clicked/edited in Notion.
3. The entire table survives as editable rows and columns, with `α © α`, literal `**literal**`, comparisons, and `COMPLETE-CELL-END` intact.

Record Notion desktop vs browser and its version if it fails. A successful local self-test, MathML rendering, generic HTML paste, or Typora rich-table paste is not destination acceptance. Keep Ticket 03 claimed until this new outcome actually passes, or accurately report the unsupported target behavior.

## Verification / review

- `./scripts/ticket03_test.sh`: passed after the final review fix. Tests include public pasteboard types/values and an independent consumer of the Chromium envelope.
- `./scripts/test.sh`: passed all 45 checks after the final code changes.
- `git diff --check`: passed.
- Release build with `MYMATHPIX_APP_NAME=my_mathpix_ticket3` and `MYMATHPIX_BUNDLE_ID=com.byterumi.mymathpix.ticket3`: passed.
- `codesign --verify --deep --strict dist/my_mathpix_ticket3.app`: passed.
- Actual signed bundle executable `--ticket03-self-test`: passed, including offline JavaScriptCore/KaTeX and clipboard writes inside the sandbox.
- Independent Standards review found one P2: decoded Complex Table cells were reparsed as Markdown, corrupting literal stars/backticks/currency. Reproduced it through the public pasteboard, fixed it by emitting literal runs, and reran the focused suite successfully. Standards re-review: zero remaining findings.
- Independent Spec re-review: zero remaining actionable findings. It also confirmed the same complex-table fix and correctly pending destination acceptance.
- Reopened the signed isolated App with the new initial fixture and refreshed the local test page. No real Notion destination pass is recorded here.

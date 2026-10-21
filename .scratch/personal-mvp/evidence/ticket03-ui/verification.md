# Ticket 03 — compact Result Editor verification

Verified on 2026-09-05 in `/private/tmp/my_mathpix-ticket03`, branch `ticket03-edit-preview-copy`. Review baseline: `fb3c32321f34c6102f7489794a74e19831a3ec72`. Latest owner-confirmed compact UI decisions are recorded in the Ticket 03 Comments; they supersede the initial always-visible workbench layout.

## Real signed App

Built and launched `dist/MyMathpixTicket03Acceptance.app` with bundle ID `com.byterumi.mymathpix.ticket03acceptance`. The acceptance host uses the production `ResultEditorView` at 470 × 700 points; only this isolated launch changes window dimensions. The native window was read, operated, and captured through Computer Use. An earlier native-pipe failure was overcome by selecting the full signed App path. Intermittent AX click errors were followed by fresh observations confirming the action's actual result.

The source fixture is deterministic and has no Datalab requests. It contains a formula and one editable GFM table, without artificial result headings or formula-label prose. Complex-table fallback and duplicate-suppression are tested separately at the renderer/clipboard seams.

Observed through the actual window:

- Default: rendered formula and exactly one table, Original and Edit collapsed, all six named copy rows visible, Formula Output disabled with Pure formula only.
- Original: independent expansion in a fixed 180-point, aspect-fit region; no crop or stretching. Original and Edit can be open together.
- Edit: changed the formula from `e^{i\pi} + 1 = 0` to `e^{i\pi} = -1`; the real WebKit accessibility tree and screenshot displayed the new rendered formula and retained table.
- Copy: clicked whole rows for Markdown, Combined Output, TSV Table, Rich Table, Original Image. Observed row-local Copied feedback, then restoration to Available. Copy/disclosure actions did not recreate the preview's accessibility tree after unchanged-document caching.
- Pure Formula: edited source to `$$x^2 + y^2$$`; preview updated, Formula Output became available, TSV/Rich rows became disabled with No table. Clicked Formula Output and independently verified raw `x^2 + y^2` on the pasteboard.
- Restored edited mixed content and confirmed the formula-plus-table preview and unavailable Formula Output state.
- Opened the Copy Formats information popover and observed the explicit Native Paste / native Notion and Feishu block boundary.

Every copy action was independently verified with `ticket03_signed_app_acceptance.sh inspect-copy <format>`, returning `TICKET03_PASTEBOARD_OK ... values=yes public_types=yes` for all six formats. Rich Table included HTML, RTF, TSV, and plain text; original image included PNG and TIFF.

Final live verification returned:

```text
TICKET03_SIGNED_APP_OK pid=18605 editor=yes edit_preview=yes offline=yes copy_formats=6 rich_types=4 native_paste=no redacted=yes
```

The scalar-only [signed App evidence](signed-app-evidence.json) is bound to run `3784ac7e-7663-4012-ad31-b60b3a0917fc` and process 18605. Evidence is emitted passively by the actual UI journey. The disclosure evidence now records whether Original and Edit were actually expanded, instead of claiming hidden content is visible.

`codesign --verify --deep --strict` passed. CDHash: `69798291fc175abf1062ebed4b5bc6139f255861`; arm64, ad-hoc signature, App Sandbox entitlement verified by the acceptance script.

## Screenshots

- [Default compact result](compact-default.png)
- [Expanded Original](original-expanded.png)
- [Original, edited source, and updated preview](expanded-edit.png)
- [Row-local successful copy feedback](copy-feedback.png)
- [Pure Formula and unavailable table formats](pure-formula.png)
- [Copy Formats information](copy-help.png)

All PNGs are captures of the actual signed App window, not mockups or browser recreations.

## Automated regression

`./scripts/ticket03_test.sh` passed after the final code changes. New red → green checks exercised existing public clipboard/AppModel boundaries: a copy action reports success only on a successful write; rejected formula copy preserves existing mixed clipboard content; format availability correctly distinguishes formula, table, and image payloads. Review exposed formula-plus-HTML-table classification: the regression failed before the fix and passed after full-payload classification was shared by automatic, manual, and UI availability paths.

The focused suite also covers deterministic/idempotent normalization; single-dollar inline and double-dollar display formulas; protected code spans/fences; editable GFM tables; escaped pipes; raw HTML escaping; safe table tags/attributes; blocked scripts/events/frames/remote content; offline CSP and navigation policy; duplicate fallback-table suppression; rich-table public pasteboard representations; original PNG bytes; and the complete edit-preview-copy journey. No second model or generated rewriting was introduced.

`./scripts/test.sh` passed: `MyMathpix self-test passed (45 checks).` Swift debug and release compilation passed. `git diff --check` passed.

## Standards

Parallel source review and follow-up review: **0 actionable findings**. Native APIs, glossary terminology, presentation-only disclosure/feedback state, and shared clipboard classification conform to repository standards. No actionable baseline code smell remained.

## Spec

Initial review: **1 finding**, formula-only Markdown plus retained safe HTML table incorrectly qualified for Formula Output. Fixed across UI availability, explicit clipboard copy, and automatic recognition copy. Re-review: **0 remaining actionable findings**.

## Limits and integration

- Full-content LaTeX export remains an undecided feature. Formula Output is still raw LaTeX for one Pure Formula only; text/table content is not silently omitted to enable it.
- Ticket 04 owns the ordinary capture-result window host and top-left placement on the capture display. Integration surface: `ResultEditorView(item: model.selectedItem).environmentObject(model).id(item.id)`, unwrapping the optional selected item first. The same model selection must identify the displayed record.
- External Notion/Feishu paste behavior and native blocks were not validated or promised. Public macOS pasteboard types and values were verified; destination-specific manual paste acceptance remains useful.
- Real Datalab recognition, screenshot-to-result integration across other tickets, dark appearance, and the final assembled-app gate remain their respective later/integration checks. This UI run used isolated fixture recognition and the current macOS appearance.

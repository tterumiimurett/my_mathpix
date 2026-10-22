# 03 — Make recognized content editable, previewable, and copyable

**What to build:** The owner can compare the original Snippet with editable Canonical Markdown and an offline rendered preview, correct formulas or tables, and choose a Copy Format suitable for a Paste Target. Pure Formula capture remains fast, while mixed content waits for review and no Native Paste behavior is falsely promised.

**Blocked by:** 01 — Make Screen Capture survive through a mock result.

**Status:** resolved

## Suggested agent split

- **Work package A — Output and preview contract:** cover deterministic normalization, Pure Formula classification, Combined Output, safe complex-table handling, and offline rendering.
- **Work package B — Clipboard experience:** cover explicit formula, Markdown, table, rich-content, and image representations plus pasteboard-level verification.
- The main agent fixes the Canonical Markdown and Formula Output contracts before parallel work and verifies edits flowing through preview and copy as one user journey.

## Acceptance criteria

- [x] The compact Result Editor emphasizes the rendered preview by default. Independent Original and Edit actions reveal a fixed-size, aspect-fit Snippet and editable Canonical Markdown on demand; both can be open while the preview remains visible. Source edits update the preview without network access.
- [x] Normalization is deterministic: inline formulas use single-dollar delimiters, display formulas use double-dollar delimiters, simple tables remain editable GitHub-Flavored Markdown, and no generative rewrite is introduced.
- [x] Pure Formula classification accepts only one formula plus whitespace; only that case may automatically copy raw Formula Output.
- [x] Mixed content remains one Combined Output and waits for owner confirmation before copying.
- [x] Raw HTML is escaped by default, and Complex Table Output is limited to safe table-related content with no executable events, frames, navigation, or remote resources.
- [x] Explicit actions provide Formula Output, Markdown, Combined Output, TSV table, rich table, and original image representations.
- [x] Rich-table copy offers compatible HTML, RTF, TSV, and plain-text representations, verified by reading the public pasteboard values and types.
- [x] Labels and help text distinguish Copy Formats from Native Paste and do not promise native Notion or Feishu blocks.

## Comments

### Owner acceptance and resolution — 2026-10-21

The owner confirmed the current Markdown / Lark / Notion candidate (`ec7e140`) with “very nice，验证通过” and explicitly requested resolving Ticket 03 and merging it into main. This accepts the latest three-action workflow and supersedes the earlier pending-destination status. The owner explicitly excludes the known Notion inline-equation defect from this resolution: it remains unresolved and must be addressed later, not represented as fixed. Track it separately in [07 — Fix Notion inline math paste](07-notion-inline-math.md).

### Owner-directed Lark format and deferred Notion inline issue — 2026-10-21

Supersedes the two-action UI: show exactly Markdown, Lark, Notion in that order, retaining small secondary-color titles on the left with one-line content previews and no inline explanatory prose. Lark copies the whole result with rich HTML tables and literal Markdown inline/display formulas (`$…$` / `$$…$$`), without Notion native clipboard data or MathML. Markdown stays source-only and unchanged. Share existing safe table conversion and preserve surrounding text, all tables, code literals, entities, and sanitized Complex Table fallback.

Owner manual results: Markdown works well; Notion display formulas work, but inline math pastes as `Before ‣.`. The owner explicitly deferred the Notion inline fix; do not report it fixed or expand this change into another native-paste investigation. This known limitation is recorded in help/evidence, not extra inline UI prose. The new Lark destination behavior still requires a real paste check after rebuild. No other worktree, recognition service, authentication, or document API changes are authorized.

### Owner-directed Notion copy follow-up — 2026-10-21

Supersedes the six visible Copy Format rows: show only Markdown and Notion, each with a small secondary-color title to the left of the actual content preview and no inline explanatory prose. Preserve Canonical Markdown copying unchanged. The Notion action copies the complete mixed content, with rich tables and editable inline/display equations rather than just the first table. This explicitly extends the earlier source-copy-only scope to an experimental Notion clipboard adapter; it does not authorize document API writes, authentication, browser injection, or modifications to another ticket/worktree. Existing legacy clipboard seams may remain for baseline compatibility and conservative automatic Pure Formula copying.

Verification remains at the pre-agreed public pasteboard types/values boundary plus a real destination paste by the owner. Native equation/table behavior must not be claimed verified solely from local serialization tests. Keep this follow-up claimed until its required destination acceptance succeeds, and record any unsupported content or destination/version limitations accurately.

Candidate implemented and independently reviewed: only Markdown/Notion rows remain visible; Notion preserves complete mixed content with rich HTML, offline MathML, native equation/table clipboard structures, and source fallback. Focused tests, all 45 full-suite checks, strict signature verification, and the signed-bundle focused tests passed. One literal-cell corruption issue found in review was fixed and both re-reviews have zero remaining findings. Actual Notion paste/edit acceptance remains unexecuted, so Status stays claimed. See [candidate verification and limitations](../evidence/ticket03-notion-copy-2026-10-21.md).

### Reopened after independent review — 2026-10-21

Fix the four reviewed Spec defects on this branch: preserve valid LaTeX row spacing and existing formula contents during delimiter normalization; retain column positions when projecting HTML rowspan/colspan to TSV/plain text; correctly decode named and numeric HTML entities without recursively decoding literal entity text; and suppress a Complex Table preview only when it represents the same table as an editable GFM table. An unrelated simple table must not hide a complex table. Add regression coverage at existing normalization, preview, and public clipboard seams. Keep the existing compact UI and output scope.

### Reopened — 2026-09-06

Owner-reported TSV cells leak inline HTML formatting tags. Fix plain-text conversion at the table boundary, preserving literal text, formulas, code, and entities; verify rich table representations too. The new owner decision supersedes format-name-only rows: each vertical immediate-copy row displays a single-line, tail-truncated preview of its actual copied content, with no persistent visible format title. Keep full clipboard payloads, shared conversion for preview/copy, accessible format names, accurate unavailability, and success feedback. Original-image rows use the actual image thumbnail; rich-table rows use their actual plain-text representation. Keep Original/Edit and bottom mode/runtime layout. Full-content LaTeX remains outside scope. Work stays on the Ticket 03 branch.

### Owner-confirmed UI direction — 2026-09-05

The owner confirmed a compact macOS result window after a Grill Me discussion in the coordinating task. This supersedes the initial always-visible editing-workbench layout: emphasize the rendered result at the top; reveal Original and Edit independently on demand; keep one editable Canonical Markdown state. Below the result, list every existing Copy Format vertically with only its format name (no content/code sample), accurate unavailable status, and immediate whole-row copy. Show brief Copied feedback only after successful clipboard writing. Keep formula-only LaTeX semantics; full-content LaTeX export remains undecided and is not implemented.

Preserve the prior fixes: fixed-size aspect-fit original image, no duplicated fallback table when editable GFM exists, no synthetic result heading or formula-label prose in the acceptance fixture, and distinct rich-table versus TSV clipboard representations.

The reusable internal surface is `ResultEditorView(item:)` with the existing `AppModel` environment object and record identity. Ticket 04 originally owned window hosting and captured-display placement. Historically, `8e27ef0` configured a 470 × 700-point **default size for the isolated Ticket 03 launch only**; that was not a verified current production outer frame. [Ticket 08](08-window-roles-regression.md) supersedes that separation: production and Ticket 03 fixture results now share the same floating panel with a 470 × 560-point outer frame including title bar, while explicit App activation opens the large workspace. Current candidate observations and still-open real desktop gates are recorded in [the handoff](../evidence/ticket06-candidate/handoff.md); historical acceptance evidence is unchanged.

The implementation and actual signed-App UI verification completed on 2026-09-05; see Answer and the linked evidence.

## Answer

### Current three-format workflow accepted — 2026-10-21

Resolved by explicit owner acceptance of the signed `my_mathpix_ticket3` candidate at implementation commit `ec7e140`: compact Markdown / Lark / Notion copy actions, unchanged Markdown source, Lark rich tables plus Markdown inline/display formulas, offline preview, deterministic normalization, and safe complete-content copying. Focused/public-pasteboard tests, the full 45-check suite, signed-bundle tests, and Standards/Spec reviews passed; see [accepted candidate evidence](../evidence/ticket03-lark-copy-2026-10-21.md).

**Known unresolved issue:** Notion inline math can paste as `Before ‣.` instead of an editable equation. The owner confirmed Notion display math works and explicitly deferred the inline fix. Ticket 03 resolution does not certify native inline-math support. Follow-up [Ticket 07](07-notion-inline-math.md) remains open.

The owner subsequently confirmed Ticket 04 had merged and authorized Ticket 03 main integration. The Ticket 03 merge preserves Ticket 02 recognition/credential recovery/Usage Records and Ticket 04 history, retry confirmation, shortcut registration, stable main-window identity and result positioning. See [main integration verification](../evidence/ticket03-main-merge-2026-10-21.md). Notion inline math remains explicitly unresolved in Ticket 07.

### Independent review fixes completed — 2026-10-21

Fixed all four reviewed Spec findings: valid LaTeX row spacing survives normalization; HTML rowspan/colspan retain column positions in TSV/plain output; named/numeric entities decode correctly without recursive interpretation; and unrelated complex tables remain visible alongside Markdown tables. Existing same-table duplicate suppression, captions, merged structure, offline security, and Copy Format scope are covered by regression tests.

Each original failure was reproduced before its fix. Focused tests, the full 45-check suite, bundled KaTeX rendering, final release compilation, signature verification, and signed-bundle regressions passed. Independent Standards and Spec re-reviews reported zero remaining findings. See [review-fix verification](../evidence/ticket03-spec-fixes-2026-10-21.md). This validation covers output/rendering/pasteboard contracts; it does not claim a new end-to-end capture or destination-app paste acceptance run.

### Follow-up completed — 2026-09-06

Resolved the independently reproduced TSV formatting-tag leak and implemented the owner's content-only single-line copy rows. Preview and complete clipboard writes share one prepared conversion; original image uses its real thumbnail. Format identity remains accessible through assistive labels and help. Preserved compact layout, independent Original/Edit, bottom mode/runtime, and Pure Formula scope. All six formats were clicked in the actual signed App and independently read from the public pasteboard; long truncated rows copied the full content. Focused and full 45-check suites passed. Standards and Spec each found one issue; both were fixed and re-review returned zero remaining findings. See [follow-up evidence and screenshots](../evidence/ticket03-content-rows/verification.md). Earlier evidence below describes the original completed UI version.

Implemented the owner-confirmed compact preview-first Result Editor, independent Original/Edit disclosures, fixed aspect-fit original image, six whole-row Copy Formats, truthful unavailable states, and transient successful-copy feedback. Preserved deterministic canonical normalization, offline secured rendering, safe table fallback, editable GFM, conservative full-payload Pure Formula classification, and exact public clipboard representations. Removed synthetic acceptance headings/labels and duplicate fallback-table rendering.

The actual sandboxed, ad-hoc-signed acceptance App passed the complete edit/preview/six-format-copy journey with externally read public pasteboard values and types. Focused regression passed; the full suite passed 45 checks. Parallel Standards and Spec review completed; the one Spec finding was fixed and both re-reviews reported zero remaining findings. Actual window screenshots, bound run evidence, red/green evidence, and limitations are recorded in [Ticket 03 verification](../evidence/ticket03-ui/verification.md).

Full-content LaTeX remains undecided. Ticket 04 owns capture-screen window placement and production compact hosting. Notion/Feishu destination-specific manual paste and the final assembled signed-App capture flow remain integration checks; native blocks are not promised.

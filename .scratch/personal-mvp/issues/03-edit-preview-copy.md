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

### Reopened after independent review — 2026-10-21

Fix the four reviewed Spec defects on this branch: preserve valid LaTeX row spacing and existing formula contents during delimiter normalization; retain column positions when projecting HTML rowspan/colspan to TSV/plain text; correctly decode named and numeric HTML entities without recursively decoding literal entity text; and suppress a Complex Table preview only when it represents the same table as an editable GFM table. An unrelated simple table must not hide a complex table. Add regression coverage at existing normalization, preview, and public clipboard seams. Keep the existing compact UI and output scope.

### Reopened — 2026-09-06

Owner-reported TSV cells leak inline HTML formatting tags. Fix plain-text conversion at the table boundary, preserving literal text, formulas, code, and entities; verify rich table representations too. The new owner decision supersedes format-name-only rows: each vertical immediate-copy row displays a single-line, tail-truncated preview of its actual copied content, with no persistent visible format title. Keep full clipboard payloads, shared conversion for preview/copy, accessible format names, accurate unavailability, and success feedback. Original-image rows use the actual image thumbnail; rich-table rows use their actual plain-text representation. Keep Original/Edit and bottom mode/runtime layout. Full-content LaTeX remains outside scope. Work stays on the Ticket 03 branch.

### Owner-confirmed UI direction — 2026-09-05

The owner confirmed a compact macOS result window after a Grill Me discussion in the coordinating task. This supersedes the initial always-visible editing-workbench layout: emphasize the rendered result at the top; reveal Original and Edit independently on demand; keep one editable Canonical Markdown state. Below the result, list every existing Copy Format vertically with only its format name (no content/code sample), accurate unavailable status, and immediate whole-row copy. Show brief Copied feedback only after successful clipboard writing. Keep formula-only LaTeX semantics; full-content LaTeX export remains undecided and is not implemented.

Preserve the prior fixes: fixed-size aspect-fit original image, no duplicated fallback table when editable GFM exists, no synthetic result heading or formula-label prose in the acceptance fixture, and distinct rich-table versus TSV clipboard representations.

The reusable internal surface is `ResultEditorView(item:)` with the existing `AppModel` environment object and record identity. Ticket 04 owns hosting the compact result window, its dimensions, and automatic placement at the top-left of the capture's display. Ticket 03's isolated signed acceptance launch can host the surface at 470 × 700 points without altering ordinary App window behavior.

The implementation and actual signed-App UI verification completed on 2026-09-05; see Answer and the linked evidence.

## Answer

### Independent review fixes completed — 2026-10-21

Fixed all four reviewed Spec findings: valid LaTeX row spacing survives normalization; HTML rowspan/colspan retain column positions in TSV/plain output; named/numeric entities decode correctly without recursive interpretation; and unrelated complex tables remain visible alongside Markdown tables. Existing same-table duplicate suppression, captions, merged structure, offline security, and Copy Format scope are covered by regression tests.

Each original failure was reproduced before its fix. Focused tests, the full 45-check suite, bundled KaTeX rendering, final release compilation, signature verification, and signed-bundle regressions passed. Independent Standards and Spec re-reviews reported zero remaining findings. See [review-fix verification](../evidence/ticket03-spec-fixes-2026-10-21.md). This validation covers output/rendering/pasteboard contracts; it does not claim a new end-to-end capture or destination-app paste acceptance run.

### Follow-up completed — 2026-09-06

Resolved the independently reproduced TSV formatting-tag leak and implemented the owner's content-only single-line copy rows. Preview and complete clipboard writes share one prepared conversion; original image uses its real thumbnail. Format identity remains accessible through assistive labels and help. Preserved compact layout, independent Original/Edit, bottom mode/runtime, and Pure Formula scope. All six formats were clicked in the actual signed App and independently read from the public pasteboard; long truncated rows copied the full content. Focused and full 45-check suites passed. Standards and Spec each found one issue; both were fixed and re-review returned zero remaining findings. See [follow-up evidence and screenshots](../evidence/ticket03-content-rows/verification.md). Earlier evidence below describes the original completed UI version.

Implemented the owner-confirmed compact preview-first Result Editor, independent Original/Edit disclosures, fixed aspect-fit original image, six whole-row Copy Formats, truthful unavailable states, and transient successful-copy feedback. Preserved deterministic canonical normalization, offline secured rendering, safe table fallback, editable GFM, conservative full-payload Pure Formula classification, and exact public clipboard representations. Removed synthetic acceptance headings/labels and duplicate fallback-table rendering.

The actual sandboxed, ad-hoc-signed acceptance App passed the complete edit/preview/six-format-copy journey with externally read public pasteboard values and types. Focused regression passed; the full suite passed 45 checks. Parallel Standards and Spec review completed; the one Spec finding was fixed and both re-reviews reported zero remaining findings. Actual window screenshots, bound run evidence, red/green evidence, and limitations are recorded in [Ticket 03 verification](../evidence/ticket03-ui/verification.md).

Full-content LaTeX remains undecided. Ticket 04 owns capture-screen window placement and production compact hosting. Notion/Feishu destination-specific manual paste and the final assembled signed-App capture flow remain integration checks; native blocks are not promised.

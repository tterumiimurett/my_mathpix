# Ticket 03 — Markdown / Lark / Notion

## Owner decision and observed results

- Exactly three visible immediate-copy rows, in order: Markdown, Lark, Notion. Preserve the compact layout, small secondary-color title on the left, one-line actual content preview, and no inline explanation.
- Owner reports Markdown works perfectly. Preserve its source-only output byte-for-byte.
- Lark needs the rich-table representation already used in the Notion output, but its inline and display equations must remain Markdown source, not MathML or Notion's native inline placeholder.
- Owner reports Notion display math works but inline math pastes as `Before ‣.`. This is a confirmed destination failure, not a hypothetical risk. The owner explicitly authorized leaving this unresolved. This change does not fix or claim to fix it.

## Implementation

Lark has its own prepared document with full HTML and full source fallback. It reuses the existing escaped Markdown renderer, plain table-cell conversion, deterministic normalization, and Complex Table sanitizer. Formula tokens can now emit escaped Markdown delimiters for this clipboard format, while the existing default preview/Notion paths stay unchanged. No scripts, remote resources, new recognition request, target credentials, native Lark API writes, or browser injection are involved.

Real Markdown tables stay rich `<table>` elements and all tables/surrounding text retain order. Inline and display formulas preserve single/double dollar delimiters in HTML text, including TeX row spacing. Code spans remain literal. Safe Complex Table HTML retains spans and captions; its source fallback includes the caption and occupied-cell grid. Caption extraction is shared with Notion without changing its existing output.

The Lark pasteboard contains HTML and plain text only. It deliberately excludes Notion's native block UTI, Chromium custom DataTransfer data, MathML, and tabular-only formats that could make a target select only the table or native placeholder. Switching from Notion to Lark clears prior types through the existing atomic copy boundary. UI content previews and actual writes share the same prepared Lark document.

## Red → green and validation

At the previously agreed `ClipboardService.copy(…, to:)` seam, the new mixed-content Lark regression first failed when `.lark` wrote source text only. It passed after the actual HTML/Markdown-math implementation. Tests read the public pasteboard rather than private method calls.

Focused coverage includes literal expected HTML/table cells, inline and display math, code stars/dollar signs, entities, surrounding text, full tail marker, multiple tables, Unicode, TeX row spacing, inert raw HTML, complex merged HTML/captions/source fallback, removal of stale Notion data, and unchanged Markdown source-only copying. Existing Notion, normalization, offline preview/security, and legacy copy regressions remain in the suite.

- `./scripts/ticket03_test.sh`: passed after implementation and added boundary regressions.
- `./scripts/test.sh`: all 45 checks passed.
- Release build with isolated `my_mathpix_ticket3` name/bundle ID: passed.
- `codesign --verify --deep --strict dist/my_mathpix_ticket3.app`: passed.
- The actual signed bundle's `--ticket03-self-test`: passed, including new Lark public-pasteboard checks.
- `git diff --check`: passed.
- Independent Standards review: zero actionable findings. Independent Spec review: zero actionable findings. Both reviewed all tracked/untracked changes relative to `63941cc236a72f87ad92956a9c0e718bcceaa068`, including this evidence and the new adapter.
- Restarted the isolated App and updated the local test page for the single Lark paste check. Fresh launch evidence reports the Result Editor, offline policy, formula preview, and table preview visible. This is not Lark destination acceptance.

## Manual acceptance still required

The isolated `my_mathpix_ticket3` fixture already contains inline math, display math, a table and text on both sides. Click **Lark**, paste normally into a blank Lark/Feishu document, and check the whole table, both formula forms, symbols, code literals and complete surrounding text. Local clipboard checks do not establish how a particular Lark release interprets mixed HTML/Markdown math. Ticket remains claimed until this new destination outcome is accepted; the separately deferred Notion inline issue remains documented.

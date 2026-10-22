# 11 — Show and paste each logical table once

**Status:** resolved

**Blocked by:** None. Coordinate the installed candidate with 07.

## Problem

Owner reports that Lark and Notion paste an extra table and the Result Editor
preview displays the same duplicate; Markdown copying does not. The preview
should display the intended pasted result. Complex Table Output must retain its
structure rather than being discarded to hide the duplicate.

## Acceptance criteria

- [x] Reproduce duplication through the production preview and Copy Format paths.
- [x] A matching Complex Table Output replaces its Table Output at the original
  reading position, retaining caption, merged structure and formula content.
- [x] Remove a matching immediately preceding caption only once.
- [x] Preview, Lark HTML, Notion HTML and native blocks contain one logical table.
- [x] Plain source fallback does not append a second TSV copy of a matched table.
- [x] Keep unrelated tables, intentionally repeated source tables, literal code,
  prices and entity-looking literal text.
- [x] Recover corroborated full-cell equations in old stored tables conservatively.
- [x] Verify the signed App preview and actual destination paste; do not equate
  generated clipboard data with destination acceptance.

## Investigation

Ranked alternatives: (1) the format combiner treats caption/spans as proof that
the complex table is additional; (2) the renderer duplicates one source table;
(3) the destination imports multiple clipboard flavors independently. The
offline reproduction generated two tables before any paste or WebView update,
while rendering Canonical Markdown alone generated one. The old
`isRepresented(in:)` deliberately returned false for captions/spans. This
confirms (1) and excludes (2)/(3) for this reproduction.

## Comments

- 2026-10-22: Claimed following the owner's report. The existing synthetic RICH
  record contains a Markdown projection and a captioned, merged HTML version of
  the same table. No new recognition or owner history migration is required.
- Red loop: `scripts/ticket03_test.sh`; `/private/tmp/my_mathpix-ticket11-red.log`
  reports preview, Lark, Notion HTML/native and intentional-repeat failures.
- The shared `TableOutputLayout` compares occupied cell grids, replaces one
  matching source table, preserves structural HTML, and projects native Notion
  cells once. Comparison normalization never rewrites the chosen rich content.
- New tests include old dollar-only stored cells, escaped prices, caption
  placement, four equations, deliberate repeated tables and existing unrelated
  table/security regressions. Notion's native simple-table format still cannot
  encode merged cells; safe HTML retains them. Destination acceptance is pending.

## Answer — Single-table output verified (2026-10-22)

The installed `abb2215a...` App preview visibly shows one rich table, one caption
and rendered cell equations in both the new and legacy RICH records. Its normal
Copy Lark captures one HTML/source table; destination replay confirms one table.
Owner explicitly accepted Notion and Markdown and identified only Lark formula
rendering as the remaining paste issue. That separate behavior is tracked in 12;
it is not a duplicate-table problem. The later native Lark prototype also shows
one table with a merged header; its production App acceptance belongs to 12.

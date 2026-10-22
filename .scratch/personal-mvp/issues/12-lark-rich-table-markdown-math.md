# 12 — Preserve Lark rich tables while rendering Markdown-compatible math

**Status:** resolved

**Blocked by:** None.

## Problem and owner direction

Owner accepted Notion and Markdown. In Lark, Markdown paste renders equations
but leaves `<b>literal</b>` and escaped prices such as `\$5`; retain the Lark
rich-table rules while making equations render. Do not replace the entire
Lark format with plain Markdown or regress the accepted Notion/Markdown paths.

## Acceptance criteria

- [x] Reproduce the owner's Markdown result in the authorized private test doc.
- [x] Test a rich-table/equation sample through actual clipboard paste.
- [x] Preserve one table, source order, cell contents, prices and code.
- [x] Only genuine equations receive Lark-specific transport syntax; literal
  dollars, code and prices remain literal.
- [x] Verify installed App copy after any production change.
- [x] Notion and Markdown regressions remain green.

## Comments

- 2026-10-22: Owner opened `MyMathpix paste test` and explicitly authorized tests
  only there. No other Lark document/chat is in scope. Markdown baseline visibly
  renders inline, display and table-cell equations, reproducing literal HTML and
  price-escape defects. Initial focus split the blank page title; it was restored
  to its original name. The retained body contains only synthetic test content.
- Actual installed App Lark clipboard inspection proves one table and four
  formula strings equal to Markdown, with no Notion native payload. Thus mere
  source-string equality does not establish Lark rich-paste compatibility.
- Primary-source research: `../research/lark-rich-markdown-math.md`. Official
  input shortcut uses `$$TeX$$`; this is an experiment candidate, not a proven
  HTML clipboard protocol. Compare rich baseline versus changed delimiters
  before changing production code or reinstalling another App.
- Actual results: ordinary rich HTML becomes an embedded sheet, so table math
  stays literal. Double-dollar changes fail. `ace-table` produces a Docs table
  but neither dollars nor isolated span metadata suffice. A fully self-contained
  native `docx/record` payload through Chromium custom MIME successfully pastes
  merged header, paragraph/cell equations and cleaned price text together.
- Working prototype and candidate details: [archived experiment record](https://github.com/tterumiimurett/my_mathpix/blob/4afd0af649f02db298a1ce152c8c58453e48a0c1/.scratch/personal-mvp/research/lark-rich-math-experiment/README.md).
  Production code and all focused/basic regressions now pass. Release candidate
  SHA256 `d1a143db9dd4a6554892e2111dd50bb1e5feb739a1c6f5188b96a2dd44fce544`.
- Installation / normal Copy Lark acceptance is pending device unlock; desktop
  tool reported the Mac is locked. Existing authorization to exit/replace the
  canonical App persists. No new build was promoted while the UI was unavailable.

- 2026-10-22 after owner unlock: backed up abb2215a to
  `dist/backups/MyMathpix-before-lark-native-abb2215a.zip`; installed d1a143db
  at `/Applications/MyMathpix.app`, strict signature and executable hash verified.
  Selected existing 17:40 RICH record and used actual Copy Lark button; bounded
  capture [archived synthetic capture](https://github.com/tterumiimurett/my_mathpix/blob/4afd0af649f02db298a1ce152c8c58453e48a0c1/.scratch/personal-mvp/research/notion-inline-math-experiment/app-lark-native-records.json)
  contains Chromium docx/record, HTML and Markdown, without Notion custom data.
  Feishu coordinate clicks still fail noWindowsAvailable; keyboard paste did not
  insert content. Asked owner to paste once in the authorized private page.
  Final destination acceptance remains unchecked.

## Answer

2026-10-22 — Owner tested the installed candidate and accepted all three formats:
“无敌棒! 三个都测试了, 没问题.” This supplies final destination acceptance
for actual App Copy Lark, Copy Notion and Copy Markdown. Native formulas and
rich tables now paste together; prices/code are cleaned without duplicating
tables. Automated focused/basic regressions and signed build passed.
Compatibility remains bounded to tested target versions. Issue 09 remains
open; the owner authorized publishing this accepted clipboard update to GitHub.

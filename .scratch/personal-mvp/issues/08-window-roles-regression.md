# 08 — Restore compact capture result and explicit main workspace

**Status:** claimed

**What to fix:** Capture completion and the menu-bar MyMathpix item show the same compact Ticket 03 result surface at the captured display's top-left. The compact surface floats over other Apps and preserves preview-first Original/Edit and Markdown/Lark/Notion. The large history/settings/usage workspace appears only on explicit App activation such as Command-Tab or reopening the App.

## Comments

- 2026-10-22: Owner rejected the assembled candidate's oversized result. This explicit correction supersedes the previous assumption that positioning the large workspace at top-left satisfied capture presentation. Work starts from integration `22bf0fd`; Ticket 06 actual acceptance remains open. Tests use the existing signed-App window/mock-recognition public seam, with in-memory history and isolated defaults. No owner data, credential, remote service, or delivered App is modified.

## Acceptance criteria

- [ ] Capture and recognition keep App windows hidden; completion shows a compact floating result at the captured display's top-left, with the main workspace hidden.
- [ ] The compact result preserves the accepted Ticket 03 contents and three copy rows.
- [ ] The menu-bar MyMathpix item shows that same compact result.
- [ ] Explicit Command-Tab/Dock/reopen opens the large workspace without losing the selected Snippet or edits.
- [ ] Existing history, usage, retry, copy and sandbox regressions remain green; real desktop observations are recorded separately from supporting tests.

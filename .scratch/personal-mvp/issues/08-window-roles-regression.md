# 08 — Restore compact capture result and explicit main workspace

**Status:** claimed

**What to fix:** Capture completion and the menu-bar MyMathpix item show the same compact Ticket 03 result surface at the captured display's top-left. The compact surface floats over other Apps and preserves preview-first Original/Edit and Markdown/Lark/Notion. The large history/settings/usage workspace appears only on explicit App activation such as Command-Tab or reopening the App.

## Comments

- 2026-10-22: Owner rejected the assembled candidate's oversized result. This explicit correction supersedes the previous assumption that positioning the large workspace at top-left satisfied capture presentation. Work starts from integration `22bf0fd`; Ticket 06 actual acceptance remains open. Tests use the existing signed-App window/mock-recognition public seam, with in-memory history and isolated defaults. No owner data, credential, remote service, or delivered App is modified.

- 2026-10-22: Addressed the independent Standards review's nonblocking P3 duplicated wait by extracting one test-private helper, with identical poll/settlement timings. The original signed-window test and diff check remained green; no production change. See the GREEN evidence follow-up.

## Acceptance criteria

- [ ] Capture and recognition keep App windows hidden; completion shows a compact floating result at the captured display's top-left, with the main workspace hidden.
- [ ] The compact result preserves the accepted Ticket 03 contents and three copy rows.
- [ ] The menu-bar MyMathpix item shows that same compact result.
- [ ] Explicit Command-Tab/Dock/reopen opens the large workspace without losing the selected Snippet or edits.
- [ ] Existing history, usage, retry, copy and sandbox regressions remain green; real desktop observations are recorded separately from supporting tests.

## Answer

Implemented in the isolated `codex/restore-compact-result-panel` worktree from `22bf0fd`; acceptance remains claimed until the parent records the actual desktop journey on the final signed candidate.

The regression came from normal capture completion and explicit workspace activation sharing the large main-window presenter, while the compact Ticket 03 layout was only wired into a fixture launch. A separate nonactivating floating panel now hosts that same preview-first Result Editor for production and fixture results. Its default **outer frame including title bar is 470 × 560 points**, with a 16-point visible-area top-left inset on the captured display. The main workspace opens through explicit App activation/reopen; showing it hides the panel, and the result command reuses the same panel and selected Snippet. Menu-bar left click is wired to that result command; the right-click menu retains Capture with its shortcut, current status, explicit workspace access, Settings and Quit through public App/SwiftUI actions. Hidden-main error alerts are gated, and compact credential errors retain an explicit Open MyMathpix recovery action. GUI test scene/restoration state is isolated from normal main-window geometry.

The real-window/mock-service test first reproduced the 1180-point normal-level main window twice, then caught visible-both-windows and result-reopen regressions before their corrections. Final observations on both connected displays show 470 × 560, floating/all-spaces, correct inset/display, main hidden on completion, main 1180 on explicit access, same compact panel on the result command, and an actual credential-failure sheet on the compact result with main hidden. Full 48-check/workflow, Ticket 03 copy/edit, signed recognition and signed daily-workflow/entitlement/packaging checks pass. See [RED evidence](../evidence/window-roles-regression/red-loop.md) and [supporting GREEN evidence and limits](../evidence/window-roles-regression/green-loop.md).

Actual physical status visibility/click, capture over other Apps, Command-Tab/Dock, failure recovery clicks and full-screen spaces still require parent CUA acceptance. In particular, possible production capture hiding of an AppKit status-host window has not been reproduced and CaptureCoordinator has not been changed. The replacement a9 production-ID candidate is now sealed; its eight supporting checks, direct signed-window checks and formal reviewed source bridge are recorded in [candidate handoff](../evidence/ticket06-candidate/handoff.md). Parent actual T3 fixture observations establish470×560, Original/Edit and6 copy-source inspections, while actual capture/menu/Command-Tab acceptance remains pending. Fresh button-triggered T1 saw an authorized overlay but rejected an undersized selection before capture; this does not close the capture criterion. Notion inline math remains deferred. The earlier source implementation and supporting tests did not access owner data/credentials/live services, change permissions or replace the retained delivery candidate; the subsequently authorized replacement seal and current parent GUI observations are separately recorded in the handoff.

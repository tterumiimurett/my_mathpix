# Ticket 03 main integration — 2026-10-21

The owner accepted the three-format `ec7e140` candidate and requested Ticket 03 resolution and main integration. Resolution/follow-up tracking is in incoming commit `df9f928`. Main was initially unavailable because Ticket 04's merge was active; no changes were made to that merge. After the owner confirmed it had completed, integration started from clean main `3a1bde1`.

## Merge intent and conflict resolution

- Preserve Ticket 02's direct recognition, progress/cancellation, credential recovery and independently stored Usage Records. The compact editor reads runtime/cost from the current Usage Record, falling back to legacy history runtime only if no current record exists.
- Preserve Ticket 04's persistence, diagnostics, hotkey registrar, launch-at-login controls, stable `main` scene/window registration, and captured-screen result presentation. Both hotkey-disable and interaction-disable seams remain effective for isolated tests. Ticket 03 does not add an early main-window show that overrides the completion presenter.
- Integrate Ticket 03's offline preview, sanitized Complex Table Output, full-payload conservative Pure Formula automatic copy, and exactly three normal copy rows: Markdown, Lark, Notion.
- Replacing the old detail view retains the retry-and-replace confirmation in the compact editor; it does not bypass the model's existing protection of edited source.
- Preserve Failed Record recovery with a separate **Copy Original Image** action in the failure footer, outside the three normal format rows. Integration Spec review found this missing action; it was restored, and an actual model/pasteboard regression now verifies exact PNG and available TIFF.
- Union the Ticket 03 and Ticket 04 launch/self-test modes. Ticket 03's fixture has in-memory history and Usage Records, isolated defaults, and temporary diagnostics; it does not read the owner's credential or recognition history.
- Keep the production default window size at 1180 × 760, but lower its content minimum height from 620 to 520. The signed window seam exposed an integration layout regression: after an initially correct inset, SwiftUI enforced a 672-point minimum frame on a 648-point visible area, moving the top back to 695 instead of the requested 679. This was reproduced repeatedly before the fix; the ScrollView-based compact editor can use the lower minimum without hiding content. The existing captured-display placement policy is unchanged.
- Preserve all ticket acceptance/known-issue records in the delivery map. No other task's worktree was read or modified.

## Validation

Final candidate validation passed after the failed-image recovery and minimum-height fixes:

- `scripts/ticket03_test.sh`: passed; all Ticket 03 transformations, offline security, public pasteboard and failed-record image recovery checks.
- `scripts/test.sh`: passed 46 checks plus Ticket 04 workflow checks.
- `scripts/ticket02_recognition_test.sh`: `TICKET02_RECOGNITION_OK` on the final signed App.
- Final signed App executable `--ticket03-self-test`: passed.
- `scripts/ticket04_daily_workflow_test.sh`: signed sandbox/history/settings/shortcut/diagnostics/version/license workflow passed.
- `scripts/ticket04_result_editor_window_test.sh`: `TICKET04_RESULT_EDITOR_WINDOW_OK all-connected-displays` on the final source after diagnostic cleanup. The window regression was red repeatedly before lowering the minimum height, then green with and without diagnostic instrumentation.
- `git diff --check` and staged-diff checks: passed; no unresolved conflict markers or temporary debug instrumentation remain.

These are integration regressions, not new live Datalab, real ScreenCaptureKit selection, menu-bar visibility, or destination-app acceptance claims. The existing owner-accepted standalone Ticket 03 testing App was not replaced; the merged code was rebuilt and tested under the main checkout's `dist/MyMathpix.app`.

## Review

- Standards integration review: zero actionable findings, including re-review of failed-image recovery and minimum-height integration adjustments.
- Spec integration review: one P2 for the removed failed-image recovery action; fixed and re-review (including the minimum-height integration adjustment) returned zero remaining actionable findings.

## Explicitly unresolved

[Ticket 07 — Notion inline math](../issues/07-notion-inline-math.md) stays **needs-triage**, not resolved. The owner observed `Before ‣.` instead of inline math and explicitly deferred the repair while accepting Ticket 03. The merge does not fix or certify Notion native inline equations. Ticket 04's separately deferred menu-bar visibility issue also remains documented in its original ticket.

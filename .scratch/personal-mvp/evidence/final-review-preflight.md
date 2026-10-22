# Remaining Personal MVP — parallel preflight review

Review date: 2026-10-22 (Asia/Shanghai). Fixed point: accepted main `8e27ef03570671e3461a3cf2074474fc679ee98a`. Initial review target: `7062cc8440adad7d402b12c9177f87869375016e`; captured comparison `git diff 8e27ef0...HEAD`. Both independent reviewers subsequently checked the single fixer's `b667026f27e3e01d6d56b838480ac62aafb0b3b9` (`git diff 7062cc8..b667026`). Final packaging evidence is linked from `ticket06-candidate/handoff.md`.

This is a preflight review. Ticket 05 is resolved; Ticket 06 remains claimed because the same final candidate's actual shortcut/capture/live GUI journeys have not been observed. Static review and supporting CLI checks do not replace those observations.

## Standards

No hard documented-standard violations were found against AGENTS, domain docs or relevant ADRs. The independent reviewer raised three possible P3 maintainability smells:

1. **Duplicated Code:** report evaluation and pending-review generation both selected `CHECKS[case['category']] + (('table_structure',) if ... else ())`. Fixed in `b667026`: both use the same `required_checks(case)` policy. The parent independently regenerated the full V2 report after this change; it is byte-identical to the committed report.
2. **Primitive Obsession:** the Golden runner used `var record: [String: Any]` and `record["status"] == nil` to control outcome. Fixed in `b667026`: private `AttemptRecord`, `Outcome` and `Consumption` types represent states; dictionaries remain at the existing JSON boundary. Raw fields, explicit nulls, failure/consumption-error distinctions and writing the service result before consumption are retained.
3. **Duplicated Code:** navigation callbacks repeated `navigationTimer?.invalidate(); self.navigation?.resume(throwing: error); self.navigation = nil`. Fixed in `b667026`: all success/failure callbacks use one completion helper.

The original Standards reviewer independently confirmed all three closed and found no new concrete standards issue. The parent also reviewed the complete fix diff. The source bridge now distinguishes 159 byte-identical ordinary core/resource inputs, nine acceptance host differences, and one separately reviewed exact-hash Golden runner refactor; it explicitly does not claim the whole quality pipeline is unchanged. Existing report/self-test/offline-preview checks are supporting evidence, with their scope recorded in `ticket06-candidate/standards-fixer-review.md`.

## Spec

Two required acceptance groups remain open:

1. **P1 — actual capture journey unverified.** Ticket 06 requires: “The same assembled, sandboxed, ad-hoc-signed App intended for handoff passes the authoritative shortcut, real selection, deterministic mock recognition, Result Editor, rendered preview, and Recent History flow while its process remains alive.” Actual granted ScreenCaptureKit, Retina/multi-display behavior and permission transitions remain unobserved. The last desktop-tool observation was a locked Mac; an ungranted preflight is not proof of denial/revocation behavior.
2. **P1 — actual live interaction/recovery unverified.** Ticket 06 requires: “A real Datalab run confirms fast recognition, visible progress, editing, the relevant Copy Formats, Failed Record recovery, and balanced retry without exposing the token.” Existing batch quality results and clipboard serialization checks do not prove this final candidate's interactive workflow.

The Spec reviewer independently verified 160 unique V2 output/review bindings, 160 canonical hashes and all 320 preview hashes. Both modes remain 69/70 ordinary; the original failed V1 report is retained. No concrete new scope creep or wrong implementation was found. The focused fix re-review found no new Spec issue. Notion inline paste, menu-bar visibility, disclosed quality failures and the blank fourteen-day checklist retain their accepted status.

Standards: 3 initial judgement findings, 3 fixed, 0 open; worst initial severity P3. Spec: 2 open acceptance findings; worst P1, final same-candidate capture journey remains unverified.

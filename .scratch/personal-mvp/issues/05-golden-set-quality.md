# 05 — Prove recognition quality with the Golden Set

**What to build:** The owner receives repeatable evidence showing whether fast and balanced recognition produce usable formulas, tables, and mixed technical content. Quality is judged by mathematical meaning and table structure rather than superficial source-string equality, and difficult boundary cases remain visible without distorting the ordinary-case gate.

**Blocked by:** 02 — Make real Datalab recognition reliable and recoverable; 03 — Make recognized content editable, previewable, and copyable.

**Status:** resolved

## Suggested agent split

- **Work package A — Reviewed truth and rubric:** assemble representative cases and define semantic formula, table-structure, mixed-content, and boundary-case judgments.
- **Work package B — Repeatable evaluation and report:** run the product output through the rubric, compare fast and balanced behavior, enforce thresholds, and retain inspectable evidence.
- The main agent reviews disagreements and owns the final pass/fail conclusion; automated similarity alone cannot declare the product acceptable.

## Acceptance criteria

- [x] The Golden Set contains thirty Pure Formula cases, twenty simple tables, twenty mixed-content cases, and ten separately reported difficult boundary cases.
- [x] Formula evaluation accepts mathematically and visually equivalent LaTeX rather than requiring byte-identical source.
- [x] Table evaluation checks row count, column count, cell content, order, Markdown editability, and applicable TSV or rich-copy structure.
- [x] Mixed-content evaluation covers Canonical Markdown, offline preview, correction, and the relevant Copy Formats as one user-visible path.
- [x] Ordinary cases achieve at least 95 percent overall pass rate with no category below 90 percent; difficult cases are reported separately.
- [x] Fast and balanced results, latency, and available cost evidence are reported without exposing the Datalab token or unrelated screen content.
- [x] Results are repeatable and inspectable, and tests assert public behavior or stable external contracts rather than private implementation details.


## Comments

- 2026-10-21: Claimed on `codex/ticket05-golden-set`, initially based on integration `3a1bde1`. Uses the already approved manifest/report, production recognition transport, public pasteboard, offline preview, and isolated correction/persistence seams. Known Notion inline and menu-bar follow-ups remain excluded. Quality requires actual outputs and hash-bound semantic review; harness success alone will not resolve this ticket.

## Answer

Resolved on 2026-10-22 after one complete fresh repaired-candidate 80x2 live run and 160 independent hash-bound semantic/consumption reviews. Both fast and balanced achieve69/70 ordinary (98.57%), with 30/30 formulas,20/20 simple tables and 19/20 mixed; this exceeds67/70 and every90% category floor. Boundaries are separate: fast 9/10, balanced 8/10, with no pending reviews. The main agent independently verified the ordinary aggregate and reconciled boundary findings.

The fixed80 authored printed, non-sensitive development fixtures, independent Golden Results/rubric, production RecognitionService runner, real offline previews, isolated correction/persistence and full public named-pasteboard values are repeatable. This is a development-corpus result, not broad private-screenshot/handwriting accuracy or new destination-native paste acceptance.

See [quality summary, measurements and remaining limitations](../evidence/ticket05-golden-set/quality-summary.md), [final report](../evidence/ticket05-golden-set/baseline-v2/report.json), [all 160 reviews](../evidence/ticket05-golden-set/baseline-v2/reviews.json), [source/full-bundle provenance](../evidence/ticket05-golden-set/baseline-v2/build-provenance.json), and [rubric](../golden-set/rubric.md). Original failed baseline-v1 remains immutable. V2 observed medians are 3.10s fast/3.07s balanced, with explicit total 0.8/2.4 cents; repeated inputs may receive provider reuse/caching, so these do not prove uncached speed. Original medians 3.78s/5.25s and about 32 cents per mode remain separate.

M15 loses blockquote layout in both modes; boundary B06 misparses escaped currency in preview/rich-copy and B08 balanced shifts table headers/adds a fallback. These are counted failures. Notion inline native paste and menu-bar visibility remain explicitly deferred. Ticket06 must still verify the assembled signed-App workflow and hand over the actual fourteen-day dogfood checklist; this result does not claim that usage period or the Public Product gate.

Verification:all 160 raw/output/source/config/artifact bindings and 320 actual preview PNG hashes match; all 80 input PNG hashes/widths match. Five report-contract tests, full 46-check regression plus Ticket04 workflow, focused Ticket03 checks, signed tall-preview regression and final strict/deep signature/whitespace checks pass. No token or unrelated screen content is exposed.

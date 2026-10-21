# Ticket 05 implementation and verification — 2026-10-21

Status: completed on 2026-10-22; the original work and failed baseline below are historical. The authoritative repaired-run outcome is in [quality-summary.md](quality-summary.md).

## Fixed inputs and truth

- 80 original non-sensitive authored printed development Snippets:30 Pure Formula,20 simple tables,20 mixed,10 difficult boundary cases. Diverse mixed reading layouts include multiple tables, table-first/formula-first cases, inline cell math, headings/blockquote, multiple paragraphs and code literals.
- Independently authored Golden Markdown, table grids, formula/layout notes and B05's expected rowspan contract accompany the fixture HTML. No expected output is derived from Datalab.
- All 80 final PNGs are1600 pixels wide for800-point fixture content; SHA256 matches their frozen manifest entries. Native snapshots wait for local fonts, verify all formula nodes rendered, reject KaTeX errors/blank pixels and normalize pixels independently of display backing scale.
- Parent independently reviewed authored source consistency and all 80 rendered inputs. Final normalized spot checks covered F13,F30,T20,M12,M13,M20,B05,B06. The input claim is deliberately limited to this printed development corpus; it is not a broad real-screenshot or handwriting benchmark.

## Public seams and TDD

The pre-agreed spec seams are used: fixed manifest/report external contracts, production RecognitionService/Datalab submit-poll boundary, actual offline preview, public named pasteboard values and isolated AppModel edit/HistoryStore state. No additional user seam confirmation was required.

Red-to-green report evidence:

1. Missing report implementation initially fails the public test command; minimal fixed-denominator/pending behavior passes.
2. A stale review hash originally allowed altered content to pass. The regression failed before actual output hash plus corpus/config/executable/content binding was enforced; it passes afterward.
3. The actual service response shape includes `costBreakdownJSON={"final_cost_cents":0.40000000000000002}` although the product's current scalar costCents is null. A report regression first failed to expose measured cost, then passed using the explicit cents field with source provenance. This does not mutate the frozen production parser or invent pricing.
4. Even-sized latency samples previously used an upper-middle element; a2s/4s public report example failed its expected3s median, then passed with the proper median.

Final report suite passes5 tests, including equivalent LaTeX acceptance, category floors and pending/hash binding. The full repository regression passes46 checks plus Ticket04 workflow; focused Ticket03 tests pass. `git diff --check` passes.

## Frozen live artifact

- Native arm64, macOS15.7.3, App version0.1.0.
- Bundle identifier: `com.byterumi.mymathpix`; ad-hoc signed; strict/deep signature verification passed. App Sandbox, outbound network and user-selected file entitlements retained.
- CDHash: `67cd4e5f6fd985257346ecfbcda07e3cd2cd8a8c`.
- Executable SHA256: `bafa156a6c81158443b924153e97c9b549ea2aff58fb6935ae7fa0d787d95102`.
- Corpus manifest SHA256: `fdc28d85aca668999c31d3c2bd18008ce7ea5c51c353334e9f0beb510dba6f0f`.
- Baseline run ID: `baseline-v1`. Sources/executable stay frozen throughout its160 scheduled fast/balanced Recognition Attempts.
- The runner uses only this signed App's existing LocalTokenStore; no credential migration, Keychain access, token print, raw exception export or unrelated screen capture occurred.

Each actual result is atomically saved before local consumption work, with source/result hashes, wall latency, API runtime, full available cost breakdown and retry count. Named private pasteboards avoid replacing the user's general clipboard. The isolated AppModel corrects a selected in-memory HistoryStore entry; actual corrected WK DOM/snapshot and public clipboard source are observed. Production Recent History is not used or evicted.

The first real pair completed:fast wall5.57s/API0.65s,balanced wall6.98s/API2.86s. Both carry explicit measured0.4-cent cost breakdowns and successful local preview/correction/copy evidence. These are a pilot pair, not final quality or latency conclusions.

## Evidence boundaries

No serialized clipboard payload establishes a new destination-native acceptance. The owner's accepted Markdown/Lark/Notion workflow, deferred Notion inline defect and menu-bar issue remain explicitly unchanged. Final fast/balanced semantic quality, overall/category thresholds and latency/cost aggregates must be attached after the baseline and independent reviews finish. Technical failures or unknown reviews cannot be hidden by reducing denominators or repeatedly spending until output passes.

An interrupted result saved before consumption is currently skipped on resume, preserving recognition spending; it may need local consumption repair or independent evidence. No such interruption was observed in the pilot. Ticket06 remains a separate signed-App capture journey and dogfood handoff gate.

## Original baseline conclusion and evaluator repair — 2026-10-22

The run crossed local midnight. Baseline-v1 completed160/160 service outputs with zero technical failures, zero consumption exceptions and zero automatic retries. All actual results, configuration/manifest and 320 original/corrected PNGs are preserved under `baseline-v1/`, together with140 independent ordinary-case review records and its report. Duplicate generated HTML files are intentionally omitted; actual canonical/safeHTML and public clipboard values remain in result JSON. The original signed bundle is separately preserved for audit.

Both original modes conclusively fail the consumption gate. Fast has30 ordinary passes,34 failures and6 pending; balanced has30 passes,21 failures and19 pending. Pending artifact judgments remain pending rather than invented scores. Confirmed failures already make the fixed thresholds impossible; the report now distinguishes this from an otherwise achievable pending gate. Boundary judgments are separately pending in this original review snapshot.

Measured original wall median: fast3.78s (65/80 below5s), balanced5.25s (34/80 below5s). Both modes have80 explicit final_cost_cents observations totaling approximately32 cents each; complete breakdowns and provenance are retained. Costs are measured response fields, not assumed price or billing audit.

The data exposed literal table-header markup, math content discarded from safe fallback HTML and duplicate tables. A separate production fix is being integrated. The original runner also clipped full-page snapshots by using body.scrollHeight without margins/host-window synchronization. A fixed tall public snapshot test reproduced this: only4 of48 footer pixel rows were visible in a1688px image. After synchronizing NSWindow content size, WK viewport and full document bounds, the same test passes with all48 rows and1776px height; the result was visually inspected. Native source changes now also retain raw service Markdown/HTML plus a raw-output hash as inert JSON for the next separately identified baseline.

Original results are not overwritten, reconstructed or cherry-picked. Since raw service HTML was not retained in baseline-v1, lost math cannot be restored from its already-sanitized HTML. The authoritative repaired-candidate assessment will therefore use one complete fresh 80x2 baseline-v2 after production fixes and tests pass, with no best-of mixing. A strict local replay is optional supporting evidence only, never a substitute for unavailable raw inputs.

## Authoritative repaired outcome — 2026-10-22

Complete fresh baseline-v2 and 160 independent reviews pass both ordinary gates at 69/70, with categories 30/30,20/20,19/20; boundary fast 9/10 and balanced 8/10 are separate. See [quality summary](quality-summary.md), [hash-bound report](baseline-v2/report.json), and [full raw/canonical/consumption evidence](baseline-v2/results). Source/bundle/configuration provenance and all 320 PNG hashes are retained. Original v1 remains immutable. Ticket06 remains a separate integration and dogfood-handoff gate.

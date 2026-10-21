# Golden Set quality evidence — 2026-10-22

The repaired production candidate passes the fixed ordinary-case gate in both modes: **69/70 (98.57%)**, with all 160 fresh result reviews complete. The main agent independently reconciled the findings and verified the aggregate. This proves usability on the reviewed, authored printed development corpus; it does not estimate unseen/private screenshot or handwriting accuracy.

| Mode | Formula | Simple table | Mixed | Ordinary | Boundary, separate | Pending |
|---|---:|---:|---:|---:|---:|---:|
| fast | 30/30 | 20/20 | 19/20 | 69/70 | 9/10 | 0 |
| balanced | 30/30 | 20/20 | 19/20 | 69/70 | 8/10 | 0 |

The ordinary requirement is at least 67/70, with category floors 27/30,18/20,18/20. No better-mode-per-case selection or failed-case replacement was used. Equivalent TeX and visual mathematical structure were reviewed rather than byte equality. F14/F30's split display rows pass the written semantic/layout rubric; this does not promise automatic Pure Formula copying for a split representation.

## Remaining observed failures

- **M15, both modes:** authored blockquote becomes an ordinary paragraph. Heading/text/order remain correct; layout fails. It is counted as the one ordinary failure in each mode.
- **B06, both modes:** service/canonical source correctly preserves escaped currency and code, but the local preview and Notion rich representation parse the currency dollar through the next formula delimiter, leaving the intended inline formula literal. Correct source strings do not pass this rendered/copy boundary.
- **B08, balanced:** blank Markdown header rows shift labels into data rows and retain a redundant third fallback table. All words being present does not pass table structure.

Boundary B05 preserves the explicit rowspan contract alongside the flat Markdown projection, and both actual representations are fully visible after snapshot repair. This is a disclosed projection-plus-merged-alternative pass, not a single-table or destination-native merge claim. B09 now has one complete formula table and no erroneous fallback duplication. Full per-case reasons remain in [report.json](baseline-v2/report.json) and the four independent review findings files.

## Separate original and repaired runs

[baseline-v1](baseline-v1/report.json) remains immutable:160 original outputs,320 PNGs,140 ordinary reviews and its original failed report. Both modes conclusively failed, exposing literal header markup, lost raw math and duplicate tables; old preview clipping also left some artifact judgments pending. Additional boundary reviews and a separately named [supplemental report](baseline-v1-with-boundary-report.json) do not overwrite that assessment. Missing original raw HTML was never reconstructed from canonical text or Golden truth.

Production fixes preserve inert text-only service math and avoid redundant header wrappers while retaining strict table matching. A public tall-document regression reproduced evaluator clipping (4/48 footer rows,1688px) and passes after window/viewport synchronization (48/48,1776px). The repaired candidate then made one complete fresh 80x2 API run, **baseline-v2**, with raw service Markdown/HTML retained as inert JSON for exact future reprocessing. No old canonical output was substituted.

| Observed run | Mode | Calls | Wall median | Below5s | API-reported cost, cents |
|---|---|---:|---:|---:|---:|
| original v1 | fast | 80 | 3.78s | 65/80 | about32.00 |
| original v1 | balanced | 80 | 5.25s | 34/80 | about32.00 |
| repaired v2 | fast | 80 | 3.10s | 78/80 | 0.80 |
| repaired v2 | balanced | 80 | 3.07s | 76/80 | 2.40 |

All 80 costs per mode are available in each run. Values come from explicit `costBreakdownJSON.final_cost_cents`, because the current product scalar parser leaves costCents null for this response shape. Zero remains measured zero; no tariff estimate or billing audit is asserted. V2 reuses the exact previously submitted images and may benefit from provider reuse/caching. Its lower observed latency/cost **does not establish uncached performance**. Original measurements remain separately inspectable; neither run establishes a universal sub5s guarantee. Both runs have zero automatic technical retries, recognition failures or consumption exceptions.

## Frozen provenance and independent review

- Corpus:80 non-sensitive, independently authored printed fixtures,30 formulas/20 tables/20 mixed/10 boundaries. All input PNGs are1600px wide and hash-match the frozen manifest. [Source consistency review](source-truth-review.md) metadata findings were fixed before freezing: per-case mixed notes, explicit B05 rowspan/grid, B08/B09 grids and boundary table checks. [Input visual review](source-visual-review.md) approves the final corpus as development inputs only.
- Corpus SHA256: `fdc28d85aca668999c31d3c2bd18008ce7ea5c51c353334e9f0beb510dba6f0f`.
- V2 executable SHA256: `52fa55da6962fe0278d1f56805481ae1a9b404b3b0df8aff09c7b637db3181cc`; source revision `f1244513d47738d9bb0dbc227878a4c42d16abba`.
- V2 configuration SHA256: `3c27bb3d79f935da026f156b656cb68fd345215f696e08c8027b769d80487ead`; complete signed-bundle file-tree SHA256: `eeccc73cd7b0ce5559f77d7fd02abac43261d45f07e6fdb60207514351a47927`.
- [Build provenance](baseline-v2/build-provenance.json) binds all 189 tracked build inputs and 147 bundle files. The preserved signed app and active evaluation bundle match exactly. Runtime:arm64/macOS15.7.3/App0.1.0, ad-hoc signature and sandbox.
- [Integrity and measurements](baseline-v2/integrity-and-measurements.json) verifies all 160 raw/canonical/input/config/artifact bindings and 320 actual normal/corrected PNG hashes. Every input hash was independently rechecked. Each result includes full public named-pasteboard values and isolated AppModel/HistoryStore correction evidence.
- [160 independent reviews](baseline-v2/reviews.json) cover all unique case/mode pairs. Formula/table/boundary reviewers read actual inputs, sources and fresh PNGs; the main agent reviewed mixed content and reconciled material differences. Review IDs/hashes must match the current run, and pending/stale reviews cannot pass.

Reproduce the final report without network or credentials:

```sh
python3 scripts/golden_set/report.py .scratch/personal-mvp/evidence/ticket05-golden-set/baseline-v2/manifest.json .scratch/personal-mvp/evidence/ticket05-golden-set/baseline-v2 --reviews .scratch/personal-mvp/evidence/ticket05-golden-set/baseline-v2/reviews.json --output /tmp/my-mathpix-golden-report.json
```

Five report-contract regressions pass, including stale hash rejection, equivalent TeX/category floors, actual cost-field provenance, true even-sample median and conclusive failure with remaining pending cases. Full46-check regression plus Ticket04 workflow and focused Ticket03 checks passed on the repaired production source. Final report tests, strict/deep signature verification and whitespace check pass after merging integration4a91a75.

## Evidence limits and next gate

This batch reviews the public Markdown/Lark/Notion representations and actual offline rendering/correction. It performs no new destination paste and makes no native-editability guarantee. Notion inline destination paste and menu-bar visibility remain the owner's explicitly deferred follow-ups; B06 is an additional observed local rendering/rich-copy limitation. No credentials were migrated/printed, production Recent History evicted, general clipboard changed or unrelated screen content captured.

Ticket06 remains the separate assembled signed-App capture/integration and dogfood-handoff gate. No fourteen-day usage period or Public Product acceptance is claimed here. Detailed run instructions are in [the evaluator README](../../../../scripts/golden_set/README.md).

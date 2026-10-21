# Golden Set rubric — authored printed development corpus v1

The fixed input PNGs and their independently authored Golden Results live in `Sources/MyMathpix/Resources/GoldenSet/manifest.json`. All 80 PNGs have width 1600 pixels for an 800-point fixture. Authoring provenance is explicit: these are original non-sensitive printed development Snippets, not harvested user images, handwriting, or service-generated truth. Their source-level and visual truth require independent review before quality scoring. Never substitute a product-rendered Golden Markdown page for the actual fixture PNG, especially boundary B06's literal currency/formula challenge.

## Formula meaning and layout

A pass preserves the mathematical expression and visible structure: operators, signs, bounds, scripts, accents, grouping, matrix dimensions/cell positions, piecewise branches and aligned rows. Equivalent LaTeX such as redundant braces, spacing commands, `\frac` versus `\dfrac`, or equivalent delimiters is acceptable. A source-string mismatch does not establish failure; a string match does not establish readable preview or editable transfer. Record the equivalence reason when it is nontrivial. Do not require omitted mathematical domain restrictions absent from the input.

## Tables

Compare every table, in order, to the independent `tableGrids`: header/data row counts, columns, complete cell content and ordering. Different source spacing/alignment markers are acceptable; lost, shifted, duplicated or merged-away cells fail. Formula cells receive semantic formula review rather than literal LaTeX equality. Verify editable Markdown plus applicable public TSV/rich representations. Legacy TSV/rich format intentionally copies the first table; visible Markdown/Lark/Notion actions must retain the whole output and all tables. B05 additionally requires its independently stored rowspan contract in safe Complex Table Output; an empty-slot Markdown projection alone cannot pass merged structure. B08/B09 require explicit table-structure judgment despite boundary separation.

## Mixed result consumption

Read all paragraphs, heading/blockquote structure, inline/display formulas and tables in fixture order. Assess Canonical Markdown, actual offline preview PNG, and complete Markdown/Lark pasteboard values together. The isolated AppModel edit must update its selected item/HistoryStore, produce a rendered corrected preview containing the marker, and copy that edited source through the public clipboard seam. An HTML source marker or a serialized equation annotation alone is insufficient.

The owner accepted the final three-action workflow but explicitly deferred Notion inline Native Paste. Keep this defect visible in each report; batch output types/MathML/native serialization never imply a real Notion destination pass. Markdown and Lark completeness and the already accepted Notion display/table contract remain relevant. No new destination document mutation or authentication occurs in this evaluation.

## Review records and gate

Review one result per case/mode, binding the input PNG hash, authored-content hash, actual canonical+safe-HTML output hash, corpus hash, run configuration hash and executable artifact hash. Record reviewer/date/notes and each applicable check as pass, fail or pending. Missing results, missing review fields and stale hashes cannot pass. Actual preview PNGs also carry hashes in the consumption record and should be checked during review. Review discrepancies against the actual source PNG and Golden Result, not against whichever service mode looks better.

Report fast and balanced separately, with fixed denominators: formula30,table20,mixed20,ordinary70 and boundary10. Each mode passes only with at least67/70 ordinary,27/30 formulas,18/20 tables and18/20 mixed. Do not choose the better mode per case after seeing results. Boundary failures are reported separately, without changing ordinary denominators. A pending mode is not an accepted mode. The specification's general Passing Threshold does not imply that fast latency is acceptable; latency and the later Dogfood Gate are distinct.

Wall time measures the full submit/poll recognition call; API runtime is separate. Preserve the complete available cost breakdown. An explicit `final_cost_cents` field is measured cents, even if the current product's scalar parser leaves costCents null; the report records that provenance. Missing costs stay unknown rather than zero. Do not estimate a price from public tariffs or invent billing accuracy. API request/automatic technical retry counts are evidence, not unlimited quality retries.

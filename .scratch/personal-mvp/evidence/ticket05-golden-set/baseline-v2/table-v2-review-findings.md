# Independent table review — baseline-v2, 2026-10-22 Asia/Shanghai

Completed fresh review of T01–T20 in both fast and balanced mode: **40/40 pass** the applicable table_structure, canonical, preview and copy checks. Review records are in `table-v2-semantic-reviews.json`. This conclusion is limited to the table category; the parent owns the full Golden Set gate.

Every canonical header/data cell, row count, column count and ordering was independently compared to the frozen authored tableGrids. Harmless source formatting tags and GFM spacing variations are interpreted as markup. T04's TeX alpha/beta and T13's TeX powers are equivalent to authored Unicode glyphs/superscripts. Safe Complex Table HTML and Lark/Notion full HTML contain exactly one complete expected table for all cases. Markdown/Lark/Notion source fallbacks preserve the entire canonical source. Applicable TSV and rich HTML values preserve every cell; required public clipboard type lists are present. Saved RTF evidence is its advertised type, not a decoded RTF body.

Inspected all 20 actual frozen input PNGs, all 40 fresh normal offline PNGs, and all 40 actual corrected PNGs in the v2 contact sheets. The full normal tables, including final rows and borders, are visible and readable. Headers no longer display literal `<b>` tags. T04/T13 do not append an incomplete second fallback table. Every corrected image retains the complete table and visibly shows `Correction check.`. These are fresh observations, not recycled v1 verdicts.

Verified all eight review binding fields against v2 result/manifest/configuration data, authored input PNG hashes, actual canonical+safeHTML output hashes, retained rawMarkdown+rawHTML hashes, original/corrected PNG hashes, and the true recorded isolated-model-edit/copy/render flags. V2 executable artifact binding: `52fa55da6962fe0278d1f56805481ae1a9b404b3b0df8aff09c7b637db3181cc`. No missing or stale result was substituted.

No destination application was operated. Notion Native Paste or native equation editability is not asserted, and the deferred inline-math defect remains outside this pass. No source, candidate, history, credential, service, TCC or UI mutation was performed. Original v1 records and review files remain unchanged.

Visual aids: `table-v2-normal-{01,05,09,13,17}.png` and `table-v2-corrected-{01,05,09,13,17}.png` under the same outside-repo context directory. Contact sheets trim only surrounding white margins for inspection; original PNG hashes bind the evidence.

# Fresh baseline-v2 mixed review — parent

Reviewed all 40 M01–M20 fast/balanced outputs against the unchanged frozen authored inputs. Read each distinct actual canonical source and viewed each distinct complete v2 normal preview; equal PNG hashes across modes allow an identical actual image to be inspected once. No baseline-v1 verdict was copied. Additional corrected-preview visual spot checks covered M01, M12, M13, M15 and M20, including full footer markers and both tables in long cases.

Verified each record's artifact/configuration/corpus/input/content/output/raw-output hashes, both normal/corrected PNG file hashes, no retries or consumption exceptions, whole public canonical fallback for all three visible formats, exact ordered Lark/Notion table grids including math annotations, and isolated public edit/persistence/correction-copy/DOM marker observations. The outside-repo helper `review-mixed-v2.py` records these technical checks after explicit semantic/image review; it does not supply truth or alter the run.

- Fast: 19/20 pass, 1/20 fail.
- Balanced: 19/20 pass, 1/20 fail.
- Confirmed failure in both modes: **M15** preserves all words/data/formula but flattens the authored blockquote “Units are unchanged.” into a normal paragraph. Layout is fail, not silently accepted.
- M20 preserves both equations, operators, row order and both complete tables; equations become separate left-aligned formula paragraphs. Centering differs, without losing the semantic/read-order contract. Recorded as a cosmetic change rather than rejecting equivalent source.
- T04-style Greek and T13-style math cells within M04/M13/M19 now render fully, with no empty-math fallback duplication. Header labels render as bold text, without literal markup. Long mixed previews now retain bottom rows and final paragraphs.

No Native Paste or real Notion inline compatibility is asserted. Deferred Ticket07 remains unchanged. Ordinary mixed floor is 18/20; these results pass that floor, while the actual combined gate still requires the independent formula and table reviews.

# Ticket 03 — independent review fixes

Date: 2026-10-21. Branch: `ticket03-edit-preview-copy`. Review baseline: `1c0befe059247bc06269801ac23382f44faccebc`.

The registered temporary worktree was absent. Restored only `/private/tmp/my_mathpix-ticket03` using `git worktree add --force` on its original branch; no other task checkout was read or changed, and main was not switched or edited.

## Four fixes and regression evidence

1. **LaTeX preservation.** Normalization now consumes escaped pairs together and tracks existing dollar/parenthesis/bracket formula context. The public normalization and Pure Formula regression failed before the fix for `$$\begin{aligned}a&=b\\[4pt]c&=d\end{aligned}$$`, then passed without changing the formula contents. Tests also cover alternate outer delimiters, literal backslashes, existing math text, and an unmatched currency dollar followed by a formula. The latter guard was added to prevent new context tracking from suppressing later normalization.

2. **Merged-cell column positions.** Complex-table TSV projection maintains occupied columns until each rowspan expires, combines rowspan with colspan, and pads records to a consistent width. Public TSV/plain pasteboard values were checked for both TSV Table and Rich Table. The three-column fixture now yields `A\tB\tC\ngroup\t\tx\n\t\ty\nz\tw\tv`, preserving the last column's `y`. These clipboard regressions failed before the fix and passed afterward.

3. **Entity correctness and safety.** One shared, offline decoder handles named and numeric entities once per token. Sanitized HTML re-escapes the result. Regression clipboard values for `&alpha; &copy; &#945; &#x3B1; &#X3B1;` are `α © α α α`; `&amp;alpha;` remains literal `&alpha;`. HTML-escaped script-like text stays escaped in HTML and literal in plain/RTF. Tests read public string, TSV, HTML, and decoded RTF values, and check re-sanitization stability. The entity value tests failed before the fix and passed afterward. Existing HTML code-cell conversion reuses this decoder instead of maintaining a second implementation.

4. **Conservative duplicate suppression.** A fallback table is omitted only when its full plain cell grid matches a real editable Markdown table and it has no merged-cell structure or caption missing from Markdown. Unrelated complex tables remain visible, including merged tables whose plain grid happens to match. The new distinct-table preview test failed before the fix and passed afterward. Tests also cover a true duplicate, a duplicate of a later Markdown table, retained caption, and table examples inside fenced code. The older test that incorrectly paired unrelated Markdown and HTML tables as a supposed duplicate was corrected to use an actual same-table fixture.

The compact UI, single-line copy previews, Copy Format scope, and first-table clipboard selection remain unchanged. No full-content LaTeX conversion was added.

## Verification

Final source checks:

```text
./scripts/ticket03_test.sh
Ticket 03 self-test passed.

./scripts/test.sh
MyMathpix self-test passed (45 checks).

git diff --check
passed
```

The bundled `katex.min.js` successfully rendered the preserved aligned formula with `throwOnError: true`:

```text
BUNDLED_KATEX_ROW_SPACING_OK
```

Built the final release source as isolated `dist/MyMathpixTicket03Acceptance.app`, bundle ID `com.byterumi.mymathpix.ticket03acceptance`. An earlier release attempt detected a source edit during the build and was discarded; the stable final rebuild succeeded. `codesign --verify --deep --strict` passed. Executing the same regressions from the signed bundle returned `Ticket 03 self-test passed.` CDHash: `cbe1e07b45d4ec6871305747ef1ef0866a909a95`.

This run validates normalization, generated preview documents, bundled KaTeX rendering, and actual public pasteboard representations. It does not claim a new full Screen Capture/UI-automation or destination-application paste acceptance run; the prior signed-window evidence remains historical. No credential was read or migrated and no live recognition request was made.

## Standards

Independent parallel review and final narrow follow-up: **0 remaining actionable findings**. Domain contracts and HTML safety boundaries remain intact; the entity decoder is shared and regressions use public output seams.

## Spec

Independent parallel review verified all four original findings fixed, using current-source probes as well as the added regressions. Final review after the unmatched-dollar guard: **0 remaining actionable findings**.

## Limits

De-duplication deliberately requires demonstrable equality; mathematically equivalent but differently encoded cells can retain a fallback rather than silently discard it. Native Notion/Feishu blocks and complete-content LaTeX remain outside scope. Production capture-window integration remains with its existing ticket.

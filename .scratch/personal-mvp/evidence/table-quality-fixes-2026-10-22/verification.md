# Golden Set table-consumption fixes — 2026-10-22

Branch: `codex/mvp-table-quality-fixes`, based on integration `e605141`. This work leaves the immutable original Golden Set baseline, recognition service, credential handling, three visible Copy Formats and deferred Notion/menu-bar work unchanged.

## Observed cause and bounded change

1. Hosted Convert Markdown wraps table headers in `<b>…</b>`. Raw HTML is correctly escaped by the generic renderer, but these redundant whole-header wrappers became visible text. The table-header boundary now peels only whole-cell `b`/`strong` wrappers without attributes; normal HTML escaping, inline code, formulas and body-cell markup retain their existing behavior. Header source copying is unchanged.
2. Hosted Convert HTML puts literal TeX inside `<math>…</math>`, not nested MathML, for the observed Greek and power cells. The sanitizer previously suppressed the entire container and lost the formula. Its safe text-only branch now retains that TeX as escaped dollar-delimited source in table cells. Attributes and nested markup are never retained; unknown/nested MathML still follows the original suppression path. Existing full-grid equality can consequently identify the real duplicate. The equality rule itself is unchanged: differing tables, captions and merged structure are still retained.

The service shape was verified with two supplementary fast Recognition Attempts against the already-authorized, non-sensitive authored T04/T13 PNGs using the existing `LiveRecognitionService` and its normal private sandbox token store. Only the returned fixture HTML and Markdown were saved here. These are fresh diagnostic responses, separately provenanced from the original baseline; no original lost cell was reconstructed or replaced. No token, authentication header, user document, unrelated screen pixels, Keychain access or credential migration was involved.

## Red → green evidence

Existing public boundary: `scripts/ticket03_test.sh`, covering `MarkdownRenderer.document` and actual named-pasteboard values from `ClipboardService.copy`.

Header regression failed before its fix:

```text
Ticket 03 self-test failed:
- service bold wrappers do not become literal markup in preview table headers
```

After the header-only fix it passed. The next slice used the literal captured T04/T13 response shapes and failed before the math-text fix:

```text
- Greek table preview omits only the fully represented math fallback table
- Greek table Lark copies one complete table without a lossy duplicate
- Greek table Notion copies one complete table without a lossy duplicate
- Power table preview omits only the fully represented math fallback table
- Power table Lark copies one complete table without a lossy duplicate
- Power table Notion copies one complete table without a lossy duplicate
```

After preserving the observed inert math source, all six passed. Negative checks additionally confirm default raw-HTML escaping, code/math preservation, retention of a different math table, decoded-once `<` content, stripped event attributes, and suppression of nested executable markup. Existing caption/span/entity/security/copy regressions also pass.

## Rendered evidence

The two `*-fixed-preview.png` files were generated offline with the fixed production renderer from the captured fixture responses. Native WK rendering independently observed one table and two KaTeX formulas in each. Visual inspection confirms complete headers/rows, α/β and x²/x³ with no literal header tags or extra table. A fixed 800-point by 500-point viewport avoids the separate Golden runner's earlier auto-height clipping defect. These are bounded fix previews, not final assembled-App capture acceptance.

The temporary live/snapshot probe, its entrypoint and its two bundled input PNGs were removed before the final clean App build. No diagnostic/probe mode is part of this commit.

## Final checks

See the completion record below for final full/focused/signed-bundle/signature/diff results. This fix does not resolve Ticket 05 by itself: the parent owns the fresh complete quality baseline, semantic review, threshold decision and later Ticket 06 integration gate. Real Notion destination behavior is not inferred from local serialization.

Completion: `scripts/test.sh` passed 46 checks plus Ticket 04 workflow checks; `scripts/ticket03_test.sh` passed. Final clean release build succeeded. Its signed executable passed `--ticket03-self-test`, `--self-test` (46 plus Ticket 04), and `--ticket02-recognition-self-test`. Strict deep signature verification and `git diff --check` passed. Executable SHA-256: `badb3346c961235858d93957bd423198f1dedd095489d335eaa7d63011fc6358`. Parent independently viewed both bounded preview PNGs and confirmed complete correct headers/math and exactly one table each.

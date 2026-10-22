# Blank preview after a recovered capture — RED

Date: 2026-10-22. Production source in this isolated checkout is unchanged from `01dffed`; only the existing signed-window/mock-recognition self-test is extended here. The retained sealed candidate is not rebuilt, signed or replaced.

The parent observed a real capture in sealed candidate executable `a9b1c2dfd87173b64a8f8159cdb7ec2c3faab792c553419570ec119c4be78faf`, run `e51e074d-88df-42b7-8a13-41218cb1f150`: validated 1764×996 capture PNG, complete fixture Markdown in the three copy rows, but a persistently blank compact preview and no formula/table preview evidence. A previous tiny-selection error had created an empty result panel. Expanding Edit did not restore the preview; changing only `z^2` to `z^3` restored formula/table DOM within 0.88 seconds. The parent's scalar evidence and observations are stored separately under `/private/tmp/my_mathpix-remaining-context/window-candidate-evidence/`. Two submissions and main visibility remain unresolved operator/activation observations and are **not** assigned to a product defect by this test.

## Public regression seam

The existing window self-test now uses the same formula/table fixture as T1 and reads the actual WKWebView DOM inside the actual production compact panel. A first exploratory run verified cold completion and subsequent empty-panel completion both rendered the expected fixture/formula/table. A second exploratory run put an empty panel first in a fresh process but used a fixed 200 ms response delay; it also passed. These are narrower GREEN observations and do not reproduce the problematic overlap.

The reproducing fixture starts with the existing compact empty surface and a small-selection error sheet, dismisses that error through model state, then hides content windows and starts a new processing record. The external recognition mock waits until the actual hidden WKWebView reports its initial document loading, then returns the complete fixture. No navigation delegate is replaced, no private preview state/hook is invoked, and no actual capture, permission request, global hotkey or live API is used. The same fake hotkey registrar, in-memory stores, isolated scene/defaults and disposable test bundle identity remain in place.

Command from `/private/tmp/my_mathpix-window-roles`:

```sh
./scripts/ticket04_result_editor_window_test.sh
```

Two consecutive runs with unchanged code produced the same RED:

```text
TICKET04_PENDING_DOCUMENT_OBSERVED pending=true
TICKET04_PREVIEW_DOM_OBSERVED scenario=fresh-empty-panel fixture=false formulas=0 tables=0 loading=false
TICKET04_RESULT_EDITOR_WINDOW_FAIL fresh-empty-panel-preview-dom
RED: signed Result Editor window acceptance failed (status=1)
```

The test polls the real DOM up to 100 times at 50 ms after the existing recognition/window settlement wait. The source fixture has completed, but the real preview has neither the fixture marker nor formula/table nodes. This extends the former geometry-only test rather than replacing it with a private coordinator mirror.

## Ranked hypotheses before implementation

1. The preview coordinator's single-use `isAwaitingDocumentLoad` gate permits one offline main-frame programmatic navigation. A previous document navigation can consume that bit after the next document is queued, causing the final navigation to be cancelled. `loadedDocument` is already the final document, so normal unchanged updates never retry. The loading-overlap RED and actual edit recovery support this hypothesis; a one-variable gate experiment will test it.
2. A WebKit load/process failure could likewise leave the early `loadedDocument` cache stuck. There is no failure/process-termination recovery callback. No such failure has yet been observed; do not add speculative recovery until evidence requires it.
3. Resource or source-content loss is less consistent with the successful cold fixture, intact copy rows, same-candidate earlier T3 checks, and immediate recovery after one source-character edit. Renderer/core source is unchanged.

The capture-time App-activation and status-host hiding hypotheses remain separate and are not tested or fixed here.

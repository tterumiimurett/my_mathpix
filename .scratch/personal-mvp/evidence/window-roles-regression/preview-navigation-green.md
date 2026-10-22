# Blank compact preview — minimal fix and supporting GREEN

Date: 2026-10-22. Follow-up to [the twice-repeated public RED](preview-navigation-red.md), committed before the production fix as `a264f77`.

## Diagnosis and one-variable result

The coordinator used one `isAwaitingDocumentLoad` bit for potentially overlapping programmatic document loads. Once one navigation policy decision consumed it, another required offline document navigation could be cancelled. The desired document had already been cached in `loadedDocument`, so unchanged SwiftUI updates did not issue a replacement load. This is consistent with the actual sealed-App blank preview recovering only when the source document changed.

The first production experiment changed exactly one guard condition: remove the single-use bit, retaining the existing `.other` navigation type, main-frame check and `OfflinePreviewNavigationPolicy` about/file URL restriction. The same pending-load fixture that failed twice immediately passed on both displays with fixture text, one rendered formula and one table. This isolates the single-use gate as the cause of the reproduced overlap failure. No renderer, resource, Markdown, recognition, clipboard or history implementation was changed. The final cleanup removes the now-unused bit/prepare method/call and documents why each eligible programmatic load is permitted. Existing JavaScript popup restrictions and content security policy are untouched; user link activations, subframe navigations and non-offline URL schemes still fail the retained guard.

The parent also supplied 67 scoped WebKit loading/process-swapping log entries from the actual isolated T1 PID50276. The two blank pages' navigation policy values differ from those after the actual edit recovery. This is supporting correlation only: no internal numeric enum meaning or WebKit crash is inferred. No speculative process-failure recovery was added.

## Final regression

The permanent test starts with the empty compact result and small-selection error recovery before any cold-preview prewarming. It uses only the existing external-service mock and reads native `WKWebView.isLoading` plus the actual rendered DOM. It now fails explicitly if the pending-load prerequisite is not observed, so a faster environment cannot silently skip the race. The existing geometry, same-panel reuse, explicit main command and compact credential-error sheet checks remain.

Command:

```sh
./scripts/ticket04_result_editor_window_test.sh
```

Final output (exit 0):

```text
TICKET04_PENDING_DOCUMENT_OBSERVED pending=true
TICKET04_PREVIEW_DOM_OBSERVED scenario=empty-panel-overlap fixture=true formulas=1 tables=1
TICKET04_WINDOW_ROLES_OBSERVED compact-width=470.0 compact-height=560.0 floating=true other-spaces=true main-width=1180.0
TICKET04_PENDING_DOCUMENT_OBSERVED pending=true
TICKET04_PREVIEW_DOM_OBSERVED scenario=empty-panel-overlap fixture=true formulas=1 tables=1
TICKET04_WINDOW_ROLES_OBSERVED compact-width=470.0 compact-height=560.0 floating=true other-spaces=true main-width=1180.0
TICKET04_FAILURE_WINDOW_OBSERVED main-visible=false result-visible=true result-sheet=true credential-recovery=true
TICKET04_RESULT_EDITOR_WINDOW_OK all-connected-displays
```

A separate comparison run after the cleanup put a cold first-completion scenario before the overlap cases. It also passed (`scenario=cold fixture=true formulas=1 tables=1`), matching the pre-fix cold GREEN observation. That cold-first ordering was not retained in the permanent regression, to keep the original fresh-process overlap case first. `./scripts/ticket03_test.sh` passed, including existing offline navigation/normalization/copy contracts; `git diff --check` passed. Already-green unrelated full suites were not rerun.

## Integration boundary

The tests build/sign only the isolated checkout's disposable test copy with its separate bundle identifier, in-memory stores, isolated defaults/window state and fake hotkey registrar. They do not replace or start the current sealed production-ID candidate, use actual capture/global events, access owner history/credentials, or call paid services.

The parent must review the exact additional MarkdownPreview host change in the source bridge, rebuild/seal a new candidate, and repeat actual first-capture preview/UI acceptance. The existing sealed a9 artifact has not been changed and its initial blank preview remains a recorded RED. Two submissions, activation-time main visibility and possible status-host hiding remain separate observations requiring their own evidence; this fix does not assign or change their causes.

## Test synchronization review follow-up

Independent Standards and Spec reviews reported zero actionable findings. Their synchronization boundary check identified that the test-owned mock could receive `complete()` before its continuation was installed; MainActor jobs do not imply FIFO order. The mock now returns whether it actually resumed an installed continuation. The existing pending loop succeeds only when the native WK view is loading **and** that synchronous release returns true, so no early release is lost or mistaken for a satisfied overlap prerequisite. This adds no production hook or separate mirror test. Native loading state still does not claim the exact ordering of individual WebKit policy callbacks.

Re-ran the same `./scripts/ticket04_result_editor_window_test.sh`: both displays observed `pending=true`, fixture/formula/table DOM, correct compact/main roles, and the compact credential-error sheet; final marker `TICKET04_RESULT_EDITOR_WINDOW_OK all-connected-displays`. `git diff --check` passed. Production `ContentView.swift` is byte-identical to `54135e2` (Git blob `28a722dd7fb2031587c15039ea94c46fb38da440`); no other production source changed in this follow-up. Unrelated suites were not rerun, and the current sealed candidate and integration tree remain untouched.

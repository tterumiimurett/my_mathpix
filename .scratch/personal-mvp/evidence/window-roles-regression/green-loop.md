# Compact/main window roles — supporting regression evidence

Date: 2026-10-22 (Asia/Shanghai). Implementation checkout `/private/tmp/my_mathpix-window-roles`, branch `codex/restore-compact-result-panel`, based on integration `22bf0fd`. The initial red test/evidence was committed as `3442f98` before production edits.

## Cause and correction

The production presenter sent both the main-workspace and capture-result intents to its `mainWindow` and activated the application for both. Normal launches hosted the 1180-point workspace; only the Ticket 03 fixture branch hosted the compact editor. The old menu action also opened the main workspace. The accepted compact surface therefore existed but was not used by normal capture completion.

The shell now owns a separate nonactivating AppKit result panel hosting the existing `ResultEditorView` and the same `AppModel`. The production presenter routes completion/result commands to that panel without activating the App, and routes explicit workspace commands to the main window while hiding the panel. The panel has floating level, can join all spaces, and is a full-screen auxiliary window. Its default **outer frame including the title bar is 470 × 560 points**; the presenter constrains it to the display's visible area and uses a 16-point top-left inset. Independent Original/Edit, preview, copy rows, edits and retry data remain shared; only the processing footer was added for compact retry feedback.

The real status item left-click calls the result command, while App activation/reopen calls the workspace command. Its right-click menu retains Capture with the configured shortcut hint, the current read-only status, Open MyMathpix, Settings and Quit. Settings delegates to the existing SwiftUI openSettings environment action installed by ContentView, without a private selector. The Ticket 03 seeded launch also uses this same panel; its separate compact-only WindowGroup layout was removed. Existing GUI test modes use a unique scene identifier, disabled restoration and an empty frame-autosave name, to avoid altering the normal main-window geometry. Their status item does not use the production item-position autosave name.

## Vertical test loop

The first compact-result RED was observed twice before production changes; see [red-loop.md](red-loop.md). Two further slices exposed and corrected independent role mistakes:

```text
TICKET04_WORKSPACE_OBSERVATION main-visible=true main-width=1180.0 result-visible=true
TICKET04_RESULT_EDITOR_WINDOW_FAIL explicit-workspace-role

TICKET04_RESULT_REOPEN_OBSERVATION main-visible=true same-result=false selected-preserved=true
TICKET04_RESULT_EDITOR_WINDOW_FAIL result-command-role
```

The final signed-App window test uses synthetic pixels and recognition but actual assembled AppKit/SwiftUI surfaces. On both connected displays it observed:

```text
TICKET04_WINDOW_ROLES_OBSERVED compact-width=470.0 compact-height=560.0 floating=true other-spaces=true main-width=1180.0
TICKET04_WINDOW_ROLES_OBSERVED compact-width=470.0 compact-height=560.0 floating=true other-spaces=true main-width=1180.0
TICKET04_FAILURE_WINDOW_OBSERVED main-visible=false result-visible=true result-sheet=true credential-recovery=true
TICKET04_RESULT_EDITOR_WINDOW_OK all-connected-displays
```

The same test verifies hidden main during recognition, completion placement and actual display identity after settling, compact content-window count, native floating/space properties, explicit public main command hiding the result, and public result command reusing the same panel and selected Snippet. It also verifies the GUI test main window is not restorable and has no frame autosave name. An added invalid-credentials mock failure verifies its actual error sheet attaches to the compact panel and leaves main hidden. That failure check is supplemental GREEN coverage; it was not a separate pre-fix RED claim.

Commands run from this implementation checkout:

```sh
./scripts/ticket04_result_editor_window_test.sh
./scripts/test.sh
./scripts/ticket03_test.sh
./scripts/ticket02_recognition_test.sh
./scripts/ticket04_daily_workflow_test.sh
git diff --check
```

Supporting outcomes: window regression passed; full self-test passed 48 checks plus Ticket 04 workflow checks; Ticket 03 copy/edit checks passed; signed recognition contract passed; signed daily workflow, sandbox/export entitlements, version/license packaging and public shell AX labels passed. The legacy packaging check for implementation class names and short menu literals was replaced with public AX identifiers: Swift optimizes the new AppKit short string literal, so `strings` is not a menu-behavior test. The wrapper now explicitly reports `actual-menu-click=pending`.

## Coverage boundary

This is supporting evidence, not the final signed-candidate UI acceptance. The window wrapper builds only this checkout, copies that App and assigns a disposable test bundle identifier before signing it. It does not replace the retained delivery candidate or access owner history/credentials, actual screen pixels, paid API calls, TCC settings or Hidden Bar configuration. The final exact production-ID sealed App still needs its own window-flag run and artifact identity verification by the parent.

The parent must observe actual capture completion over another App, the physical status item's visibility and left click, Command-Tab/Dock activation, editing/copy destinations, retry progress and failure recovery. Native floating/all-spaces flags are supporting evidence and do not by themselves prove behavior in every other App/full-screen space. The window fixture hides only content-sized windows; this does **not** prove that the production CaptureCoordinator's broad window hiding cannot affect a status-item host window. That remains a falsifiable hypothesis for an actual before/after-capture menu observation; CaptureCoordinator is unchanged until a real RED justifies a fix. Notion inline equations remain separately deferred in Ticket 07.

The source bridge also needs a reviewed update for these intentional production UI-host changes; new AppWindowShell/AppModel/ContentView/ResultEditorView/MyMathpixApp behavior must not be relabeled acceptance-only telemetry. Recognition, Datalab, normalization/rendering, copy formats, history, usage and immutable Golden evidence remain outside this correction.

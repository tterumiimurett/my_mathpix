# Compact result window regression — RED evidence

Date: 2026-10-22 (Asia/Shanghai). Starting source: integration `22bf0fdc7f7d523f370cd6b05177243506e0c012`.

The existing public signed-App window / mock-recognition seam now checks the owner's explicit compact-result contract: one compact visible result, a hidden main workspace, a floating window level, and settled placement on the selected display. Capture pixels and the service are synthetic; AppKit/SwiftUI windows and production completion presentation are real. History is in memory, defaults and diagnostics are disposable, and the script's copied App has a separate test bundle identifier.

Command (from the isolated implementation checkout):

```sh
./scripts/ticket04_result_editor_window_test.sh
```

Both runs produced the same observed failure:

```text
TICKET04_COMPACT_OBSERVATION visible-windows=1 main-visible=true width=1180.0 height=632.0 floating=false
TICKET04_RESULT_EDITOR_WINDOW_FAIL compact-result-role
RED: signed Result Editor window acceptance failed (status=1)
```

The first run bootstrapped the release build. The repeat used cached compilation and completed in 4.604 seconds, exit 1. The failure is the user-reported pattern: completion shows the large normal-level main workspace, not a compact floating result. No production implementation change, actual Screen Capture, live API request, owner-history/token change, or delivered-App replacement was made before this evidence. Root separately observed the existing production App through CUA.

Implementation is paused after the red signal pending the parent's ranked hypotheses.

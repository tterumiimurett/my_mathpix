# Signed candidate acceptance (Ticket 06)

Build once in the Ticket 06 worktree after code checks/review. Copy the complete signed `.app` to the retained integration worktree's `dist/MyMathpix.app` **before** sealing; do not rebuild or re-sign that artifact during acceptance. The current stable location is:

`/Users/bytedance/.codex/worktrees/personal-mvp-integration/my_mathpix/dist/MyMathpix.app`

`candidate_checks.py APP --evidence-dir NEW_DIRECTORY --git-commit SHA` runs eight existing signed CLI seams and records signature/CDHash, binary and bundle-tree hashes, architecture/macOS, version, sandbox entitlements, offline resources/license hashes. It never builds, signs, resets TCC or requests recognition. All GUI/live/destination/dogfood acceptance remains explicitly unasserted. The fixed-output filter excludes arbitrary process output. Run supporting checks before interactive acceptance, so test-only relaunch markers or global clipboard probes are not interleaved with an active journey.

`candidate_checks.py APP --verify-manifest DIRECTORY/supporting-checks.json` only verifies the current artifact against the prior successful manifest. Use this after GUI steps and before handoff; it does not rerun the eight tests.

`source_bridge.py REPO APP GOLDEN_PROVENANCE --output NEW_JSON` records the candidate/source bridge to the reviewed Ticket 05 run. Recognition, normalization, preview, safe-table, clipboard, history, usage, Golden Set runner and bundled resource inputs must match the quality candidate exactly. Only the enumerated acceptance host/telemetry/inspector/test changes may differ; those differences require code review. This is source continuity evidence, not a repeat quality run or binary-equivalence claim.

`test_launch_contract.py EXECUTABLE` verifies malformed/duplicate/unknown/conflicting Ticket 06 CLI arguments exit 2 before owner-state initialization. The existing `--self-test` keeps the pre-fix red safe; the UUID mode intentionally rejects simultaneous test modes.

## Disposable live and controlled-fault sessions

Generate one run UUID and reuse it when relaunching the same disposable history. Use the normal production-identity candidate; no token is copied. `.live` passes the existing `LiveRecognitionService` as both service and credential configuration, so real credential preflight and Settings remain normal. The acceptance-specific history, Usage Records, diagnostics and defaults are isolated. Credential Settings operate the normal approved credential store; do not change or clear credentials as part of disposable history tests.

```sh
open -n /Users/bytedance/.codex/worktrees/personal-mvp-integration/my_mathpix/dist/MyMathpix.app --args --ticket06-acceptance=REPLACE_WITH_UUID --ticket06-service=live
```

The App validates a canonical UUID and rejects malformed configuration without falling back to normal owner history. Extra service options are `failure`, `timeout`, and `malformed`: they keep **real Screen Capture**, disposable persistent state, normal result/error UI and the public Datalab client, but substitute the existing deterministic external transport with a non-secret sentinel. `timeout` uses a disclosed seven-second test deadline, permitting the normal five-second slow message; it is not a new default live timeout or proof of a real sixty-second wait. `malformed` supplies malformed polling JSON. These modes do not send a real request.

To test Failed Record recovery, launch a controlled failure session, capture a deliberate fixture, copy its retained original image, quit that exact session, then relaunch the **same UUID** with `--ticket06-service=live` and Retry. Balanced retry reuses the same original and retains edit-replacement confirmation. Do not substitute a simulated failure for the required live fast/balanced success observations.

Under the normal bundle ID the exact root is:

`~/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket06Acceptance/<lowercase-uuid>/`

It contains `History/history.json` and PNG artifacts, `Usage/usage-records.json`, `Diagnostics/events.json`, and `session.json`. Defaults use `com.byterumi.mymathpix.ticket06.<lowercase-uuid>` inside the app's sandbox preferences. The same UUID restores prior final edits and Failed Records; another UUID starts independently. Login-item changes are disabled in this test mode. A shortcut changed through Settings persists only in the session's defaults; existing preview processes may own the default, and the conflict must remain visible.

`session.json` contains only scalar process/run/service/status/count/source-hash/image-retention observations, never credential bytes, source text or Snippet pixels. Its existence is **not** GUI acceptance. Read it alongside actual CUA observations and the sealed artifact manifest. Only deliberate acceptance fixture content may be inspected in this disposable history; never clear or bulk-fill the normal owner history.

## Actual signed-App journeys remain required

Use the same immutable candidate for the existing Ticket 01 real selection/mock-recognition primary seam and the real-service session above. The parent agent must personally drive the shortcut and selection, observe process survival, progress, rendered formula/table, Original/Edit visibility, recent history and captured-display placement. The current hardware probe found two Retina displays: primary `(0,0,1280,720)`, secondary `(1280,0,1312,848)`, scale 2 each. Reconfirm the current UI geometry when operating it; this probe is not a capture pass. Screen Recording grant is currently pending; do not grant/reset it without the parent's action-time approval flow.

The corrected Ticket 03 script accepts `MYMATHPIX_ACCEPTANCE_APP=APP`, derives its bundle ID, and pins PID/run/CDHash. Click Markdown/Lark/Notion and immediately run `inspect-copy FORMAT initial`; open Original/Edit, replace with the declared edited fixture, then repeat `inspect-copy FORMAT edited` for all three. Retain the six stage-labeled inspector observations. A type-only match cannot pass the Notion inspector. No real destination paste/native editability is asserted.

The eight supporting seams cover the deterministic persistence/eviction/permission-mapping/timeout/malformed/clipboard boundaries. Actual granted capture/multi-display/editor/live flow must still be recorded separately. Menu-bar visibility and Notion inline destination math remain deferred. Ticket 05 also records M15's flattened blockquote, B06's local currency/formula ambiguity and B08 balanced's table structure defect. Keep all limits in handoff. Fourteen blank dogfood rows are a handoff, not fourteen completed days or permission to start Public Product work.

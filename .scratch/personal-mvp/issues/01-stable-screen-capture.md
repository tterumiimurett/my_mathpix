# 01 — Make Screen Capture survive through a mock result

**What to build:** The owner can launch the signed App, invoke Screen Capture, select a known on-screen fixture, and reach a visible editable result supplied by a deterministic mock recognition service without the App terminating. Capture permission, cancellation, invalid selections, and ordinary multi-display use fail or recover in ways the owner can understand.

**Blocked by:** None — can start immediately.

**Status:** claimed

## Suggested agent split

- **Work package A — Reproduction and acceptance seam:** make the highest-level signed-App flow reproduce the reported process termination, retain a redacted crash artifact, and fail specifically when the process dies before recognition submission.
- **Work package B — Capture lifecycle and hardening:** repair overlay, selection, display identity, coordinate conversion, image capture, and callback lifetimes; cover permission and cancellation paths.
- These packages are sequential at their integration boundary: establish the failing seam first, then repair against it. The main agent owns the final capture-to-result run.

## Acceptance criteria

- [ ] The authoritative signed-App test invokes the configured shortcut, drags a known rectangle, consumes a deterministic mock submit-and-poll response, and observes the Result Editor and one Recognition Attempt.
- [x] The test fails specifically on process death when run against the reported regression, and a redacted crash artifact contains no credential, Snippet pixels, or complete recognized output.
- [ ] After the fix, the App remains alive through overlay dismissal and asynchronous PNG capture; the selected fixture, expected Canonical Markdown, rendered formula or table, and Recent History entry are visible.
- [ ] Screen Recording states of not determined, denied, granted, and revoked produce an explanation or recoverable state and never terminate the process.
- [ ] Escape, a tiny accidental selection, display disappearance, and capture API failure return the App to an operable state without creating a spurious successful record.
- [ ] The selected Retina pixels and multi-display geometry are preserved correctly, App windows are excluded from the selection, and only the selected PNG proceeds to recognition.
- [ ] A second capture is blocked with a clear message while one Recognition Attempt is active.

## Comments

### 2026-09-04 — implementation and acceptance audit

Implementation repaired the overlay/capture lifetime, designated-window initializer crash, release-after-close crash, signed-bundle resource lookup, stable display geometry, Retina rounding, own-window exclusion, cancellation recovery, explicit capture state, and recoverable ScreenCaptureKit errors. A later owner-reported fullscreen-Space gap was reproduced by the overlay contract and repaired with a nonactivating `NSPanel` that joins fullscreen and multi-display Spaces. The owner confirmed the fullscreen region is now covered. Real Datalab recognition quality and service-returned image references remain Ticket 02 scope.

The deterministic acceptance adapter exercises the real signed-App ScreenCaptureKit path and the real Datalab client submit/poll parser through an isolated URL protocol. It validates approved multipart fields, PNG dimensions, fixture markers/content, guard-band exclusion, sRGB/Display-P3 conversion, one fixed mock result containing a formula and table, and offline preview rendering. Acceptance mode uses in-memory history, an isolated defaults suite, and a non-secret sentinel; it does not read the local token file. Evidence is scalar-only and contains no credentials, Snippet pixels, request body, authentication header, or complete recognition output.

Verified supporting evidence:

- Baseline process termination: `evidence/ticket-01/baseline-crash-summary.txt` records redacted `EXC_BREAKPOINT`/`SIGTRAP` before recognition; `second-red-crash-summary.txt` records the later overlay release failure. No credential, pixels, or recognized output are present.
- Final assembled App is ad-hoc signed and sandboxed; CDHash `9d6cde0d61b80eef236631771a29b0020b1ac571`. Strict signature verification passed.
- `scripts/test.sh`: 31 deterministic checks passed.
- Signed-App checks passed: mock protocol (`submit=1`, `polls=5`, PNG/fields/fixture/guard/result all yes), overlay lifecycle, bundled resources, and private local-token file behavior.
- Source and binary checks found no Security framework import, `SecItem` symbol, or `KeychainStore` reference. No Keychain item was read, migrated, written, or deleted.
- The owner confirmed real shortcut capture, rectangle bounds, Result Editor visibility, formula/table preview, repeated capture after Escape, multi-display overlay coverage, and fullscreen-Space coverage. No new MyMathpix crash report was emitted on 2026-09-04.

The ticket remains `claimed`, not `resolved`, because the final strict signed-App evidence did not satisfy every compound acceptance criterion. The last scalar-only run reached a live complete Result Editor with correct fixture, formula, table, PNG dimensions, and history, but accumulated `submit_count=3`, `recent_history_count=3`, `second_capture_blocked=false`, and selected the 1x primary display. A fresh exactly-one-attempt Retina-secondary run is still required. Actual macOS not-determined and revoked-after-prior-grant states, plus a real display-disappearance/capture-API-failure recovery run, remain unexecuted. This directory has no Git metadata (`git status` reports “not a git repository”), so the requested commit is also impossible without repository metadata; no repository was initialized and no commit was fabricated.

### 2026-09-04 — Git status correction

The preceding audit accurately recorded the repository state at that time. The owner subsequently authorized Git initialization. Commit `6692c67` on `main` now records the pre-review Ticket 01 snapshot, and review fixes are developed on `ticket01-review-fixes`; no pre-Ticket implementation history was reconstructed or fabricated.

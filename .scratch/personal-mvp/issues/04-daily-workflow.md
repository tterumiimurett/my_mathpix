# 04 — Make the App dependable for a daily personal workflow

**What to build:** The owner can keep MyMathpix available from the menu bar and normal window, configure capture behavior, return to recent work after navigation or relaunch, and control locally retained content. Diagnostics and license information support troubleshooting without becoming another content store.

**Blocked by:** 01 — Make Screen Capture survive through a mock result.

**Status:** claimed

## Suggested agent split

- **Work package A — Recent History lifecycle:** cover creation, edit autosave, failure retention, relaunch recovery, deletion, clear-all, bounded eviction, and associated image cleanup.
- **Work package B — App shell and control:** cover menu bar and window access, global shortcut configuration and conflicts, launch at login, settings, diagnostics, version, and licenses.
- The main agent verifies that both packages use one coherent record and settings model and that a relaunch preserves the complete user workflow.

## Acceptance criteria

- [x] The App is usable from both a menu bar presence and a normal application window, with a default global shortcut of Control-Command-M.
- [x] The owner can customize the shortcut, and registration conflicts are reported immediately instead of failing silently.
- [x] Recent History preserves the original image and final edited output for the twenty newest Successful or Failed Records inside the App Sandbox container.
- [x] Edits autosave and survive navigation and relaunch; retry updates remain associated with the existing Snippet.
- [x] Creating the twenty-first record evicts the oldest record and its image together, and the owner can delete one record or clear all history.
- [x] Launch at login is disabled by default and can be deliberately changed in Settings.
- [x] Local diagnostics exclude credentials, authentication headers, Snippet pixels, and complete output, and no analytics or automatic upload is introduced.
- [x] The App exposes its version and bundled third-party license notices.
- [ ] A Screen Capture keeps the App window hidden while recognition is active, then presents the Result Editor at a 16-point inset from the top-left visible area of the captured display (falling back to a remaining display only if that display disappears).

## Answer

Reopened on 2026-09-05 because the automatic Result Editor window behavior did not yet meet the owner-confirmed daily workflow: at reopening, recognition opened the main window before completion and did not preserve the captured display identity through to Result Editor presentation. The ticket remains claimed until the Result Editor is presented only after recognition completes, at the top-left visible area of the display where the Snippet was captured, with risk-proportionate signed-App and multi-display evidence recorded below.

Implementation candidate on 2026-09-05 now carries the stable `CGDirectDisplayID` from `ScreenCaptureRequest` into `CapturedSnippet` and through `AppModel` until the Recognition Attempt finishes. Successful Screen Capture no longer restores previously visible App windows before recognition; cancellation and capture failure still restore them. Completion (including the existing recoverable failure path) delegates to an AppKit Result Editor window presenter that targets the captured `NSScreen.visibleFrame` with a 16-point top/left inset, falling back only if the captured display has disappeared. Pure Formula auto-copy still occurs, but no longer suppresses the Result Editor window requested by the owner.

Supporting evidence is green: a deferred-recognition test proves no presentation call occurs before completion and that completion receives the original display ID; geometry coverage includes a secondary display with a negative origin; the signed Ticket 04 workflow seam and the full 46-check suite pass. The signed Ticket 01 acceptance reporter was extended with scalar-only evidence for pre-completion window visibility, requested/actual display matching, and visible-area placement. The current session reported three active displays, but the live capture fixture could not be driven without taking over a browser the owner was actively using. Therefore the new acceptance box remains unchecked and the ticket remains `claimed` pending one real signed-App capture on a secondary display followed by `scripts/ticket01_signed_app_acceptance.sh verify-secondary`.

This candidate does not use any Ticket 02 or Ticket 03 in-progress interface, component, size, or worktree.

The required two-axis review used `4f1c994` as its fixed point. Initial Standards review found one terminology violation and one primitive window-identity smell; initial Spec review found that a closed window could be abandoned after two short main-queue retries. Commit `4b1b3f8` fixed all three by using the glossary's Result Editor terminology, registering the real SwiftUI `NSWindow` with a stable identifier, and retaining a pending presentation until the window is registered (including when the opener arrives later). Standards and Spec re-reviews both returned zero findings. After remediation, `scripts/ticket04_daily_workflow_test.sh` and `scripts/test.sh` passed again against the signed sandboxed candidate.

Resolved on 2026-09-04. MyMathpix now keeps one coherent Recent History and settings model for daily use: a `WindowGroup` and `MenuBarExtra` share the same `AppModel`; the default exclusive global shortcut is Control-Command-M, can be changed and restored, rejects malformed keys, preserves the working registration on failure, and displays conflicts beside the shortcut controls immediately. Launch at login starts disabled and is changed only through Settings. Version `0.1.0 (1)`, the full bundled KaTeX MIT notice, fixed content-free local diagnostics, deliberate diagnostic export, single-item deletion, clear-all, and confirmation for destructive history clearing are exposed in Settings.

The signed-App persistence seam passed creation, Successful and Failed Record retention, edit autosave across navigation and relaunch, interrupted-attempt recovery as a Failed Record, retry on the same record/image, single deletion, clear-all, twenty-record eviction, and deletion of the evicted image. History indexes and image artifacts use private files under the App Sandbox container; diagnostic events accept only fixed codes and optional fixed Recognition Mode values. The package has no third-party dependency or analytics integration, and source inspection found network access only in the direct Datalab client and deterministic Ticket 01 mocks.

Verification evidence:

- `scripts/ticket04_daily_workflow_test.sh` passed against the assembled, ad-hoc-signed App with App Sandbox and user-selected diagnostic-export entitlements. Its scalar output was `history=create-edit-failed-retry-relaunch-delete-clear-evict-image-delete`, `diagnostics=fixed-codes-redacted-manual-export`, `shell=menu-bar-and-window`, `shortcut=control-command-m-conflict-visible`, `launch-at-login=opt-in`, `version=0.1.0`, and `licenses=bundled`.
- `scripts/test.sh` passed all existing 46 deterministic checks plus the Ticket 04 workflow checks after the review refactor.
- An isolated signed App was operated through the real macOS UI without loading the owner's token or history. It showed the normal window and Settings, saved Control-Command-K, displayed a real cross-process Control-Command-M registration conflict in red beside the shortcut controls, started with launch at login off, successfully toggled it on and back off, displayed version `0.1.0 (1)`, and expanded the full KaTeX MIT license. Closing the normal window left the App process running, and activating the App reopened a new normal window; the signed bundle also contains the functional menu-bar Capture, Show MyMathpix, Settings, and Quit commands.
- The final two-axis review found no documented Standards or ADR violation and no Spec finding. One duplicated rollback judgment was fixed and reverified. The remaining judgment that `AppModel` coordinates several daily-workflow controls was retained because this ticket explicitly requires one coherent record and settings model; splitting it now would add an unrequested middle layer.

No Ticket 02 or Ticket 03 worktree was read or modified, and no recognition or copy-format behavior from those tickets was added.

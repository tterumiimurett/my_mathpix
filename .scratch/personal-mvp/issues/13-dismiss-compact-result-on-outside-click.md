# 13 — Hide the compact result when clicking outside

**Status:** resolved

**Blocked by:** None.

## Intended outcome

After capture or a menu-bar click shows the compact result, clicking outside
hides it without swallowing the click or opening the large workspace. Clicking
inside keeps the result usable. The menu bar can reopen the same selected result.

## Acceptance criteria

- [x] Outside clicks in another app and within MyMathpix hide only the compact result.
- [ ] Inside clicks, editing/copy controls and recovery sheets remain usable.
- [x] Repeated hide/reopen preserves the selected result and reinstalls monitoring.
- [x] Focused signed-window regression and installed-App interaction verified.

## Implementation

Mouse-down monitors cover both local and other-application events because the
compact result is a nonactivating panel; deactivation alone misses clicks back
into an already-active foreground app. Monitors exist only while the compact
panel is shown and never consume the click. Attached recovery sheets are exempt.

## Verification — 2026-10-23

- Signed window regression passed on connected displays: `TICKET04_OUTSIDE_CLICK_OK
  inside-retained=true outside-hidden=true reopen-preserved=true` across two
  hide/reopen cycles. Existing compact geometry, main-workspace separation,
  pending preview loading and attached recovery-sheet checks also passed.
- Basic suite passed: 48 checks plus Ticket 04 daily workflow.
- Build 5 installed at `/Applications/MyMathpix.app`; strict signature and
  executable SHA256 match the built candidate:
  `19829807dbe1ab72af16bc436263bffb57f3bf3b11a89dd8cf98465e385516c7`.
  App reopened successfully. Previous App preserved in
  `dist/backups/MyMathpix-before-outside-click.zip`.
- Desktop automation took almost five minutes on its first connection; the
  isolated acceptance fixture then reopened the main workspace. No physical
  other-app mouse-click acceptance is credited. Owner should try one click into
  another App after opening the compact result. No screenshot/OCR submission,
  token access or history modification was performed for these tests.
- macOS Screen Capture authorization was not rechecked for this new signature.
  GitHub release remains v0.1.2; this is the locally installed feature candidate.

## Answer

2026-10-23 — Owner accepted the installed feature (“OK, 很好”) and authorized
GitHub publication. This closes the pending owner acceptance checkpoint above.
Outside clicks hide the compact result without discarding the selected Snippet;
the existing menu-bar command reopens it. Local event dispatch, two hide/reopen
cycles, recovery sheets and existing window roles passed the signed regression.
The basic suite passed 48 checks plus Ticket 04 daily workflow. Detailed manual
editing/copy-control exercises were not individually recorded, so that combined
criterion remains unchecked rather than asserting additional test coverage.

The v0.1.3 distribution updates version metadata only from the owner-tested
build, then re-signs. Existing releases are retained. No changes to history,
credentials, recognition, clipboard formats or the large workspace are included.

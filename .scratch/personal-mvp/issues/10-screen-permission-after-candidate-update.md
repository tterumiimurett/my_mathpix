# 10 — Restore Screen Capture permission for the current App version

**Status:** resolved

**Blocked by:** None.

## Problem

Owner reports Screen Capture still asks for authorization after enabling
MyMathpix in System Settings. System Settings showed MyMathpix on. The running
candidate was the repository `dist/MyMathpix.app`, while `/Applications` held
accepted V1. Both use bundle identifier `com.byterumi.mymathpix`, but their
ad hoc designated requirements pin different code hashes.

After removing/re-adding only MyMathpix and selecting the exact dist candidate,
the system requested Quit and Reopen. That action demonstrably launched the
old `/Applications/MyMathpix.app`, not the selected candidate. Thus toggle-on
and a restart do not establish current-candidate permission.

## Intended outcome

Use one unambiguous application at the canonical installation path and verify
permission in that running App with the real capture entry. Do not use a
Terminal-context preflight as proof of GUI authorization. Preserve V1 backup,
owner history and credentials; do not reset other applications' permissions.

## Acceptance criteria

- [x] Confirm the actual process paths and the two different signed builds.
- [x] Confirm MyMathpix toggle-on in Screen & System Audio Recording settings.
- [x] Reproduce system Quit and Reopen launching old V1 after selecting candidate.
- [x] Preserve and verify a complete installed V1 backup before replacement.
- [x] With explicit owner authorization, stop the existing App and install the prepared candidate at /Applications/MyMathpix.app.
- [x] Re-register only MyMathpix permission for that fixed artifact, relaunch, and confirm exact running path/build.
- [x] Confirm actual capture overlay works without a renewed authorization loop; cancel before recognition unless separately authorized.

## Evidence and current blocker

2026-10-22 — Candidate executable SHA256 is
`701ac58e1c5cbe1f9947998fedf2b2c0da305c52e884af1adf1bc0f7f211b5a3`,
CDHash `4f00a5db8ba8f66299b8830a49ebf4e93cf15ec8`.
V1 executable SHA256 is
`a05eefa3cb53fa9d7ec73fa40ec51964876d7c028067fb33d49fddde15a08150`,
CDHash `0e22025dae3b9b101e692333f7eb3b03b1763c99`.
Both designated requirements consist of their respective cdhash.

Candidate PID54939 ran from the repository dist path. Following the System
Settings Quit and Reopen action, PID56720 instead ran from `/Applications`.
Both observations were process-path metadata only, without arguments or tokens.
CUA reads/normal-quit targeting the App subsequently failed/timed out, so actual
capture permission has not been proved. MyMathpix was re-added and toggle-on
was observed, but that does not satisfy the final criteria.

Full V1 backup: `dist/backups/MyMathpix-installed-v0.1.0-before-notion.zip`.
The archived executable's SHA256 was verified against the installed V1.
The candidate signature also passed strict verification. No installed files
have yet been changed. The released ZIP and main branch are unchanged.

Automatic approval rejected a proposed SIGTERM of the exact old-App process:
it might lose unsaved state, and the owner had not explicitly authorized
stopping and replacing the installed version. No process was terminated.
Owner approval was requested for exit plus replacement, with a save-and-exit
option and V1-retention option. Do not bypass the rejection through a different
process or UI route; wait for the owner's specific authorization.

## References

Apple confirms ad hoc signing identity changes across builds and recommends
stable development signing for permission continuity:
https://developer.apple.com/forums/thread/819406
https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements

A stable signing certificate is a separate follow-up decision. No certificate,
private key, credential or custom weakened signing requirement was created,
read or changed here.


2026-10-22 — Owner explicitly approved “允许退出并替换”. After rechecking
candidate signature and the archived V1 executable, the exact matching App
process was normally terminated and the candidate staged, verified and moved
to `/Applications/MyMathpix.app`. Final executable SHA256 and strict signature
verification match the prepared candidate. Installation did not modify owner
history or token files. Main and published V1 remain unchanged.

After launch, PID58589 runs from `/Applications/MyMathpix.app` with candidate
CDHash `4f00a5db8ba8f66299b8830a49ebf4e93cf15ec8`. CUA App inspection still
times out, so no overlay success is credited. MyMathpix's System Settings
record is on. Refreshing that single record now triggered the macOS
“隐私与安全性正在尝试解锁系统设置” Touch ID/password sheet. The agent stopped
at that authentication step and asked the owner to complete it. No password
was read or entered; re-registration, final relaunch and actual overlay
acceptance remain pending. Do not rebuild/re-sign this fixed candidate while
validating its permission identity.


## Answer

Owner completed system authentication. The agent removed the old single-App
record, explicitly selected `/Applications/MyMathpix.app` in the file chooser
(the final selected URL was verified, rather than trusting the previous dist
selection), added it, and used the system Quit and Reopen action. MyMathpix is
on in Screen & System Audio Recording. The relaunched PID64951 is at the
canonical installed path with frozen candidate executable SHA256 `701ac58...`.
The App's live preview also resolves bundled resources from `/Applications`.

The actual Capture button opened the full-screen gray selection overlay;
Escape restored the main window without a permission-denied message. During
subsequent observation the App displayed Recognizing, then a compact result
with High Quality Retry, corroborating a working captured-Snippet path. Agent
performed no region drag/selection or OCR submission; the initiating gesture
for that subsequent recognition was not established. No global-hotkey,
selection-pixel accuracy or latency acceptance is claimed here.

The current permission loop is resolved for this frozen installed artifact.
Ad hoc signing still binds identity to each build, so a later rebuild may
require re-registration; stable certificate signing remains a separate
follow-up and was not configured or weakened. V1's verified backup is retained.
Owner history/token files were not edited by installation/permission work.

Ticket 07 remains open for actual normal-copy acceptance, now unblocked from
this runtime/authorization ambiguity. No main merge or public release update.

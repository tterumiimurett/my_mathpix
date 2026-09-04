# 04 — Make the App dependable for a daily personal workflow

**What to build:** The owner can keep MyMathpix available from the menu bar and normal window, configure capture behavior, return to recent work after navigation or relaunch, and control locally retained content. Diagnostics and license information support troubleshooting without becoming another content store.

**Blocked by:** 01 — Make Screen Capture survive through a mock result.

**Status:** ready-for-agent

## Suggested agent split

- **Work package A — Recent History lifecycle:** cover creation, edit autosave, failure retention, relaunch recovery, deletion, clear-all, bounded eviction, and associated image cleanup.
- **Work package B — App shell and control:** cover menu bar and window access, global shortcut configuration and conflicts, launch at login, settings, diagnostics, version, and licenses.
- The main agent verifies that both packages use one coherent record and settings model and that a relaunch preserves the complete user workflow.

## Acceptance criteria

- [ ] The App is usable from both a menu bar presence and a normal application window, with a default global shortcut of Control-Command-M.
- [ ] The owner can customize the shortcut, and registration conflicts are reported immediately instead of failing silently.
- [ ] Recent History preserves the original image and final edited output for the twenty newest Successful or Failed Records inside the App Sandbox container.
- [ ] Edits autosave and survive navigation and relaunch; retry updates remain associated with the existing Snippet.
- [ ] Creating the twenty-first record evicts the oldest record and its image together, and the owner can delete one record or clear all history.
- [ ] Launch at login is disabled by default and can be deliberately changed in Settings.
- [ ] Local diagnostics exclude credentials, authentication headers, Snippet pixels, and complete output, and no analytics or automatic upload is introduced.
- [ ] The App exposes its version and bundled third-party license notices.


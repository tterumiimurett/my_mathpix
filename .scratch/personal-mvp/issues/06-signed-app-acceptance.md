# 06 — Deliver a signed-App acceptance candidate

**What to build:** The owner receives an assembled, sandboxed, ad-hoc-signed MyMathpix App whose actual shortcut-driven workflow succeeds on the current Apple Silicon Mac. The candidate is verified as the artifact the owner will use, with known limitations and a concrete fourteen-day dogfood handoff, rather than being declared complete from compilation or isolated tests.

**Blocked by:** 04 — Make the App dependable for a daily personal workflow; 05 — Prove recognition quality with the Golden Set.

**Status:** claimed

## Comments

- 2026-10-22: Ticket 05 ordinary quality gate is verified for both modes. Claimed on integration baseline `a1333d6` to assemble and support-check one stable signed candidate. Actual shortcut/selection/live-service GUI acceptance remains pending; the parent agent owns those observations. Existing menu-bar and Notion-inline exceptions remain unresolved.

## Suggested agent split

- **Work package A — Candidate assembly and evidence:** assemble the signed sandboxed App, run automated checks, verify bundled resources and licenses, and produce a clean candidate.
- **Work package B — Independent user-journey audit:** exercise capture, recognition, editing, copy, history, relaunch, permissions, cancellation, and recoverable failure against the assembled candidate.
- The main agent reconciles both evidence sets, repeats the authoritative flow personally, and does not accept a child agent's build or launch report as proof of the core workflow.

## Acceptance criteria

- [ ] The same assembled, sandboxed, ad-hoc-signed App intended for handoff passes the authoritative shortcut, real selection, deterministic mock recognition, Result Editor, rendered preview, and Recent History flow while its process remains alive.
- [ ] An authorized real ScreenCaptureKit smoke run confirms permission handling, coordinate conversion, Retina output dimensions, and ordinary multi-display behavior.
- [ ] A real Datalab run confirms fast recognition, visible progress, editing, the relevant Copy Formats, Failed Record recovery, and balanced retry without exposing the token.
- [ ] Relaunch recovery, individual deletion, clear-all, twenty-record eviction, shortcut conflict, capture cancellation, denial, timeout, and malformed-service behavior remain operable in the candidate.
- [ ] The candidate contains required offline rendering resources, version information, and third-party license notices and makes no remote preview request.
- [ ] Known limitations explicitly retain the Personal MVP boundaries, including no Native Paste guarantee, backend, subscription, App Store release, cloud history, document import, or local Marker fallback.
- [ ] A fourteen-day dogfood checklist is handed to the owner, and the Public Product gate is not claimed until the owner records successful routine replacement of the Mathpix Snip workflow.

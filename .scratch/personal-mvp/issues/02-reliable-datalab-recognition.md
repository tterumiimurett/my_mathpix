# 02 — Make real Datalab recognition reliable and recoverable

**What to build:** The owner can save and validate a Datalab token, send the selected PNG through the current hosted Convert API in fast mode, understand recognition progress, and recover from technical failure. Difficult Snippets can be retried in balanced mode without recapturing or silently losing hand edits.

**Blocked by:** 01 — Make Screen Capture survive through a mock result.

**Status:** claimed

## Suggested agent split

- **Work package A — Credential and API boundary:** cover the sandboxed private token-file lifecycle, authenticated health validation, approved multipart input, trusted asynchronous polling, and secret-safe artifacts. Do not access Keychain.
- **Work package B — Recognition experience:** cover the visible progress state, slow-processing state, timeout, transient retry, Failed Record behavior, cost evidence, and High-Quality Retry.
- The main agent defines the recognition contract before delegation and verifies both packages together through the real Result Editor flow.

## Acceptance criteria

- [ ] The owner can save, replace, validate, and clear the token; it is stored only in a private `0600` file inside the App Sandbox container and never appears in preferences, history, diagnostics, command output, or test artifacts. Existing Keychain items are neither read nor migrated nor deleted.
- [ ] Token validation uses the authenticated health operation without uploading a Snippet or consuming recognition credit, and invalid credentials lead directly to a recoverable Settings path.
- [ ] Fast recognition submits only the selected PNG and approved fields to the current Convert API and requests Markdown plus HTML output.
- [ ] Polling follows only an HTTPS status URL on an approved Datalab host and handles processing, completion, HTTP rejection, malformed response, service failure, cancellation, and a sixty-second timeout.
- [ ] The owner sees ordinary progress during the first five seconds and a distinct slow-processing message afterward; only clearly transient technical failure receives at most one automatic retry.
- [ ] Technical failure retains the original Snippet as a Failed Record that can be retried or copied without recapture.
- [ ] High-Quality Retry reuses the same Snippet in balanced mode and asks before replacing hand-edited content.
- [ ] Available request cost and runtime evidence are recorded separately from recognition content.

## Comments

- 2026-10-21: Fixed the Spec review's lost cost-breakdown regression. Usage Records now retain the complete serialized cost breakdown separately from recognition content, alongside the existing total. A deterministic signed-App regression first failed on missing persisted detail, then passed with nested components and discounts preserved after reload; legacy records without the new optional field remain readable, and deletion/clear-all retain the breakdown. This is automated evidence only; status remains `claimed` and manual/live acceptance is not expanded.

- 2026-09-05 P2 regression fixes: clearing credentials invalidates pending health validation before it can save; recovery Retry asks before replacing retained content after a cancelled balanced attempt; completed attempts retain independent Usage Records even after single deletion or clear-all. Each trigger was reproduced with a failing deterministic public-boundary test and passed after its fix. Signed-App Ticket 02 focused checks and the full 45-check self-test pass. Live credential and GUI acceptance below remain unperformed; status remains `claimed`.

- 2026-09-04 implementation checkpoint: the signed-App deterministic Datalab boundary covers private-file token lifecycle and health validation; fast/balanced multipart requests; trusted polling; processing, completion, rejection, malformed response, service failure, cancellation, timeout, and one-retry behavior; Failed Record recovery; edit-replacement confirmation state; and separate Usage Records. The full repository self-test also passes.
- Blocker: no real Datalab credential was made available, so authenticated health and live Convert submit/poll have not been exercised against the hosted service.
- Blocker: the signed App's real SwiftUI Result Editor flow, including visible progress, Settings recovery, copying the retained Snippet, and the High-Quality Retry confirmation dialog, has not been operated in a GUI session for this ticket. The deterministic signed-App self-test exercises the public model and transport seams but does not claim that human-visible acceptance.
- The ticket therefore remains `claimed`; no acceptance checkbox is marked complete until those live credential and GUI checks are performed.

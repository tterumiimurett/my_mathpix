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

# 02 — Make real Datalab recognition reliable and recoverable

**What to build:** The owner can save and validate a Datalab token, send the selected PNG through the current hosted Convert API in fast mode, understand recognition progress, and recover from technical failure. Difficult Snippets can be retried in balanced mode without recapturing or silently losing hand edits.

**Blocked by:** 01 — Make Screen Capture survive through a mock result.

**Status:** resolved

## Suggested agent split

- **Work package A — Credential and API boundary:** cover the sandboxed private token-file lifecycle, authenticated health validation, approved multipart input, trusted asynchronous polling, and secret-safe artifacts. Do not access Keychain.
- **Work package B — Recognition experience:** cover the visible progress state, slow-processing state, timeout, transient retry, Failed Record behavior, cost evidence, and High-Quality Retry.
- The main agent defines the recognition contract before delegation and verifies both packages together through the real Result Editor flow.

## Acceptance criteria

Accepted using the owner's final tested-build confirmation plus the automated evidence detailed in Answer. Checked items do not imply that every failure path was manually exercised against the live service.

- [x] The owner can save, replace, validate, and clear the token; it is stored only in a private `0600` file inside the App Sandbox container and never appears in preferences, history, diagnostics, command output, or test artifacts. Existing Keychain items are neither read nor migrated nor deleted.
- [x] Token validation uses the authenticated health operation without uploading a Snippet or consuming recognition credit, and invalid credentials lead directly to a recoverable Settings path.
- [x] Fast recognition submits only the selected PNG and approved fields to the current Convert API and requests Markdown plus HTML output.
- [x] Polling follows only an HTTPS status URL on an approved Datalab host and handles processing, completion, HTTP rejection, malformed response, service failure, cancellation, and a sixty-second timeout.
- [x] The owner sees ordinary progress during the first five seconds and a distinct slow-processing message afterward; only clearly transient technical failure receives at most one automatic retry.
- [x] Technical failure retains the original Snippet as a Failed Record that can be retried or copied without recapture.
- [x] High-Quality Retry reuses the same Snippet in balanced mode and asks before replacing hand-edited content.
- [x] Available request cost and runtime evidence are recorded separately from recognition content.

## Comments

- 2026-10-21: At the owner's request, removed the added top linear progress bar and restored the original processing text/spinner presentation. Credential-validation feedback improvements remain in place.

- 2026-10-21 manual feedback: the owner confirmed edit protection, and elected not to manually exercise disconnection this round; disconnection remains covered by automated checks only. The owner observed processing text but wanted a visible progress bar. Invalid replacement credentials correctly preserved the saved credential, but the failure message was not visible. GUI reproduction found the rejection text at y=964 below the Settings window's visible bottom y=667. The repair places credential-test feedback next to the input, adds a failure alert, and adds a top-of-window indeterminate recognition progress bar (the service supplies no completion percentage). These UI changes require a fresh owner check before they count as manual passes.

- 2026-10-21: Fixed the Spec review's lost cost-breakdown regression. Usage Records now retain the complete serialized cost breakdown separately from recognition content, alongside the existing total. A deterministic signed-App regression first failed on missing persisted detail, then passed with nested components and discounts preserved after reload; legacy records without the new optional field remain readable, and deletion/clear-all retain the breakdown. This is automated evidence only; status remains `claimed` and manual/live acceptance is not expanded.

- 2026-09-05 P2 regression fixes: clearing credentials invalidates pending health validation before it can save; recovery Retry asks before replacing retained content after a cancelled balanced attempt; completed attempts retain independent Usage Records even after single deletion or clear-all. Each trigger was reproduced with a failing deterministic public-boundary test and passed after its fix. Signed-App Ticket 02 focused checks and the full 45-check self-test pass. Live credential and GUI acceptance below remain unperformed; status remains `claimed`.

- 2026-09-04 implementation checkpoint: the signed-App deterministic Datalab boundary covers private-file token lifecycle and health validation; fast/balanced multipart requests; trusted polling; processing, completion, rejection, malformed response, service failure, cancellation, timeout, and one-retry behavior; Failed Record recovery; edit-replacement confirmation state; and separate Usage Records. The full repository self-test also passes.
- Blocker: no real Datalab credential was made available, so authenticated health and live Convert submit/poll have not been exercised against the hosted service.
- Blocker: the signed App's real SwiftUI Result Editor flow, including visible progress, Settings recovery, copying the retained Snippet, and the High-Quality Retry confirmation dialog, has not been operated in a GUI session for this ticket. The deterministic signed-App self-test exercises the public model and transport seams but does not claim that human-visible acceptance.
- The ticket therefore remains `claimed`; no acceptance checkbox is marked complete until those live credential and GUI checks are performed.

- 2026-10-21 final feedback: after using the updated independent `my_mathpix_ticket2` build with saved credentials and requesting restoration of the original progress presentation, the owner stated: "OK, 可以. 测试通过". This final acceptance supersedes the historical claimed/blocker disposition above. Evidence limits remain recorded below.

## Answer

Resolved on 2026-10-21 following the owner's final tested-build confirmation for `my_mathpix_ticket2` at implementation commit `5171aca`.

Owner-reported checks include real credential setup, earlier High-Quality Retry producing correct formulas/tables with mode/runtime present, protection of hand edits, and confirmation that the final build passes after restoring the original processing text/spinner. Earlier displayed Fast mode/runtime is supporting UI evidence, not an independently captured live fast submit/poll trace. The invalid replacement kept the saved credential; its initially invisible rejection was reproduced and fixed, with agent GUI replay confirming the new rejection text beside the input. The owner subsequently confirmed credentials were saved and the final build passed.

Supporting automated evidence: the signed-App Ticket 02 deterministic self-test passes; the full repository self-test passes 45 checks; production compilation, signing verification and diff checks pass. Tests cover authenticated health without image submission, private-file credential lifecycle, approved fast/balanced multipart input, trusted polling, errors, cancellation, timeout, one-retry budget, Failed Record recovery, replacement confirmation and independent Usage Record persistence. Focused red-to-green regressions cover clearing during validation, retry after cancellation/edit, deletion during recognition, complete cost breakdown persistence and old record compatibility. Standards/Spec reviews found and drove fixes; the final follow-up fixed renamed main-window lookup. No Keychain access was introduced.

Evidence limits: the owner explicitly declined manual disconnection testing this round. Disconnection, the full slow/60-second timeout matrix, clearing during in-flight validation, and usage retention after deletion rely on automated checks rather than individual owner manual passes. Live billing accuracy and a captured live fast request chain were not independently audited. The final owner confirmation is a tested-build acceptance, not a claim that every checklist scenario was manually performed. The later signed-App integration acceptance gate remains separate; the previously reported TSV conversion problem belongs to Ticket 03.

# MyMathpix Personal MVP

Status: ready-for-agent

## Explicit window-role correction — 2026-10-22

The owner rejected the oversized result in the assembled candidate and clarified the window roles. [Ticket 08](issues/08-window-roles-regression.md) is now the active correction before Ticket 06 can pass:

- Capture completion shows the compact Ticket 03 Result Editor over the current App, at the captured display's visible-area top-left. Its default outer window frame, including the title bar, is 470 points wide and 560 points high, constrained to fit; Original and Edit use the existing internal scroll surface.
- Clicking the MyMathpix menu-bar item opens that same compact result, with the same selected Snippet and edits. A normal sidebar/toolbar workspace is not substituted for it.
- Explicit App activation such as Command-Tab, Dock/reopen or Open MyMathpix shows the large Recent History/settings/Usage workspace. Interacting with the nonactivating compact panel must not open that workspace.
- Capture and recognition still keep content windows hidden until completion. High-Quality Retry in an already open compact result reports progress in its existing footer.
- Production and seeded acceptance launches use the same actual compact surface and presenter. Isolated acceptance scene/restoration state does not change production layout or overwrite normal main-window geometry.

This supersedes the interpretation that merely moving the large workspace to top-left fulfilled the compact-result design. Menu-bar behavior/visibility is explicitly in this correction's scope; its previous waiver is historical, and a real desktop click remains required before claiming it passed. Notion inline math remains deferred. Golden Set recognition/copy quality evidence is unchanged.

## Accepted baseline and remaining scope — 2026-10-21

Tickets 01–04 are resolved by the owner, with their recorded evidence limits and acceptance exceptions. Their Answers and later owner directions supersede the original prototype description and superseded UI requirements below. Remaining delivery work is Ticket 05, followed by Ticket 06. Deferred follow-ups do not silently reopen accepted tickets or count as passed checks.

- The Result Editor is compact and preview-first. Independent Original and Edit actions reveal the aspect-fit Snippet and Canonical Markdown; both may be open alongside the offline preview.
- Exactly three immediate Copy Format rows are visible, in order: **Markdown / Lark / Notion**. Each has a small secondary-color title and a single-line preview; copying writes complete content. Legacy six-format public clipboard seams remain compatibility coverage, not six visible UI actions.
- Markdown copies unchanged Canonical Markdown. Lark copies the complete mixed result with rich tables and literal `$…$` / `$$…$$` formulas. Notion uses the accepted experimental whole-content adapter; display formulas work in the owner's test, but inline formulas can become `Before ‣.`. This unresolved destination defect remains deferred in Ticket 07; serialization alone does not prove editable native equations.
- Pure Formula alone may automatically copy raw Formula Output. Mixed content waits for an explicit copy. Failed Records retain the original-image copy recovery path.
- Recognition uses the accepted status text/spinner presentation. High-Quality Retry preserves the Snippet and asks before overwriting hand edits. Runtime and complete available cost breakdown remain separate Usage Records.
- Ticket 04 menu-bar visibility remains unresolved, including after Hidden Bar was expanded. This is an owner-accepted exception, not a verified menu-bar pass. Normal-window, history, shortcut and captured-display result placement behavior remain required.
- ADR 0006 supersedes the earlier Keychain-storage direction: credentials use only the private sandbox file. Golden Set and acceptance tests use deliberate, non-sensitive fixtures and do not replace or clear the owner's Recent History.

Final acceptance must test this accepted behavior on the assembled signed candidate. Historical six-row screenshots and earlier ticket passes cannot stand in for the final integration journey. No Public Product or completed fourteen-day Dogfood Gate is implied.

## Problem Statement

The owner needs a dependable personal macOS alternative to the Mathpix Snip workflow. A Screen Capture should turn a selected visual region containing formulas, tables, or mixed technical material into editable Canonical Markdown and Formula Output that can be corrected and copied into a Paste Target such as Notion or Feishu.

The repository currently contains a prototype that launches and exposes settings, but it is not a working Personal MVP: attempting a Screen Capture causes the application to terminate. Previous checks verified compilation, bundle structure, settings UI, and isolated transformation behavior, but never exercised the real capture-to-result path. The owner therefore cannot complete the product's core task, and the existing prototype must not be treated as accepted behavior until the full path passes an end-to-end test.

## Solution

Deliver a native macOS Personal MVP whose primary interaction is a global shortcut followed by rectangular Screen Capture. The App uploads only the resulting PNG Upload Payload directly to Datalab's hosted Convert API, tracks the asynchronous Recognition Attempt, presents editable Combined Output beside an offline rendered preview, and offers explicit Copy Formats for reuse.

The first release is optimized for the owner and runs on the owner's current Apple Silicon Mac. At the owner's explicit request, it stores the Datalab credential in a local 0600 file inside the App Sandbox and does not access Keychain, retains only the twenty most recent Snippets locally, exposes a High-Quality Retry, and contains no public-product account, subscription, backend, analytics, or App Store infrastructure.

The implementation is complete only when one highest-level test drives the signed `.app` through real Screen Capture selection with a deterministic mock Datalab response, proves that the process remains alive, and observes the expected result in the Result Editor.

## User Stories

1. As the owner, I want the App to launch without crashing, so that I can begin a recognition workflow.
2. As the owner, I want the App available from both the menu bar and a normal application window, so that frequent capture and detailed editing are both convenient.
3. As the owner, I want a default global shortcut of `Control-Command-M`, so that I can start Screen Capture without changing focus manually.
4. As the owner, I want to customize the shortcut, so that I can avoid conflicts with other applications.
5. As the owner, I want shortcut conflicts reported immediately, so that a failed registration is not silent.
6. As the owner, I want Screen Recording permission explained and requested before capture, so that macOS security requirements do not appear as unexplained failure.
7. As the owner, I want denied Screen Recording permission to produce a recoverable message, so that the App never terminates because permission is missing.
8. As the owner, I want Screen Capture to work across every connected display, so that the location of a formula or table does not matter.
9. As the owner, I want the App's own windows hidden while selecting, so that they do not contaminate the Snippet.
10. As the owner, I want a crosshair and dimmed overlay, so that the selected region is visually unambiguous.
11. As the owner, I want to select a rectangular region by dragging and releasing the pointer, so that capture matches the familiar Snip workflow.
12. As the owner, I want `Escape` to cancel selection without creating a record or error, so that accidental captures are cheap to abandon.
13. As the owner, I want tiny accidental selections rejected safely, so that invalid image dimensions never reach ScreenCaptureKit or Datalab.
14. As the owner, I want the Retina pixels inside the final selection preserved as a PNG, so that small symbols, lines, superscripts, and subscripts remain recognizable.
15. As the owner, I want only the selected pixels uploaded, so that complete screens, window titles, foreground application identity, and surrounding content remain private.
16. As the owner, I want the capture process to stay alive through overlay dismissal and asynchronous image capture, so that completing a selection never terminates the App.
17. As the owner, I want one active Recognition Attempt at a time, so that result ordering, concurrency, and cost remain understandable in the Personal MVP.
18. As the owner, I want an attempt already in progress to block a second capture with a clear message, so that requests are not silently duplicated.
19. As the owner, I want to enter my Datalab token once, so that repeated recognition does not require repeated authentication.
20. As the owner, I want the token stored in a local 0600 file inside the App Sandbox without Keychain access, and never written to preferences, history, or diagnostic output.
21. As the owner, I want token validation to use Datalab's authenticated health endpoint, so that validation does not upload an image or consume recognition credit.
22. As the owner, I want an invalid or expired token to open a direct recovery path to Settings, so that capture failure is actionable.
23. As the owner, I want the first Recognition Attempt to use fast mode, so that a simple Snippet normally becomes usable within five seconds.
24. As the owner, I want the App to submit PNG input to the current Datalab Convert endpoint, so that the implementation does not rely on deprecated Marker, OCR, or table-specific endpoints.
25. As the owner, I want the App to request Markdown and HTML outputs, so that editable source and table-preserving fallback are available from one attempt.
26. As the owner, I want the App to poll the returned trusted Datalab status URL, so that asynchronous processing is represented accurately.
27. As the owner, I want status polling restricted to HTTPS Datalab hosts, so that an unexpected API response cannot redirect my credential to another host.
28. As the owner, I want visible recognition progress for the first five seconds, so that normal latency does not look like a hang.
29. As the owner, I want a distinct slow-processing message after five seconds, so that unusually slow requests remain understandable.
30. As the owner, I want an attempt to fail recoverably after sixty seconds, so that the App does not wait forever.
31. As the owner, I want one automatic retry only for clearly technical transient failure, so that retry behavior does not bias recognition quality or multiply cost unexpectedly.
32. As the owner, I want technical failure to retain the original Snippet as a Failed Record, so that I can retry or copy the image without recapturing.
33. As the owner, I want a High-Quality Retry using balanced mode, so that difficult formulas and tables can trade more time for accuracy.
34. As the owner, I want High-Quality Retry to reuse the same Snippet, so that I do not have to reproduce the selection.
35. As the owner, I want confirmation before a retry replaces hand-edited content, so that corrections are not lost silently.
36. As the owner, I want the API's request cost and runtime recorded, so that future free-allowance and subscription planning can use real evidence.
37. As the owner, I want Datalab output conservatively normalized into Canonical Markdown, so that formatting is stable without a second generative rewrite.
38. As the owner, I want plain text, inline formulas, display formulas, and simple tables represented in one Combined Output, so that mixed Snippets can be reused as a unit.
39. As the owner, I want inline formulas delimited with single dollar signs and display formulas with double dollar signs, so that the output remains KaTeX-compatible.
40. As the owner, I want simple tables represented as GitHub-Flavored Markdown tables, so that their structure remains editable.
41. As the owner, I want Complex Table Output retained as sanitized HTML alongside Markdown, so that merged or otherwise non-rectangular structure is not silently discarded.
42. As the owner, I want the Result Editor to show the original Snippet, editable source, and an offline rendered preview together, so that recognition errors are visible and correctable.
43. As the owner, I want source edits to update the preview, so that I can see the effect before copying.
44. As the owner, I want the preview to render formulas with bundled KaTeX resources, so that recognized content is not transmitted to a renderer or CDN.
45. As the owner, I want raw HTML escaped by default, so that recognized content cannot execute arbitrary markup.
46. As the owner, I want table HTML limited to safe table-related tags and attributes, so that a Complex Table Output cannot execute scripts, frames, events, or remote resources.
47. As the owner, I want a Pure Formula copied automatically as raw LaTeX, so that the fastest common workflow needs no additional click.
48. As the owner, I want automatic formula classification to be conservative, so that mixed content is not copied under the wrong format.
49. As the owner, I want non-formula output to wait for confirmation in the Result Editor, so that tables and mixed content can be checked before copying.
50. As the owner, I want the accepted Markdown, Lark, and Notion actions to copy the complete result in the appropriate representation, while legacy source/table/image clipboard capabilities remain available at their existing public seams and Failed Records retain original-image recovery.
51. As the owner, I want rich-table copy to offer HTML, RTF, TSV, and plain-text clipboard representations, so that target applications can select the format they support.
52. As the owner, I want source copying and the experimental Notion clipboard adapter distinguished from a Native Paste guarantee, with the known Notion inline-equation defect retained explicitly.
53. As the owner, I want the twenty most recent Snippets stored locally, so that accidental window closure does not destroy recent work.
54. As the owner, I want each Recent History entry to contain the original image and final edited output, so that a result can be reviewed and reused later.
55. As the owner, I want editing to autosave the final output, so that correction work survives navigation and relaunch.
56. As the owner, I want the twenty-first record to delete the oldest record and its image, so that history has a predictable bound.
57. As the owner, I want to delete one record or clear all history, so that I control retained local content.
58. As the owner, I want local history to remain inside the App Sandbox container, so that the Personal MVP does not become a cloud document store.
59. As the owner, I want launch-at-login disabled by default but available in Settings, so that the App does not modify login behavior without my choice.
60. As the owner, I want local diagnostic information to exclude credentials, Snippet pixels, and complete output, so that troubleshooting does not create a second content store.
61. As the owner, I want the App to expose its version and bundled third-party licenses, so that the build is auditable.
62. As the owner, I want the Personal MVP tested on my current Apple Silicon macOS system before broader compatibility work, so that implementation effort stays focused.
63. As the owner, I want a Golden Set of real formulas, simple tables, mixed content, and difficult boundary cases, so that recognition quality has a stable reference.
64. As the owner, I want formula results judged by mathematical meaning and layout rather than byte-identical LaTeX, so that equivalent source remains acceptable.
65. As the owner, I want tables judged by rows, columns, cell content, and order, so that structural correctness is explicit.
66. As the owner, I want ordinary Golden Set cases to reach 95 percent overall pass rate with no category below 90 percent, so that completion is measurable.
67. As the owner, I want difficult boundary cases reported separately, so that deliberate stress cases do not indefinitely block the Personal MVP.
68. As the owner, I want to use the finished App for fourteen consecutive days before public-product work, so that daily reliability is demonstrated rather than assumed.
69. As the owner, I want the App to replace Mathpix in my routine Snippet workflow, so that the Dogfood Gate measures real substitution rather than feature count.
70. As the owner, I want the Result Editor window to appear only after recognition finishes and at the top-left visible area of the display where I captured the Snippet, so that the result returns to the screen where I was working without being hidden by the menu bar.

## Implementation Decisions

- Treat the current implementation as a prototype, not an accepted baseline. Preserve useful modules, but revalidate every behavior against this spec.
- Build a native macOS client with Swift and SwiftUI, using AppKit and ScreenCaptureKit at system-integration boundaries. This follows the native-client ADR.
- Keep App Sandbox enabled from the first build. The Personal MVP needs only outbound network access plus the minimum system capabilities required for Screen Capture, local credential storage, login-item management, and deliberate local export.
- Model the primary flow as a single explicit state machine: `idle → selecting → capturing → recognizingFast → complete | failed`; High-Quality Retry moves an existing record to `recognizingBalanced → complete | failed`. Cancellation returns selection to `idle` without creating a record.
- Keep one Recognition Attempt active at a time. Queueing and concurrent recognition are excluded.
- Make overlay and capture lifetimes explicit. Screen selection must carry a stable display identity and selection rectangle into the asynchronous ScreenCaptureKit call; dismissing overlay windows must not invalidate the display or callback state required by capture.
- Convert AppKit bottom-left selection coordinates to ScreenCaptureKit display coordinates in one tested boundary. Account for display origin, per-display scale, Retina output size, and multi-display geometry.
- Reject selections smaller than the defined minimum before creating a ScreenCaptureKit configuration.
- Use Datalab's authenticated health endpoint to validate a token, and store a verified token in a local 0600 file inside the App Sandbox without reading, migrating, or deleting any Keychain item.
- Submit recognition using the current hosted Convert API, multipart PNG input, `fast` or `balanced` mode, and `markdown,html` outputs. Do not integrate the deprecated standalone table-recognition or OCR endpoints.
- Poll only the HTTPS `request_check_url` returned under the Datalab domain. Treat completed failure states, malformed responses, HTTP errors, cancellation, and sixty-second timeout as recoverable failures.
- Do not call a second LLM or generative rewriting pass. Canonical Markdown normalization is deterministic and testable.
- Use GitHub-Flavored Markdown plus KaTeX-compatible formula delimiters as the canonical source contract.
- Render previews entirely offline using bundled KaTeX assets and a non-persistent web view. The generated preview may not contain remote script, stylesheet, font, frame, image, or navigation resources.
- Sanitize or regenerate table HTML before preview or rich-copy use. Raw service HTML does not enter an executable web context unchanged.
- Present one Result Editor with original image, editable Canonical Markdown, and rendered preview. Do not create a block editor or word processor.
- Preserve the captured display identity through recognition. Keep App windows hidden after a successful Screen Capture while recognition is active, then present the result or recoverable failure at a small inset from that display's top-left `visibleFrame`; use a remaining display only if the captured display disappears before presentation.
- Define Pure Formula conservatively. Only one formula plus whitespace qualifies for automatic raw-LaTeX copy.
- Write the accepted Markdown / Lark / Notion Copy Formats to the macOS pasteboard. The Notion adapter is an owner-authorized experimental exception to the original source-only scope, with no document API, authentication, browser injection, or general Native Paste guarantee. Its deferred inline-equation defect remains open.
- Store Recent History as an index plus image artifacts inside the App Sandbox container. Persist only the twenty newest records and delete the evicted image in the same operation.
- Store usage counts and available Datalab cost information separately from recognition content.
- Keep diagnostic events local and content-free. No third-party analytics or automatic log upload is included.
- Assemble a signed local `.app` with the provided build workflow. App Store distribution signing is not part of this spec.
- Existing direct Datalab access is deliberately personal-only. A distributed Public Product must replace it with a controlled backend, but that migration is outside this spec.

## Testing Decisions

- The primary and authoritative test seam is one end-to-end signed-App flow. Launch the real `.app`, invoke the configured capture shortcut, drag a known rectangle over a fixture displayed on screen, feed the produced PNG into a deterministic mock of the Datalab submit-and-poll protocol, and assert all of the following externally visible behavior: the App process remains alive; selection closes; one Recognition Attempt is created; progress is shown; the mock completion is consumed; the Result Editor opens; the original image, expected Canonical Markdown, and rendered formula/table preview are visible; and the record is present in Recent History.
- The primary seam must go red when the reported regression occurs: if completing Screen Capture terminates the process, the test fails specifically on process death before recognition submission. Merely proving that the App launches is insufficient.
- Run the primary seam against the same assembled, sandboxed, ad-hoc-signed bundle used for Personal MVP handoff. Testing only an unrestricted executable is insufficient.
- Provide deterministic injection points for capture output and Datalab transport only where required by the highest seam. Avoid a wide collection of low-level protocols that expose implementation details.
- Include a real ScreenCaptureKit smoke variant on an authorized Mac to validate permissions, coordinate conversion, Retina image dimensions, and multi-display behavior. It may use a mock Datalab response so it does not expose a token or incur cost.
- Exercise permission states externally: not determined, denied, granted, and revoked after prior grant. None may terminate the process.
- Exercise capture cancellation, too-small selection, display disappearance, and capture API error. Each returns to an operable state.
- Exercise Datalab submit success, processing polls, completion, HTTP rejection, malformed check URL, service failure, timeout, and cancellation through a mock URL protocol or equivalent transport boundary.
- Assert through the signed-App capture seam that the normal window is not visible while recognition is active, and that the completed Result Editor window is shown on the captured display at the top-left of its visible area.
- Assert that multipart requests contain only the selected PNG and approved fields, and never include window titles, active application identity, history, or credentials outside the authentication header.
- Retain deterministic checks for Canonical Markdown normalization, conservative Pure Formula classification, Markdown-table-to-TSV conversion, safe rich-table generation, raw-HTML escaping, and offline-preview resource isolation.
- Test Recent History through externally meaningful persistence behavior: creation, edit autosave, failed-record retention, retry update, relaunch recovery, single deletion, clear-all, twenty-record eviction, and image deletion.
- Test sandboxed local-token behavior through save, replace, read, file-permission, and clear operations without printing the token. Redact credentials and authentication headers in every captured artifact.
- Test copy behavior by reading the pasteboard types and values produced for each Copy Format, not by calling private helpers.
- Build the initial Golden Set with thirty Pure Formula cases, twenty simple tables, twenty mixed-content cases, and ten separately reported difficult cases. Mathpix output may be stored as a comparison, but Golden Result remains the reviewed truth.
- A good test asserts user-observable behavior or a stable external contract. Tests must not assert private method calls, internal type layout, polling implementation details, or the exact source-string form of mathematically equivalent LaTeX.
- The current `--self-test` mechanism is prior art only for deterministic transformation and history checks. It is supporting coverage and cannot satisfy the primary acceptance seam.
- The feature is complete only after the primary seam first reproduces the screenshot termination on the current prototype, then passes after the fix, and all supporting checks and release-bundle verification pass.

## Out of Scope

- Public App Store release, TestFlight operations, notarized direct distribution, or production signing.
- A user account system, Sign in with Apple, backend proxy, free-allowance enforcement, StoreKit subscriptions, subscription restoration, or public-product abuse controls.
- Public-product privacy policy, DPA, deletion-request workflow, data-residency decisions, or Datalab OEM/resale agreement execution.
- iPhone, iPad, Windows, web, Intel Mac, or older macOS compatibility work.
- Local or offline Marker model deployment and automatic fallback from Datalab to Marker.
- PDF, Office document, EPUB, or full-page import; the Personal MVP begins with Screen Capture Snippets.
- General Native Paste integrations, target-application authentication, accessibility automation, or document API writes. The accepted experimental Notion clipboard adapter is the narrow exception recorded above; repairing its deferred inline issue is outside the remaining Ticket 05/06 work.
- Cloud history, iCloud synchronization, full history search, favorites, folders, collaboration, or document-library behavior.
- A visual block editor, Word-like editing, layout reconstruction, free-form canvas, or pixel-perfect source-image reproduction.
- Deprecated Datalab OCR or standalone table-recognition endpoints.
- Multiple simultaneous Recognition Attempts or a background job queue.
- Exact subscription price, free quota size, public fair-use policy, international storefronts, localization, branding, and final product name.

## Further Notes

- The immediate known defect is process termination when Screen Capture is attempted. The spec intentionally records no unverified cause; implementation begins by making the primary seam reproduce the exact symptom and capturing a redacted crash artifact.
- The current machine has Apple Silicon and macOS 15.7.3. It has standalone Command Line Tools but not full Xcode or an App Store signing identity. Local SwiftPM builds are possible with the compatible installed SDK; standard XCTest availability must be revisited after installing full Xcode.
- The Datalab token is sensitive. It must never appear in issue text, command output, fixtures, logs, screenshots, or crash artifacts.
- The bundled KaTeX assets require their MIT license notice to remain in distributed bundles.
- Public Product decisions already recorded in the glossary and ADRs are parked. They constrain future work but do not expand this Personal MVP spec.

## Comments

- 2026-08-25: Synthesized from the completed grill-with-docs session and the observed screenshot-termination report. Published with `ready-for-agent` status.

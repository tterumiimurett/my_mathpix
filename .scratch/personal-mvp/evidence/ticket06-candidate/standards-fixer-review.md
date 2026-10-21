# Standards fixer — independently reviewed, replacement sealed, actual GUI/live pending

Base integration: `7062cc8440adad7d402b12c9177f87869375016e`. Scope is the three P3 Standards recommendations plus the necessary narrow source-bridge update. The two Spec gates remain external: human unlock and actual granted shortcut/capture/live GUI acceptance. Ticket06 stays claimed/pending; ungranted preflight is not a verified denied/revoked scenario.

Parent and both independent reviewers approved `b667026`; the three Standards findings are closed and no new Standards/Spec issue was found. Parent then explicitly authorized rebuilding/resealing. The replacement candidate now passes all eight signed supporting checks, strict UUID, the exact pinned source bridge and existing signed Golden preview self-test. Its post-preview immutable audit matches. See `handoff.md` and `../final-review-preflight.md`; original external Spec gates remain open.

## Reviewed changes

1. `report.py` owns `required_checks(case)`; both report evaluation and pending-review generation use it. Boundary tables still require `table_structure` in addition to the unchanged category checks.
2. The existing fixed Golden runner uses a private bounded AttemptRecord with typed recognition outcome and consumption states. Public dictionaries are emitted only at the existing result JSON boundary; rawMarkdown/rawHTML/rawOutputSHA256, canonical/safe output, cost/runtime/retry/wall fields and absent-versus-null/error semantics remain. The service result is still written before preview/clipboard consumption, so resumed runs cannot spend again. No generic JSON abstraction, test-only helper protocol, CLI, service retry or quality policy was added.
3. The existing navigation delegate success/failure callbacks share one private completion helper for invalidating the timer, resuming the continuation and clearing it. Rendering/viewport/snapshot behavior is unchanged.

## Existing public checks and limits

- Five public Golden report unit tests pass before/after.
- Re-generated baseline-v2 report is byte-identical before/after: fast69/70 ordinary+9/10 boundary; balanced69/70+8/10. The 160-record pending-review template is also byte-identical. These are local report checks of immutable existing outputs, not new service attempts or new semantic reviews.
- Existing full debug self-test passes (48 checks plus Ticket04 workflow checks).
- Existing public local `--golden-set-preview-self-test` passes on the isolated debug executable: height1776, footerRows48. It uses only a local offscreen WebKit fixture; no Screen Capture, credential access or API request. This does not exercise real service-result serialization or claim actual GUI capture.
- Public source-bridge CLI rejects a future runner edit, an ordinary renderer edit and a wrong baseline runner hash in disposable fixture Git repositories, before any artifact/report can be accepted. No private mirrored-method test was added.
- During source-only fixing, the old pre-review App read-only manifest verification passed with SHA256 `49e4b18832715738628b22d0f94fcdb3096067f8e88a4ba391e651fb99510b65` / CDHash `74fa9e3c9a63c6c8ec51f5b0390ce58fd3624a4f`. No release rebuild/re-sign/stable-dist overwrite occurred during that source-only check; the later parent-authorized replacement seal is recorded below. No CUA/TCC change or live API request occurred.
- Result JSON preservation is source-reviewed at the bounded serializer; a new live Golden run is deliberately not performed. Immutable baseline-v1/v2 results, reviews, previews, configuration and provenance remain untouched.

## Approved bridge, executed for the replacement seal

The nine acceptance-only host differences remain in their original separate list. Ordinary recognition, normalization, rendering, table/clipboard, history/usage and resource inputs remain byte-for-byte protected. GoldenSetRunner is not described as unchanged: a separate exact pair pins baseline file SHA256 `3ebc2b386f987f594b34aef02ec91830d369be2baf7dde7f2faaebcf0113980b` to refactor file SHA256 `150517e9ab4a650ccbdf1d06368960273d1465339aa12ef1ef8611b04db89185`. Missing source/baseline runner or any later runner change fails closed and requires review.

Executed source-bridge schema2 reports ordinaryCoreInputsUnchanged=true, qualityPipelineInputsUnchanged=false, and lists reviewedGoldenRunnerRefactor separately from acceptanceOnlyChanges. No new-source bridge was generated against the old binary. The old full bundle and original evidence are archived under the documented backup/pre-review locations. After parent approval, a new clean-source release from `b667026f27e3e01d6d56b838480ac62aafb0b3b9` was completely staged, sealed and support-checked; its exact source bridge is now recorded. New executable SHA256 `ea7ad5f183af7c18fa72fc6a20b59f851662f874e2c0a32912632de363b869dd`, CDHash `d778b73b6a491c382cb56abeab19c2fcd7e96501`. All subsequent updates are documentation/data only; source/sign/bundle stay frozen. The new parent permission probe is ungranted without asserting denied/revoked behavior.

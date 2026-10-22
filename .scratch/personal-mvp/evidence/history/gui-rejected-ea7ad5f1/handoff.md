# Ticket06 reviewed fixed candidate — code/audit ready, actual UI/live pending

Frozen App: `/Users/bytedance/.codex/worktrees/personal-mvp-integration/my_mathpix/dist/MyMathpix.app`. Version0.1.0 (1), arm64, macOS15.7.3. Reviewed builder/source `b667026f27e3e01d6d56b838480ac62aafb0b3b9`. Parent and both independent reviewers approved the bounded Standards fixes before this replacement build.

Executable SHA256 `ea7ad5f183af7c18fa72fc6a20b59f851662f874e2c0a32912632de363b869dd`. CDHash `d778b73b6a491c382cb56abeab19c2fcd7e96501`. Bundle-tree SHA256 `068a8f2aa3b409694154e8510ada1ac136a298120236849c9ca495c5a5e159fd`. The complete signed bundle was staged before sealing. No source/build/sign/bundle changes followed the seal.

## Supporting evidence

- [Same-candidate eight signed CLI checks](supporting-checks.json): ad-hoc signature, sandbox/network/user-selected export, version, required offline CSS/JS/font/license hashes and deterministic contracts passed. The whole bundle and executable remained unchanged after each check.
- Offline preview policy remains protected byte-for-byte with the renderer/resources: restrictive local document CSP, bundled renderer/fonts, no remote connection source, and sanitized table fallback. The signed resource/local-preview checks support this criterion without claiming a real capture journey.
- [Strict UUID launch contract](launch-contract.json): eight malformed/duplicate/unknown/conflicting invocations fail closed on this exact signed executable.
- [Existing signed Golden preview self-test](preview-self-test.json): height1776/footerRows48; [actual local fixture PNG](preview-self-test.png). Parent visually inspected the actual PNG and confirmed the END footer is complete; footerRows48 counts black pixel rows. This is an offscreen local WebKit fixture, not Screen Capture or live recognition.
- [Post-preview immutable verification](immutability-after-preview.json): executable/CDHash/bundle tree still match the same sealed manifest.
- [Source bridge schema2](source-bridge.json): 159 ordinary recognition/normalization/rendering/table/clipboard/history/usage/resource inputs match baseline-v2 byte-for-byte. One Golden runner record/teardown refactor is a separate exact baseline-to-reviewed-file-hash exception; nine acceptance host differences remain separate. The whole old quality pipeline is explicitly **not** described as unchanged. No new paid Golden run or binary-equivalence claim follows.
- [New exact-candidate permission probe](permission-probe.json): parent independently verified this new SHA/CDHash and read-only preflight is ungranted. This does not establish denial/revocation behavior.
- [Desktop gate](desktop-gate.json): Read-only inventory reported the Mac locked and automatic unlock failed; no manual unlock, UI interaction, screenshot or TCC change was performed.
- [Parallel Standards / Spec preflight review](../final-review-preflight.md): three Standards findings fixed, zero open; two required actual capture/live acceptance groups remain open. This is not an all-Spec pass.

Actual shortcut/selection, granted ScreenCaptureKit/Retina/multi-display flow, rendered Original/Edit/result and Recent History/process survival, initial+edited copy rows, real fast/balanced progress/recovery and destructive/cancellation/permission UI observations remain pending parent CUA work after human unlock and action-time Screen Recording authorization. The first four Ticket06 criteria stay unchecked; the ticket remains claimed. No actual live service request was made during this reseal.

## Superseded candidate

The complete old App is preserved at `/private/tmp/my_mathpix-remaining-context/artifacts/MyMathpixCandidatePreReview.app`; its signature and full manifest match were verified. Do not launch it for current acceptance. Original [old manifest/bridge/permission/handoff bytes](pre-review/README.md) are retained under pre-review. Their old SHA49e4b188/CDHash74fa9e3 observations are historical; the new permission probe above is separately bound to the replacement.

## Parent-only disposable launches

These new UUIDs have not been launched. Do not execute the commands until unlock and action-time authorization. Reuse a UUID only to relaunch its own disposable history/usage/defaults; the normal credential store is neither copied nor migrated.

### live

```sh
open -n /Users/bytedance/.codex/worktrees/personal-mvp-integration/my_mathpix/dist/MyMathpix.app --args --ticket06-acceptance=f49432fb-2568-4b1b-9d3f-6fa57be88cba --ticket06-service=live
```

Root `/Users/bytedance/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket06Acceptance/f49432fb-2568-4b1b-9d3f-6fa57be88cba`; scalar report `/Users/bytedance/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket06Acceptance/f49432fb-2568-4b1b-9d3f-6fa57be88cba/session.json`; history `/Users/bytedance/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket06Acceptance/f49432fb-2568-4b1b-9d3f-6fa57be88cba/History/history.json`; independent ledger `/Users/bytedance/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket06Acceptance/f49432fb-2568-4b1b-9d3f-6fa57be88cba/Usage/usage-records.json`.

### failure

```sh
open -n /Users/bytedance/.codex/worktrees/personal-mvp-integration/my_mathpix/dist/MyMathpix.app --args --ticket06-acceptance=860e388d-df2f-4fa1-86bd-5be30ef0a59a --ticket06-service=failure
```

Root `/Users/bytedance/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket06Acceptance/860e388d-df2f-4fa1-86bd-5be30ef0a59a`; scalar report `/Users/bytedance/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket06Acceptance/860e388d-df2f-4fa1-86bd-5be30ef0a59a/session.json`; history `/Users/bytedance/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket06Acceptance/860e388d-df2f-4fa1-86bd-5be30ef0a59a/History/history.json`; independent ledger `/Users/bytedance/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket06Acceptance/860e388d-df2f-4fa1-86bd-5be30ef0a59a/Usage/usage-records.json`.

### timeout

```sh
open -n /Users/bytedance/.codex/worktrees/personal-mvp-integration/my_mathpix/dist/MyMathpix.app --args --ticket06-acceptance=06e7cf6d-65d7-42b0-a166-b04177661801 --ticket06-service=timeout
```

Root `/Users/bytedance/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket06Acceptance/06e7cf6d-65d7-42b0-a166-b04177661801`; scalar report `/Users/bytedance/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket06Acceptance/06e7cf6d-65d7-42b0-a166-b04177661801/session.json`; history `/Users/bytedance/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket06Acceptance/06e7cf6d-65d7-42b0-a166-b04177661801/History/history.json`; independent ledger `/Users/bytedance/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket06Acceptance/06e7cf6d-65d7-42b0-a166-b04177661801/Usage/usage-records.json`.

### malformed

```sh
open -n /Users/bytedance/.codex/worktrees/personal-mvp-integration/my_mathpix/dist/MyMathpix.app --args --ticket06-acceptance=0326ba1f-0b04-4be8-a2a9-9fce5a433a05 --ticket06-service=malformed
```

Root `/Users/bytedance/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket06Acceptance/0326ba1f-0b04-4be8-a2a9-9fce5a433a05`; scalar report `/Users/bytedance/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket06Acceptance/0326ba1f-0b04-4be8-a2a9-9fce5a433a05/session.json`; history `/Users/bytedance/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket06Acceptance/0326ba1f-0b04-4be8-a2a9-9fce5a433a05/History/history.json`; independent ledger `/Users/bytedance/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket06Acceptance/0326ba1f-0b04-4be8-a2a9-9fce5a433a05/Usage/usage-records.json`.

For Failed Record recovery, quit the failure session, then relaunch its same UUID with service=live and Retry the retained captured original. The live factory passes the existing LiveRecognitionService as both service and credential configuration. Do not change/clear credentials when testing disposable history. Fault modes make no live requests; timeout uses a disclosed seven-second test deadline and malformed supplies malformed polling JSON. Normal live timeout is unchanged. Reuse the live UUID after quitting to inspect corrected source/image persistence. Delete/clear only this deliberate fixture history; observe Usage Records independently. Twenty-record eviction is covered by the signed deterministic public self-test, not claimed as a manual GUI action.

For the primary deterministic capture journey, run the merged integration Ticket01 acceptance script with `MYMATHPIX_ACCEPTANCE_APP=APP`. Approved processing stays hidden: observe redacted evidence phase recognizing, invoke the second shortcut before completion, and leave its raw Recognizing visibility truthful. Observe final Original/Edit/preview/history and process survival, then verify; use secondary-display launch/verify for actual multi-display evidence. Last hardware geometry: primary(0,0,1280,720), secondary(1280,0,1312,848), bothscale2; re-observe actual geometry when CUA is allowed.

For Ticket03, use the same APP override. Click Markdown/Lark/Notion and immediately inspect-copy FORMAT initial; open Original/Edit and enter the declared edited fixture, then click each row and inspect-copy FORMAT edited. Retain all six external stage-labeled observations. Full source/table/order/formula serialization checks do not prove destination Native Paste. Demonstrate visible real progress separately with the result window already open during balanced retry.

After the actual journeys, run only `scripts/acceptance/candidate_checks.py APP --verify-manifest .scratch/personal-mvp/evidence/ticket06-candidate/supporting-checks.json` for artifact continuity. Do not use rebuilding scripts on this candidate.

## Limits and fourteen-day handoff

Golden gate remains69/70 ordinary per mode (formula30/30, table20/20, mixed19/20); boundaries fast9/10, balanced8/10. Retain M15 blockquote flattening, B06 currency/formula ambiguity, B08 balanced extra-header/fallback, deferred Notion inline paste and menu-bar visibility. Provider reuse was inferred in v2; no universal cold fast latency or Native Paste guarantee follows. Personal MVP excludes backend/accounts/subscription, cloud history, document import, App Store release and local Marker fallback.

The candidate-bound [fourteen-day checklist](../../dogfood-checklist.md) is handed over with all14 daily rows blank. Start date and actual UI/live acceptance remain pending. Supporting resources/offline/limitations/handoff criteria are recorded as satisfied with the above scoped evidence; routine replacement and Public Product approval remain the owner's future gate.

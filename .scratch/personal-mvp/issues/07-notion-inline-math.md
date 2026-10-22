# 07 — Fix Notion inline math paste

**Status:** resolved

**Blocked by:** None. Ticket 10 restored a consistent installed runtime and screenshot permission.

## Problem

Notion Copy Format does not reliably create an editable inline equation. With a source paragraph `Before $x^2$.`, the owner observed `Before ‣.` after ordinary paste into Notion. The formula is not rendered as intended. This is a confirmed unresolved destination behavior; do not assume the precise cause is known merely because the serialized native payload contains an equation annotation.

The owner reports Notion display formulas and the Markdown workflow work, and accepted the three-format Markdown / Lark / Notion Ticket 03 candidate at `ec7e140`. The owner explicitly deferred this inline defect for later investigation. Closing Ticket 03 does not close this issue.

## Intended outcome

Find a viable way for inline math to paste into Notion as a correctly rendered, editable equation while preserving the surrounding text and table content. Preserve the accepted Markdown and Lark outputs and working Notion display-math behavior. Do not silently replace formulas with an image, drop formula content, or claim success from local serialization alone.

## Acceptance criteria

- [x] Reproduce the actual `Before ‣.` failure in a recorded Notion desktop or browser version, with a minimal non-sensitive fixture.
- [x] Establish regression coverage through the public clipboard boundary and a real Notion destination paste; the tests must distinguish an editable equation from a placeholder, literal source, or static image.
- [x] Confirm inline formulas in mixed text retain formula content and surrounding text; cover code/currency that must not become equations and inline formulas in tables when supported.
- [x] Confirm existing Markdown, Lark, display formulas, rich tables, and offline/security contracts do not regress.
- [x] Document target-version limitations and the supported transfer mechanism. Notion's undocumented v3 clipboard or local virtual-clipboard behavior must not be treated as a supported public API.

## Scope and safety

The owner authorized investigation and synthetic writes only in the private
`MyMathpix inline math test` page. Work must not read credentials or unrelated clipboard content, mutate a user's Notion documents through APIs, add authentication, or inject into the browser without separately established scope/authorization. Use explicit test fixtures and preserve the accepted three-row compact UI.

## Context

- [Ticket 03 resolution](03-edit-preview-copy.md#answer)
- [Accepted three-format evidence and known issue](../evidence/ticket03-lark-copy-2026-10-21.md)
- Current adapter: `Sources/MyMathpix/NotionClipboardDocument.swift`; native inline decoration and `org.chromium.web-custom-data` output already exist. Their presence did not establish destination compatibility.

## Comments

2026-10-22 — Scoped AppKit inspection of the agent-copied NREF fixture succeeded
without owner export, after sandbox access was resolved through approved
escalation. Native equation runs use U+204D `⁍`; the App uses U+2023 `‣`.
Native dragged-selection MIME/envelopes also differ. Agent then wrote the
unchanged production single-formula fixture and ordinary paste reproduced
exactly `Before ‣.` in Notion Desktop 7.40.0. Only-marker-change candidates are
prepared, preserving the HTML/table/source bytes. Destination green verification
is pending because desktop input began returning `noWindowsAvailable`; owner
was asked to foreground/click the test page, not rerun all cases. No production
fix or rich-table acceptance is claimed. The original reproduction criterion
now has controlled destination evidence in the experiment record.

2026-10-22 — Agent completed the Notion-to-Notion NREF copy/paste reference
without owner assistance: five selected native blocks, four equations, bold
text and the table survived one ordinary copy/paste. Opened the new copy's
fraction cell and verified native editable LaTeX `\frac{1}{2}`. This separates
native mixed-content clipboard capability from the failing external adapter;
raw clipboard schema and complex-table fidelity remain unverified. See the
agent-run round-trip section in the experiment evidence. No production fix.

2026-10-22 — Owner clarifies that all formulas fail to render in 10–12 and
asks whether rich tables and formulas are inherently incompatible. This does
not establish that conclusion. P5 already demonstrated native table equations,
including editing after reload. Official table rows contain rich-text cells,
and rich text explicitly supports equations. Those facts establish native
table/equation coexistence, not arbitrary HTML rich-table import fidelity or a
working external clipboard protocol. Table structural fidelity in 10–12 remains
separate from the confirmed formula failures.

2026-10-22 — Owner reports **all of 10, 11 and 12 fail**. This closes the
pending owner comparison for those rich-table integration candidates with a
failing result; do not promote any of them to a production fix. The failure
classification (formula-only versus table/content damage) has been requested
and is not inferred. No native NREF clipboard capture has been received yet.

2026-10-22 — Owner reports fixture buttons 2/3/5/6/8/9 work and requested
removing escaped-currency backslashes in 9 (fixture updated). Owner identified
the missing full rich-table-plus-formula case. Added 10–12 with identical mixed
input through unchanged production renderer/adapter sources: two rich HTML
tables, complex caption/spans/literal content, seven inline formulas and one
display formula. The case-11 HTML-only native CUA destination probe preserved
the observed table contents but left every formula literal. No rich-table/math
integration pass or App fix is asserted. See the latest experiment evidence.

2026-10-22 — Owner correction: Notion tables cannot be fully represented by the
Markdown path; this limitation was established in earlier acceptance. Rich-table
behavior is a required part of the existing Notion Copy Format. A simple GFM
table paste passing does not justify replacing the Notion adapter with plain
Markdown, treating the Lark rich-table representation as universally compatible,
or declaring mixed-content acceptance. Continue with a native mixed-content
clipboard reference and test formulas plus the already accepted rich-table
fixtures together. Plain Markdown remains a diagnostic control only until a
transfer policy preserves the accepted rich-table behavior.

2026-10-22 — Owner authorized a bounded clipboard compatibility experiment and
confirmed single-line plain Markdown / literal-math HTML fixture buttons 2/3
work. Owner specifically requested multiple-block checks. On Notion Desktop
7.40.0, a single plain-Markdown paste created distinct paragraphs and rendered
five inline equations; a second plain-Markdown fixture created native paragraph /
simple-table / paragraph blocks with rendered equations, including editable table
math that survived reload. The HTML/table counterpart retained all formulas as
literal source. HTML-only multiline paste became one block and does not count
as a true multi-block pass. Code/currency checks and remaining fidelity limits
are recorded in [experiment evidence](../research/notion-inline-math-experiment/README.md#multi-block-destination-checks--2026-10-22).
The production adapter is unchanged; this does not resolve Issue 07 or establish
the precise cause of the historical placeholder defect. Ticket 09 remains
scheduled after this issue as requested by the owner.

2026-10-22 — Marker-only destination control is green on Notion Desktop 7.40.0:
`Before x².` renders and opens native editable `x^2`, while the original fixture
still yields `Before ‣.`. Rich marker-only paste renders paragraph/GFM-table
formulas but leaves complex-cell `<math>` source literal and misparses prices.
A scoped production candidate now addresses those two boundaries as well;
new public clipboard tests were red before the fix and Ticket 03 is green
afterward. Actual candidate-generated `rich-mixed-fixed.json` is on the
clipboard, awaiting one owner paste because desktop clicks again fail with
`noWindowsAvailable`. Full rich destination acceptance remains pending; no
installed-App replacement, merge, release or Ticket 09 repair.


## Candidate result — reopened after owner test

The fixture-only result below does not close the actual signed-App copy flow.

Candidate on `codex/notion-inline-math-fix` with controlled red/green evidence
and an actual Notion Desktop 7.40.0 destination pass. The original `Before ‣.`
reproduction becomes an editable native `x^2` when U+2023 is corrected to
U+204D. The complete production candidate also preserves explicit complex-cell
math metadata and avoids interpreting adjacent prices as equations.

The owner pasted the final full synthetic candidate once. Agent inspection
verified all seven inline equations, the display block, both tables, code,
prices, Unicode, caption and projected columns. Agent changed the complex-table
fraction to `2/3`, reloaded Notion, reopened the saved native LaTeX `\frac{2}{3}`,
and restored `1/2`. Existing merged cells still project into occupied native
grid slots; true Notion merged cells are not claimed. Clipboard HTML retains
the original sanitized spans. The undocumented offline v3 adapter is verified
on this target version, not guaranteed across all Notion versions.

Validation: focused Ticket 03 regression passed; basic 48-check suite plus
Ticket 04 workflow checks passed; release candidate built and signature verified.
See [destination evidence and limitations](../research/notion-inline-math-experiment/destination-verification.md)
and [full research sequence](../research/notion-inline-math-experiment/README.md).

Candidate: `dist/MyMathpix.app`. It retains the normal application name,
bundle identifier and sandbox entitlements. It has not replaced the installed
V1; normal signed-App UI Copy has not separately been driven. No merge or
GitHub release occurred. The result-editor caret defect remains a separate
Ticket 09 follow-up and was not changed here.


2026-10-22 — Reopened after owner reports that ordinary Notion Copy Format
paste still fails, whereas Markdown copy renders some formulas with incomplete
Notion compatibility. The earlier candidate destination test exercised an
exported adapter fixture, not the normal signed-App Copy click. It was wrong
to treat that as full workflow acceptance. Preserve that scoped evidence, but
require an actual running-version check and the normal App copy-to-Notion path
before closure. No production-format changes in this renewed diagnosis yet.
Ticket 09 remains deferred until this workflow is handled.

2026-10-22 — Current App normal-copy probe used the actual Notion button on
the selected synthetic RICH result. The guarded native clipboard inspection
found three U+204D equations and no U+2023. By the time of actual Notion paste,
a second guarded inspection found unchanged plain source but a different
native/HTML payload: four U+2023 markers, no U+204D. Therefore this paste is
not a valid current-candidate acceptance or a controlled identical-payload
failure. System Settings Quit and Reopen was independently observed launching
old installed V1 despite selecting the dist candidate. Ticket 10 tracks this
runtime/authorization ambiguity. Keep 07 open; do not attribute the result to
rich-table incompatibility or claim the current candidate is accepted. No
further format/source changes were made in this renewed diagnosis.

2026-10-22 — Ticket 10 is resolved for the frozen installed candidate. Actual
screen selection opens/cancels after exact-path permission re-registration.
The renewed offline normal-model regression now reproduces a second real
boundary: `AppModel.complete` persisted sanitized plain HTML, losing explicit
complex-cell math before reload/copy. New source changes preserve inert math
provenance in storage, keeping display HTML/TSV unchanged. A fully isolated
recognition → disk history → reloaded model → normal copy test was red then
green; legacy whole-cell recovery is constrained by Canonical Table Output.
An additional code/formula ambiguity case is being tightened before building.
Installed artifact is not yet changed to these subsequent source fixes.


## Answer — Owner accepted installed workflow (2026-10-22)

Owner: “notion 这里修好了. 没问题, markdown 也没问题.” This supersedes
the reopened destination status above. The installed executable is
`abb2215a470f97c93e65f90b87643cddb59df7659c6d61d0bd88bce9a28cd1c3` at
`/Applications/MyMathpix.app`; main and the public V1 release remain unchanged.

The final source uses U+204D native equation runs, persists inert explicit math
markers through History reload, conservatively recovers corroborated legacy
whole-cell formulas, and shares table placement with preview/Lark (Ticket 11).
The real installed App preview shows one RICH table and rendered cell equations.
Offline tests additionally cover recognition → disk → reload → public AppModel
copy, code/currency ambiguity and old records. Owner acceptance is separate
from the earlier exported-fixture counts and edit/reload experiment. Native
merged cells remain projected into occupied slots; v3 clipboard compatibility
is target-version dependent. Lark formula rendering remains a separate active
follow-up; Ticket 09 remains deferred until the paste work is closed.

# Bounded Notion clipboard experiment

Date: 2026-10-22. Notion Desktop: **7.40.0 (7.40.0)**.
Target: owner-created private page `MyMathpix inline math test`.

The installed MyMathpix App, its signature, credentials, history and production
source are unchanged. This directory contains disposable fixture tooling only.

## Fixtures

`GenerateFixture.swift` compiles with the production adapter and renderer sources
unchanged, using a resource-directory shim and an error-enum shim. It exports
representations without accessing any pasteboard. `baseline.json` contains only
`Before $x^2$.` and generated UUIDs. `index.html` uses actual browser copy events
to compare the full web clipboard payload, plain Markdown, literal-math HTML,
and MathML HTML without the native v3 payload. It does not read clipboard data,
make network requests, or operate a Notion page.

The browser copy path is equivalent to a browser `DataTransfer` MIME write, not
an independent test of the native AppKit UTI registration. Do not equate either
with a destination pass until real paste is observed.

## Observations so far

| Probe | Notion Desktop result | Editable native equation? |
| --- | --- | --- |
| A: plain `Before $x^2$.` | rendered inline x squared | Yes: clicked it, saw Equation (LaTeX) value `x^2`, changed to `x^3`, confirmed visible x cubed |
| B: plain `Before $$x^2$$.` | rendered inline x squared | Not yet individually inspected |
| C: HTML containing literal `Before $x^2$.` | rendered inline x squared | Not yet individually inspected |
| D: simple KaTeX/MathML HTML | visible `Before x2x^2.` | No native equation exposed in the accessibility tree |
| E: exact production-generated HTML for this formula | visible `Before x2x^2.` | No native equation exposed in the accessibility tree |

All probes used native CUA `paste` with an explicit `text` or `html` format and
read the resulting target accessibility tree. The tool documents macOS paste as
a temporary system pasteboard write plus paste, restoring the previous clipboard.
These probes do not include the App's native custom clipboard representation.
The historical exact `Before ‣.` symptom has **not** yet been reproduced in a
controlled probe with a known clipboard representation.

During the owner's subsequent manual activity, the test page gained two lines
containing `C — HTML with literal math: Before  ‣ .`, alongside rendered native
equation copies. The input operation and clipboard representation for those
lines have not been confirmed by the owner, so this observation is not a
controlled reproduction and does not establish the cause. Automation stopped
input after the tool reported an owner change to the App.

The first native-app inspection unexpectedly encountered an unrelated existing
page. Its contents were not copied into evidence. Automatic approval rejected
a subsequent screenshot; the owner then opened a private blank test page.
All subsequent page output was limited to that test page's accessibility subtree.
Browser automation also rejected opening the local fixture file under its URL
policy; no alternate transport or browser surface was used to bypass that block.
The owner was asked to open/copy from the file manually if full-payload comparison
is desired.

## Pending

- Full web custom-payload versus no-custom comparison, including exact historical placeholder.
- Browser destination comparison (if needed; no authenticated browser session used).
- Production change and regression coverage (not part of the fixture exporter).

## Multi-block destination checks — 2026-10-22

The owner confirmed local fixture buttons **2 and 3 work for the single-line
sample** and requested multi-block checks. All following operations were one
paste per complete fixture, into the same private test page, on Notion Desktop
7.40.0. No manual per-formula conversion was used to obtain rendering.

| Probe | Clipboard representation | Actual destination result |
| --- | --- | --- |
| P2 | Plain Markdown: three paragraphs, five inline formulas, Chinese surrounding text | Three distinct editable paragraph elements; all five formulas rendered. Opened the second paragraph's `\\sqrt{z}` and changed it to `\\sqrt{z+1}`; opened the final paragraph's `E=mc^2` editor. |
| H3 | HTML `<p>` elements with the same five formulas | All formulas rendered, but this native CUA HTML paste produced **one editable block with soft line breaks**. This is not evidence of independent HTML paragraph-block support. |
| H4 | HTML paragraph + HTML table + following paragraph, literal `$…$` math | Separate paragraph/table/paragraph blocks and table cells preserved, but **all five formulas stayed literal source**, including both surrounding paragraphs and both formula cells. This is a controlled failing comparison for the mixed-rich-content path. |
| P5 | Plain Markdown counterpart of H4, including GFM table | Separate paragraphs and a native 3-row, 2-column table; all five formulas rendered. Opened the Root cell's native Equation (LaTeX) editor, changed `\\sqrt{x+1}` to `\\sqrt{x+2}`, and saw the modified formula in the cell. |
| P6 | Plain Markdown: multiple paragraphs, inline formulas, `$$` block equation, inline code, fenced code, escaped currency | Inline and block formulas rendered; the block equation's editor exposed `y=x+1`. Inline/fenced code dollar expressions remained literal code. Escaped currency was not converted into math, but the backslashes remained visible (`\\$5`, `\\$10`), a fidelity limitation. |
| P7 | Plain Markdown: unescaped `$5 and $10`, inline math, inline code, multiple paragraphs | Currency stayed ordinary `$5 and $10`, inline `x^2`/`y^2` rendered, and code `$x^2$` stayed literal. |

After Command-R on the test page, an immediate accessibility observation briefly
returned older page data; the subsequent screenshot and settled tree showed the
new probes intact. The modified P5 Root cell visibly retained the `+2` expression;
clicking it again exposed native Equation (LaTeX) value `\\sqrt{x+2}`. Thus the
tested table formula remained editable after reload, not merely a rendered image.

### Interpretation and limits

**Owner correction:** the earlier accepted Notion rich-table behavior cannot be
replaced wholesale with Markdown tables. P5 proves only its simple GFM fixture.
Plain Markdown is a diagnostic control, not an approved replacement for the
Notion Copy Format. The Lark rich-table representation also cannot be assumed
universally compatible with Notion. The next comparison must preserve the
accepted rich-table fixtures while repairing editable inline math in the same
mixed content.

The tested plain-Markdown path supports genuine multiple native blocks, simple
tables and inline equations on this destination version. The owner's concern is
real for the tested HTML/table path: formulas remain source even when the same
formulas work through plain Markdown. HTML-only multiline H3 must not be counted
as a genuine multi-block pass because it became one block.

This supports a candidate that avoids MathML/private native clipboard data for
ordinary Markdown content. It does not yet certify the App's final copy action,
every inline equation, other Notion versions, browser destinations, or Complex
Table Output with merged cells. Do not drop rich merged-cell fidelity silently.
The historical placeholder cause remains separate from H4's literal-source
failure. No production adapter was changed and Issue 07 is not resolved.

`multiblock-fixtures.json` preserves the exact P2/H3/H4/P5/P6 inputs.
The local HTML fixture now adds buttons **5–9**, preserving buttons 1–4.
Browser buttons that offer both `text/plain` and `text/html` still need their own
manual destination comparison; native CUA probes supplied one explicit format.

## Native mixed-content reference — prepared, capture pending

The test page now contains a bounded `NREF BEGIN` / `NREF END` specimen with
native paragraphs, bold text, inline equations, and a native table. It is a
reference for Notion's own clipboard structure, not a complex-table acceptance
fixture or proof that the App can reproduce that structure. An initial paste
landed in an existing test code block; it was immediately undone and the code
block's original text was verified before the specimen was inserted correctly.

The local `index.html` now includes a fixture-only paste receiver and anonymous
JSON download. It accepts only clipboard text containing both NREF sentinels,
reads the current user-initiated paste event's selected MIME representations,
and anonymizes UUIDs before showing/exporting them. It does not read clipboard
history, send network requests or write to Notion. Browser policy still prevents
agent access to this local HTML file; manual owner paste/export is required.
No native reference capture has been received and no production fix was made.

## Rich-table/formula integration fixtures — 2026-10-22

Owner feedback: buttons **2, 3, 5, 6, 8 and 9 work**; remove the currency
backslashes in 9. This is owner-reported destination acceptance of those
fixtures, not evidence that every formula/table shape passes. Fixture 9 now
contains ordinary `$5 and $10`; its earlier escaped-currency observation remains
historical evidence. The owner correctly identified the missing integration
fixture for the existing rich-table path combined with formulas.

New buttons **10–12** use the same complete input, not a plain Markdown substitute:

- Two HTML tables, including Unicode/entities and protected literal cell text.
- An existing complex-table regression shape extended with formulas: caption,
  `rowspan="2"`, `colspan="2"`, and Y/Z occupied-grid alignment.
- Seven inline formulas across surrounding paragraphs and both tables, plus one
  independent display formula.

`rich-mixed-input.json` preserves the authored source and complex HTML.
`GenerateFixture.swift` now accepts this optional JSON input, compiling the
production Notion/Lark adapter and renderer sources unchanged. The generated
`rich-mixed-generated.json` and `rich-mixed-fixtures.json` preserve the exact
candidate payloads. Case 10 uses current Notion HTML/native v3/source; case 11
uses the existing Lark renderer's literal-math HTML/source as an experiment;
case 12 uses current Notion MathML HTML/source without native v3. None is an
approved production replacement. All retain both HTML tables, caption and spans
in their source representations; that does not guarantee destination fidelity.

**Agent destination probe:** pasted the exact case-11 HTML via native CUA
`format: html` in one operation. Notion created the two tables and preserved the
observed literal cells, Unicode and projected Y/Z positions. All seven inline
formulas and the display formula remained literal source. The target's table
accessibility tree showed empty projected cells for merged positions; it did
not establish native merged cells. The caption was not exposed in that observed
tree, so caption fidelity is not certified. This probe is explicitly HTML-only;
the browser buttons offer both HTML and text, and still need their own owner
comparison. The App, recognition, credentials and production clipboard adapter
remain unchanged.

## Owner outcome for rich mixed cases

2026-10-22 — Owner reports **10–12 all fail**. The combined rich-table/equation
goal is therefore not achieved by any of these candidates. The report does not
yet distinguish formula-only failure from damaged tables or lost content; a
classification question is pending. Do not infer that Notion cannot support the
goal at all, or silently replace the accepted rich-table path with Markdown.
The next required diagnostic is a real Notion-origin mixed-content clipboard
reference, rather than more ungrounded format variants. The expected anonymous
reference JSON has not been received in its documented Downloads location.

The owner subsequently clarified: **all formulas fail to render** in 10–12.
This still does not establish the exact table-fidelity outcome. Official
[table-row documentation](https://developers.notion.com/reference/block#table-rows)
defines each cell as an array of rich-text objects, and
[rich-text documentation](https://developers.notion.com/reference/rich-text#equation)
explicitly supports inline equation objects. Together with the observed P5
native table equation editing after reload, this establishes native coexistence.
It does **not** establish that arbitrary HTML tables, merged cells, all rich
formatting or a specific clipboard representation can be imported intact. The
current evidence points to transfer-path limitations; the exact parser/encoding
cause remains unconfirmed. Any API fallback must separately validate required
table fidelity instead of assuming it preserves every HTML feature.

## Agent-run Notion-to-Notion copy/paste — passed reference check

2026-10-22 — No owner action was required for this check. Through native CUA,
searched this private test page for `NREF BEGIN`, selected exactly the five
blocks from `NREF BEGIN` through `NREF END` with a drag, and inspected the
selected text before copying. The selection contained only the intended
paragraph/table fixture, including the four equations and bold labels.

Used Command-C, collapsed the selection to its end, created an empty paragraph,
verified that paragraph had focus, and used ordinary Command-V. The second NREF
group retained separate surrounding paragraphs, bold text, the 3-row/2-column
table, both formula cells, and the two surrounding inline equations. Clicked
the fraction in the **new copy** and observed the native Equation (LaTeX) editor
value `\frac{1}{2}`. Closed the editor without changing that formula.

This establishes a successful Notion-origin clipboard round trip for this
native mixed-content fixture. It does not certify merged-cell HTML fidelity,
identify the raw private clipboard representation, or repair the external App
adapter. No raw NREF clipboard JSON was captured; the separate HTML receiver
remains unused. The installed App and accepted copy behavior are unchanged.

## Scoped native format capture and exact red reproduction

2026-10-22 — Continued autonomously after the round trip. `InspectNativeFixture.swift`
is a data-only AppKit inspector: it refuses any clipboard whose plain text lacks
all three NREF markers, reads only the bounded current synthetic fixture, checks
the pasteboard change count to reject races, and exports only text/HTML plus
decoded `text/_notion-*` entries with UUIDs anonymized. It performs no UI actions,
clipboard mutation, clipboard-history access, credential reads or network calls.
The sandboxed runs refused to identify the fixture; the approved escalated run
captured the same just-copied fixture successfully. This was a safer native-data
alternative to the blocked browser-local file receiver; that receiver was not
opened through a workaround and owner export was not required.

`native-reference.json` now contains the anonymous reference. Observed facts:

- Native HTML contains literal Markdown math and an HTML `notionvc` comment.
- Native custom data for this dragged multi-block selection includes
  `text/_notion-multi-text-production` and `text/_notion-page-source-production`.
- Every native inline equation in the selected block data uses **U+204D `⁍`**
  with an `e`/LaTeX decoration; four were observed.
- The App adapter instead emits **U+2023 `‣`** with that decoration, under its
  block clipboard envelope. The MIME/envelope difference is separately relevant;
  these observations do not prove either is the only cause.

`WriteFixture.swift` writes only the pre-exported synthetic single-formula or
RICH MIX fixture and never reads the clipboard. Its original mode emits the
same four representations as the production Notion copy seam. Writing the
original `baseline.json` and invoking ordinary Command-V in an empty test-page
paragraph reproduced **exactly `Before ‣.`**, observed in both the accessibility
tree and screenshot. This is the first controlled native-write reproduction of
the historical symptom, distinct from earlier HTML-only/literal-source failures.

The next single-variable candidate changes only the native formula marker to
U+204D. Source text and HTML/table bytes remain unchanged; verification hashes
are in `marker-comparison.json`, payloads in `marker-candidates.json`, and local
fixture buttons 13/14 are prepared. The single-formula and rich candidates have
**not** been destination-accepted. After the red reproduction, native desktop
clicks repeatedly failed with `noWindowsAvailable` despite readable AX/screenshot
state; re-querying/raising the window and a text-selection approach did not
restore verified input. Asked the owner only to foreground the test page and
click an empty paragraph so agent-driven checks can resume.

The existing complex-table native fallback projects cells as literal runs, so
fixing one marker alone does not establish native equations in those cells.
Likewise any pre-existing code/currency parsing boundaries remain separate.
No production adapter change, App replacement, acceptance closure or merge.


## Marker-only green and remaining rich-table failures (2026-10-22)

After the owner foregrounded the test page, the agent pasted `baseline.json`
with **only U+2023 changed to U+204D**. The new paragraph rendered `Before x².`
next to the unchanged `Before ‣.` control. Clicking the new formula opened a
native **Equation (LaTeX)** input containing `x^2`. The unchanged v3 MIME,
Chromium envelope, HTML and source therefore suffice on Notion Desktop 7.40.0;
changing the native MIME or adding a virtual-clipboard bridge was unnecessary
for this controlled case.

The same marker-only change on `rich-mixed-generated.json` made the paragraph,
GFM-table inline equations and display equation render. It exposed two separate
remaining defects: explicit text-only `<math>` source in Complex Table Output
had been reduced to literal dollar text, and `$5 and $10` in the GFM table was
misclassified as an equation. Complex-table caption and projected Y/Z slots
remained visible; native merged cells are not claimed.

## Production candidate, destination pending (2026-10-22)

On branch `codex/notion-inline-math-fix`, three new public-copy regression
failures were observed before changing behavior (`ticket07-red-focused.log`):
wrong equation marker, missing complex-cell equations / currency parsing, and
literal-cell fidelity. The fixed copy adapter uses U+204D; the sanitizer now
also exposes the same occupied cell grid with inert generated math metadata
for **explicit text-only `<math>` source only**. It retains the existing HTML
and TSV representations. Complex-cell text is never reparsed as Markdown.
The math delimiter parser avoids treating adjacent prices as a formula and
keeps backtick code protected. No target API, authentication or browser bridge
was added.

`Ticket 03 self-test passed.` after the changes, including the new full mixed
copy test: seven native inline equations, one display equation, code / currency,
caption / span fallback, projected columns and sanitization. XML entities can
split text across runs; the literal-cell assertion joins the runs semantically.
The earlier `scripts/test.sh` run covers only the basic 48-check suite, not
Ticket 03; the focused red/green commands use `--ticket03-self-test`.

`rich-mixed-fixed.json` is exported from the actual changed production sources,
not patched after export. The full candidate has **not yet passed destination
acceptance**: desktop coordinate clicks again report `noWindowsAvailable`.
The known synthetic candidate was written to the clipboard and the owner was
asked only to click an empty test-page paragraph and paste once. Agent will
inspect that result. The installed V1 App is unchanged and nothing is merged
or published.


## Full destination green (2026-10-22)

Supersedes the pending candidate status above. The owner pasted the actual
`rich-mixed-fixed.json` candidate. Agent inspection verified all seven inline
equations and the display block, both tables, literal code, unescaped prices,
caption, Unicode and projected Y/Z positions. In the complex table, agent
opened native `\frac{1}{2}`, changed it to `\frac{2}{3}`, committed, reloaded,
and reopened the exact saved `\frac{2}{3}`. It was then restored to `\frac{1}{2}`.
The merged-cell projection limit remains; true native merged cells are not
claimed. Full evidence, transfer mechanism and boundaries are recorded in
[destination verification](destination-verification.md). No V1 replacement or
publication occurred.


## Actual App copy investigation and runtime switch (2026-10-22)

Owner reports normal Notion Copy Format paste fails, while Markdown partially
renders. Ticket 07 is reopened. The earlier exported-fixture acceptance does
not establish signed-App workflow acceptance.

The agent bound the exact running dist App and used its actual Notion button
on the existing synthetic RICH result. `InspectAppFixture.swift` refuses data
unless the known bounded display-formula/RICH END/caption/Group source matches.
It captured the normal App copy: three U+204D native equations, no U+2023.
A later ordinary paste showed placeholders. The second guarded capture found
identical plain source but **different native and HTML data**: four U+2023
markers, no U+204D. Consequently this was not an identical-clipboard-payload
red result; something switched the data before paste. The two anonymous
captures are `app-copy-inspection.json` and `app-copy-after-paste.json`.

Owner then reported recurring screenshot permission requests despite toggle-on.
The agent observed System Settings MyMathpix on, removed/re-added only that
entry with the exact dist candidate, and used the system Quit and Reopen action.
Process metadata demonstrated it launched old `/Applications/MyMathpix.app`.
The two Apps share an identifier but have different cdhash-only designated
requirements. This establishes a concrete runtime switch, not permission
success, nor proof of every cause of the clipboard change. See Ticket 10.

V1 is fully backed up and the candidate is signature-verified. Auto-review
rejected terminating the old installed process because unsaved state could be
lost and stopping/replacing it lacked explicit owner authorization. Nothing
was terminated or replaced. Owner approval is pending for exit plus replacement
at the canonical path. Do not bypass this rejection. No screenshot pixels,
paid recognition, credential access, broad permission reset, new build,
re-signing, merge or release occurred during this renewed diagnosis.


## Authorized installation; system authentication pending (2026-10-22)

Owner explicitly approved exit and replacement. V1's complete backup and
candidate signature were verified before the exact matching App process was
terminated and candidate installed at `/Applications/MyMathpix.app`. Strict
signature / executable identity and subsequent running path match the frozen
candidate. No main merge or public release change occurred.

Refreshing only MyMathpix's Screen Recording record now requires macOS Touch ID
or password unlock. Agent handed that step to the owner without reading or
entering credentials. Actual overlay acceptance and normal-copy destination
acceptance remain open. The candidate will not be rebuilt/re-signed during
permission validation. Ticket 10 records the current state.


## Owner acceptance and single-table candidate (2026-10-22)

The installed canonical-path App now has executable SHA256
`abb2215a470f97c93e65f90b87643cddb59df7659c6d61d0bd88bce9a28cd1c3`.
The preceding candidate is completely backed up at
`dist/backups/MyMathpix-before-table-fix-701ac58e.zip`; V1 backup remains intact.
No main merge or public release was performed.

Storage/provenance tests exposed a further actual-model bug beyond the native
marker: saving sanitized display HTML lost explicit cell math. It now stores
inert markers. A conservative legacy bridge uses only real source-table math
and declines values also present as literal code. Offline coverage drives the
recognition/storage/relaunch/copy path.

Ticket 11 red tests reproduced two rich tables before destination import. The
shared layout now replaces one matching Markdown table in position, preserving
rich structure and caption once. Old escaped prices compare against the same
clipboard cell projection in all clients. Release and 48 basic checks pass.

Observed signed-App preview: one table, one caption, rendered cell equations.
Actual Copy Lark guarded capture `app-lark-single-table.json`: one HTML table,
one caption, one source table, no native Notion types. Its four formula strings
match Markdown exactly: display y=x+1, inline z0/u²+v²/fraction. Destination
Lark formula rendering still needs confirmation.

Owner now explicitly accepted Notion and Markdown in the normal workflow.
This closes 07; earlier reopened/fixture-only status is historical. Screen
Capture permission was proven on the preceding frozen artifact; rechecking
after this rebuild is separate from paste acceptance.

# Notion inline equations: exported-fixture destination verification

2026-10-22 · Notion Desktop 7.40.0 (7.40.0) · private synthetic test page
`MyMathpix inline math test`.

## Current status: actual App flow failed owner testing

The owner subsequently reports ordinary Notion Copy Format paste fails, while
Markdown renders some formulas with incomplete compatibility. This reopens
Ticket 07. The successful results below apply only to the exported synthetic
fixture, not full signed-App UI acceptance. Current running-version and
normal-copy diagnostics are pending. Do not use this record to certify the
App workflow or close the issue.

## Controlled cause and repair

The unchanged production clipboard fixture produced exactly `Before ‣.`.
Changing only U+2023 `‣` to Notion's native U+204D `⁍` produced a rendered,
editable `x^2` equation. No MIME/envelope change was needed on this version.

The full repair also preserves explicit text-only `<math>TeX</math>` semantics
in Complex Table Output and distinguishes inline dollar delimiters from
adjacent prices. Existing sanitized HTML and TSV are retained. Complex table
literal text is not reparsed as Markdown; nested MathML and active markup
remain suppressed. Inline dollar math uses non-whitespace delimiter boundaries
and does not close immediately before a digit; ambiguous prices stay text.

## Full mixed-content destination

The owner pasted `rich-mixed-fixed.json` once with ordinary Command-V after
agent-driven native clicks intermittently returned `noWindowsAvailable`.
This JSON was exported from the changed production adapter sources, without
post-export marker replacement. The writer emits the same four public/native
representations as the Copy Format boundary. The agent then inspected the real
Notion destination and drove the editing and reload checks.

| Case | Observed result |
| --- | --- |
| Before paragraph: `x^2`, `\frac{a}{b}` | Both render inline |
| GFM table: `E=mc^2`, `\sqrt{x+1}` | Both render inside editable table cells |
| After paragraph: `z_0` | Renders inline in its separate paragraph |
| Complex table: `u^2+v^2`, `\frac{1}{2}` | Both render inside the projected native table |
| Display equation: `y=x+1` | Renders as a separate display block |
| Price: `$5 and $10` | Remains literal price text in both tables, no slash |
| Code: `**literal** $not_math$` | Remains literal code content |
| Complex literal: `Keep **literal** ` + backtick `code` + `$5 and $10` | Remains literal text |
| Caption, Unicode `α ©`, Y/Z columns, occupied span slots | Retained |
| Complex-cell edit | Opened native Equation (LaTeX), changed `\frac{1}{2}` to `\frac{2}{3}`, committed |
| Persistence | Reloaded Notion, saw `2/3`, reopened native editor with exact `\frac{2}{3}` |
| Cleanup | Restored the complex-cell formula to `\frac{1}{2}` and observed rendered `1/2` |

All seven intended inline equations and the display equation rendered.
The original red controls and earlier failed candidates remain in the page;
they must not be mistaken for the final sample at the bottom.

## Limits and validation boundary

- Notion's native table still projects merged cells into occupied grid slots;
  this repair does not add true native rowspan/colspan support. The clipboard
  HTML retains its caption and spans, and native cell contents/columns are
  preserved. This matches the existing adapter's projection, without replacing
  rich copy with a whole-document Markdown workaround.
- Complex-cell math is recognized from explicit, sanitized text-only `<math>`
  source. Arbitrary literal dollar text in that HTML remains literal.
- This is an offline clipboard adapter using an undocumented Notion v3 format,
  verified on the target version above. It is not a public Notion API contract
  or a guarantee for every Notion/browser version.
- Public `ClipboardService.copy` regression tests use isolated named
  pasteboards; the real destination uses the adapter-exported synthetic data.
  The new signed App's normal UI Copy click has not separately been exercised.
- No credentials, unrelated clipboard content, live recognition, authentication,
  browser injection, Notion document APIs or installed-App replacement were
  used for this repair. Main and GitHub release remain unchanged.

## Candidate

`dist/MyMathpix.app` is a locally built, ad hoc signed candidate with the existing
MyMathpix name, bundle identifier and sandbox entitlements. The installed
`/Applications/MyMathpix.app` and published V1 ZIP are unchanged. This candidate
has not been promoted, installed, merged or published.


## Final installed-App owner acceptance

2026-10-22 — Owner tested all three installed App formats and accepted them:
“无敌棒! 三个都测试了, 没问题.” This supersedes the pending/failure checkpoints
above for the current d1a143db clipboard implementation. Owner authorized
GitHub publication. No claim is made about other destination versions, and
Issue 09 remains open.

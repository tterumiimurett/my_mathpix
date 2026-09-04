# 03 — Make recognized content editable, previewable, and copyable

**What to build:** The owner can compare the original Snippet with editable Canonical Markdown and an offline rendered preview, correct formulas or tables, and choose a Copy Format suitable for a Paste Target. Pure Formula capture remains fast, while mixed content waits for review and no Native Paste behavior is falsely promised.

**Blocked by:** 01 — Make Screen Capture survive through a mock result.

**Status:** ready-for-agent

## Suggested agent split

- **Work package A — Output and preview contract:** cover deterministic normalization, Pure Formula classification, Combined Output, safe complex-table handling, and offline rendering.
- **Work package B — Clipboard experience:** cover explicit formula, Markdown, table, rich-content, and image representations plus pasteboard-level verification.
- The main agent fixes the Canonical Markdown and Formula Output contracts before parallel work and verifies edits flowing through preview and copy as one user journey.

## Acceptance criteria

- [ ] The Result Editor presents the original Snippet, editable Canonical Markdown, and rendered preview together, and source edits update the preview without network access.
- [ ] Normalization is deterministic: inline formulas use single-dollar delimiters, display formulas use double-dollar delimiters, simple tables remain editable GitHub-Flavored Markdown, and no generative rewrite is introduced.
- [ ] Pure Formula classification accepts only one formula plus whitespace; only that case may automatically copy raw Formula Output.
- [ ] Mixed content remains one Combined Output and waits for owner confirmation before copying.
- [ ] Raw HTML is escaped by default, and Complex Table Output is limited to safe table-related content with no executable events, frames, navigation, or remote resources.
- [ ] Explicit actions provide Formula Output, Markdown, Combined Output, TSV table, rich table, and original image representations.
- [ ] Rich-table copy offers compatible HTML, RTF, TSV, and plain-text representations, verified by reading the public pasteboard values and types.
- [ ] Labels and help text distinguish Copy Formats from Native Paste and do not promise native Notion or Feishu blocks.


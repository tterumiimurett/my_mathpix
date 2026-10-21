# 07 — Fix Notion inline math paste

**Status:** needs-triage

**Blocked by:** None.

## Problem

Notion Copy Format does not reliably create an editable inline equation. With a source paragraph `Before $x^2$.`, the owner observed `Before ‣.` after ordinary paste into Notion. The formula is not rendered as intended. This is a confirmed unresolved destination behavior; do not assume the precise cause is known merely because the serialized native payload contains an equation annotation.

The owner reports Notion display formulas and the Markdown workflow work, and accepted the three-format Markdown / Lark / Notion Ticket 03 candidate at `ec7e140`. The owner explicitly deferred this inline defect for later investigation. Closing Ticket 03 does not close this issue.

## Intended outcome

Find a viable way for inline math to paste into Notion as a correctly rendered, editable equation while preserving the surrounding text and table content. Preserve the accepted Markdown and Lark outputs and working Notion display-math behavior. Do not silently replace formulas with an image, drop formula content, or claim success from local serialization alone.

## Acceptance criteria

- [ ] Reproduce the actual `Before ‣.` failure in a recorded Notion desktop or browser version, with a minimal non-sensitive fixture.
- [ ] Establish regression coverage through the public clipboard boundary and a real Notion destination paste; the tests must distinguish an editable equation from a placeholder, literal source, or static image.
- [ ] Confirm inline formulas in mixed text retain formula content and surrounding text; cover code/currency that must not become equations and inline formulas in tables when supported.
- [ ] Confirm existing Markdown, Lark, display formulas, rich tables, and offline/security contracts do not regress.
- [ ] Document target-version limitations and the supported transfer mechanism. Notion's undocumented v3 clipboard or local virtual-clipboard behavior must not be treated as a supported public API.

## Scope and safety

Investigation is deferred, not started by this tracking change. Future work must not read credentials or unrelated clipboard content, mutate a user's Notion documents through APIs, add authentication, or inject into the browser without separately established scope/authorization. Use explicit test fixtures and preserve the accepted three-row compact UI.

## Context

- [Ticket 03 resolution](03-edit-preview-copy.md#answer)
- [Accepted three-format evidence and known issue](../evidence/ticket03-lark-copy-2026-10-21.md)
- Current adapter: `Sources/MyMathpix/NotionClipboardDocument.swift`; native inline decoration and `org.chromium.web-custom-data` output already exist. Their presence did not establish destination compatibility.

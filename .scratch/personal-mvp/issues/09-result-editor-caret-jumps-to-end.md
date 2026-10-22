# 09 — Preserve the caret while editing Combined Output

**Status:** needs-triage

**Blocked by:** 07.

## Problem

Owner report on 2026-10-22: while editing text in the Result Editor's Edit
section, entering each character moves the caret to the end of the entire
string. To continue editing in the middle, the owner must repeatedly click the
intended position with the mouse after every character.

This is an owner-reported defect. It has not yet been independently reproduced,
and its cause is unknown.

## Intended outcome

Typing or replacing text at any position in Combined Output preserves the
expected caret/selection position while the rendered preview updates.

## Acceptance criteria

- [ ] Reproduce the report in the actual signed App using non-sensitive fixture text.
- [ ] Insert multiple characters in the middle of a line and an earlier paragraph without the caret jumping to the end.
- [ ] Verify Chinese input-method composition, selection replacement, deletion, and undo/redo preserve expected editing behavior.
- [ ] Confirm live preview, saved edits, and existing Copy Formats still reflect the final edited source.

## Scope and sequencing

The owner explicitly requested recording this issue now and investigating it
**after the Notion inline math issue (07) is handled**. This ticket records that
execution order; it does not assert a technical dependency between the defects.
Do not change editing behavior as part of the current clipboard experiment.

## Comments

2026-10-22 — Owner: each typed character sends the caret to the end of the string;
repeated mouse repositioning is required. Record for follow-up after Notion.

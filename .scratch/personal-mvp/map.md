# MyMathpix Personal MVP — Delivery Map

This map presents six original delivery tickets and explicit follow-ups while preserving the engineering coverage from the finer-grained draft as acceptance criteria and suggested work packages.

## Execution model

- One main agent owns each ticket's complete user outcome, integration, and acceptance evidence.
- A ticket may use multiple sub-agents for bounded work packages with clean interfaces or sequencing.
- One ticket does not imply one agent, and parallel-capable tickets do not require parallel execution.
- Sub-agent completion is supporting evidence only. The main agent must verify the ticket's end-to-end behavior before resolving it.
- During early stabilization, prefer sequential execution when work packages touch the same capture lifecycle, recognition state machine, or application UI.

## Stages and blocking flow

```mermaid
flowchart TD
    T1["Stage 1 — T1<br/>Stable Screen Capture to mock result"]
    T2["Stage 2 — T2<br/>Reliable Datalab recognition"]
    T3["Stage 2 — T3<br/>Editable preview and Copy Formats"]
    T4["Stage 2 — T4<br/>Recent History, Settings, and App shell"]
    T5["Stage 3 — T5<br/>Golden Set quality evidence"]
    T6["Stage 3 — T6<br/>Signed-App acceptance candidate"]

    T1 --> T2
    T1 --> T3
    T1 --> T4
    T2 --> T5
    T3 --> T5
    T4 --> T6
    T5 --> T6
    T8["Follow-up — T8<br/>Compact result and explicit main window"]
    T3 --> T8
    T4 --> T8
    T8 --> T6
```

## Recommended frontier

1. Ticket `01` is resolved by explicit owner acceptance; its implementation establishes the authoritative capture seam and repairs the reported termination. See [01 — Make Screen Capture survive through a mock result](issues/01-stable-screen-capture.md#answer) for the verified evidence and owner-waived external runs.
2. Tickets `02`, `03`, and `04` are resolved following the owner's confirmations on 2026-10-21; see [Ticket 02](issues/02-reliable-datalab-recognition.md#answer), [Ticket 03](issues/03-edit-preview-copy.md#answer), and [Ticket 04](issues/04-daily-workflow.md#answer). Ticket 04 menu-bar visibility and [Ticket 07 — Notion inline math](issues/07-notion-inline-math.md) remain unresolved follow-ups. These resolutions do not close the final integration gate.
3. Ticket `05` is resolved on 2026-10-22: both modes pass the reviewed ordinary Golden Set at 69/70 with category floors met; boundary failures and original failed baseline remain visible. See [Ticket 05 Answer](issues/05-golden-set-quality.md#answer) and [quality evidence](evidence/ticket05-golden-set/quality-summary.md). Ticket `06` is now the next integration frontier.
4. Ticket `08` is claimed after the owner rejected the candidate's oversized result on 2026-10-22. It restores the compact floating Result Editor and separates menu-bar result access from explicit large-workspace activation. See [Ticket 08](issues/08-window-roles-regression.md); actual desktop capture/menu/Command-Tab remains a parent acceptance step.
5. Ticket `06` is the integration gate. It must test the assembled signed App and cannot be replaced by reports from earlier tickets.

2026-10-21: The owner accepted Ticket `04` and requested resolution and merge. Follow-up: the menu-bar icon is still not visible, including after the owner expanded Hidden Bar; its cause and repair remain open. Resolution is an explicit acceptance exception, not a claim that menu-bar visibility passed.

## Delivered context

- Ticket `03` is resolved by owner acceptance on 2026-10-21 for Markdown / Lark / Notion at implementation commit `ec7e140`. See [accepted Lark/three-format verification](evidence/ticket03-lark-copy-2026-10-21.md) and [main integration verification](evidence/ticket03-main-merge-2026-10-21.md). Notion inline math is **not fixed** and is tracked separately in [open Ticket 07](issues/07-notion-inline-math.md). Main integration follows the completed Ticket 04 merge and preserves its shell/window behavior alongside Ticket 02 recognition and Usage Records.

- Earlier Ticket `03` two-action Markdown/Notion candidate was superseded by the accepted three-action workflow above. Its [historical verification](evidence/ticket03-notion-copy-2026-10-21.md) records the original experimental clipboard boundary; it does not establish working Notion inline math.

- Ticket `03` review fixes resolved on 2026-10-21: preserves valid LaTeX row spacing, projects merged cells without TSV column shifts, decodes HTML entities safely, and retains unrelated Complex Table Output. See [verification and review results](evidence/ticket03-spec-fixes-2026-10-21.md). Changes remain on the original Ticket 03 branch.

- Ticket `03` follow-up resolved on 2026-09-06: corrected plain-text table conversion and owner-approved single-line content preview rows, backed by [actual signed-window six-format regression](evidence/ticket03-content-rows/verification.md). This supersedes the earlier format-name-only row design. Integration remains on the original Ticket 03 branch; no other ticket was merged.

- Ticket `03` resolved on 2026-09-05: owner-confirmed compact Result Editor, offline edit/preview, and six immediate Copy Formats. See [Ticket 03 Answer](issues/03-edit-preview-copy.md#answer) and [signed-App UI verification with screenshots](evidence/ticket03-ui/verification.md). Ticket 04 can host `ResultEditorView(item:)` using the selected record and existing `AppModel`; capture-display placement remains Ticket 04 scope. Full-content LaTeX remains undecided.

# 05 — Prove recognition quality with the Golden Set

**What to build:** The owner receives repeatable evidence showing whether fast and balanced recognition produce usable formulas, tables, and mixed technical content. Quality is judged by mathematical meaning and table structure rather than superficial source-string equality, and difficult boundary cases remain visible without distorting the ordinary-case gate.

**Blocked by:** 02 — Make real Datalab recognition reliable and recoverable; 03 — Make recognized content editable, previewable, and copyable.

**Status:** claimed

## Suggested agent split

- **Work package A — Reviewed truth and rubric:** assemble representative cases and define semantic formula, table-structure, mixed-content, and boundary-case judgments.
- **Work package B — Repeatable evaluation and report:** run the product output through the rubric, compare fast and balanced behavior, enforce thresholds, and retain inspectable evidence.
- The main agent reviews disagreements and owns the final pass/fail conclusion; automated similarity alone cannot declare the product acceptable.

## Acceptance criteria

- [ ] The Golden Set contains thirty Pure Formula cases, twenty simple tables, twenty mixed-content cases, and ten separately reported difficult boundary cases.
- [ ] Formula evaluation accepts mathematically and visually equivalent LaTeX rather than requiring byte-identical source.
- [ ] Table evaluation checks row count, column count, cell content, order, Markdown editability, and applicable TSV or rich-copy structure.
- [ ] Mixed-content evaluation covers Canonical Markdown, offline preview, correction, and the relevant Copy Formats as one user-visible path.
- [ ] Ordinary cases achieve at least 95 percent overall pass rate with no category below 90 percent; difficult cases are reported separately.
- [ ] Fast and balanced results, latency, and available cost evidence are reported without exposing the Datalab token or unrelated screen content.
- [ ] Results are repeatable and inspectable, and tests assert public behavior or stable external contracts rather than private implementation details.


## Comments

- 2026-10-21: Claimed on `codex/ticket05-golden-set`, initially based on integration `3a1bde1`. Uses the already approved manifest/report, production recognition transport, public pasteboard, offline preview, and isolated correction/persistence seams. Known Notion inline and menu-bar follow-ups remain excluded. Quality requires actual outputs and hash-bound semantic review; harness success alone will not resolve this ticket.

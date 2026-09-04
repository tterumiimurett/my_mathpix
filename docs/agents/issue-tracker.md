# Issue tracker: Local Markdown

Issues and specs for this repo live as Markdown files in `.scratch/`.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`
- Triage state is a `Status:` line near the top of each issue file
- Comments and conversation history append under a `## Comments` heading

## Skill operations

- **Publish:** create the appropriate file under `.scratch/<feature-slug>/`
- **Fetch:** read the referenced path or issue number directly
- **Map:** `.scratch/<effort>/map.md`
- **Child ticket:** `.scratch/<effort>/issues/NN-<slug>.md`
- **Blocking:** record `Blocked by: NN, NN`; a ticket is unblocked when every listed file is resolved
- **Claim:** set `Status: claimed` before starting work
- **Resolve:** append the result under `## Answer`, set `Status: resolved`, and add a context pointer to the map

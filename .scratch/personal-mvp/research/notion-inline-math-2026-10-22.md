# Notion inline math transfer investigation

Research date: 2026-10-22. Scope: public documentation and public source code only. No private Notion page, credentials, destination paste, installed App, or issue status was changed.

## Finding

**Subsequent destination experiment:** the owner confirmed single-line fixture
buttons 2/3 work, and actual Notion Desktop 7.40.0 testing found a viable plain
Markdown route for multiple independent paragraphs, inline formulas and a simple
table. The HTML/table counterpart left formulas literal. Native table equation
editing survived reload. See [multi-block experiment evidence](notion-inline-math-experiment/README.md#multi-block-destination-checks--2026-10-22).
This is version-bound destination evidence, superseding the initial absence of a
reproduced direct-paste route; it is not a completed production fix.

There is a documented way to create native inline equations through Notion's public API. There is no official guarantee found that ordinary external Command-V of Markdown/HTML creates native, editable inline equations. These are different transfer mechanisms. The existing `Before ‣.` destination failure remains unresolved until a real Notion paste succeeds.

For an external macOS App, investigate clipboard compatibility with a controlled fixture first if Command-V at the current caret is essential. If that cannot be made reliable, an explicit **Send to Notion** action using the public API is the strongest documented alternative. It needs authorization and an explicit target page/block; the API documentation does not expose the current editor caret as a write destination.

## Evidence and options

| Mechanism | What the primary source establishes | Practical implication |
| --- | --- | --- |
| Ordinary LaTeX paste | Notion's math FAQ says inline LaTeX copy/paste yields source code. Its inline-entry instructions describe typing `$$…$$`, opening the equation input with Command-Shift-E, or selecting source and applying that shortcut. [Notion math help](https://www.notion.com/help/math-equations) | Typing shortcuts do not establish that pasting the same characters triggers the shortcut. Changing `$…$` to `$$…$$` alone is not a confirmed fix. |
| Manual inline insertion | Mathpix instructs users to copy raw LaTeX, choose Notion's Inline equation command, then paste inside the equation input. [Mathpix Snip with Notion](https://mathpix.com/docs/snip/snip-with-notion) | Documented workflow for a single Pure Formula: open inline equation input, paste raw Formula Output, confirm. It does not solve bulk mixed-content insertion. |
| Public rich-text API | Notion explicitly supports rich-text items of type `equation` with `equation.expression` holding LaTeX. [Rich text reference](https://developers.notion.com/reference/rich-text) | A paragraph can preserve surrounding text as separate text items around a native equation item. This bypasses clipboard parsing. |
| Public Markdown content API | The enhanced format documents `$equation$` for inline math and `$$` blocks for display math. It supports tables with rich-text cell content. The format is used by page creation and Markdown update endpoints. [Enhanced Markdown](https://developers.notion.com/guides/data-apis/enhanced-markdown) | Existing Canonical Markdown is close to the required input, but escaping and supported structures still need an adapter and tests. This is server-side parsing through an authenticated API, not the paste parser. |
| Page targeting | Public APIs create a page from `markdown`, update Markdown by matching text, and support insertion at page start/end or after a selected content range. `insert_content` remains supported but is marked legacy; new integrations are directed to `update_content` or `replace_content`. [Markdown content guide](https://developers.notion.com/guides/data-apis/working-with-markdown-content), [Markdown update reference](https://developers.notion.com/reference/update-page-markdown) | Choose an explicit new page/append destination. Do not promise insertion at an arbitrary live Notion cursor. Avoid whole-page replacement for a Snippet transfer. |
| Browser conversion helper | The actual `content.js` of `deepanshut041/notion-inline-equation` removes delimiters, selects source, shows a HUD asking the user to press Command/Ctrl-Shift-E, observes the equation dialog, and advances after conversion. [Source](https://github.com/deepanshut041/notion-inline-equation/blob/main/content.js) | This is guided UI automation, despite broad README wording. It does not prove a fully automatic one-paste path and is limited to browser DOM integration. |
| Another browser converter | Noeqtion's source selects delimited math, replaces inline math through `document.execCommand("insertText", false, "$$…$$")`, and uses `/math` plus dialog interaction for display math. [Author source](https://github.com/voidCounter/noeqtion/blob/master/content.js) | A potentially useful browser-only alternative, requiring destination/version testing. It acts inside the editor after paste; it does not establish that an external clipboard alone can trigger the same conversion. Source inspection is not independent destination acceptance. |
| Markdown file import | Notion documents `.md`/`.txt` importing and standard Markdown structures, without promising inline math conversion in the import help. [Import help](https://www.notion.com/help/import-data-into-notion) | Can be tested as a batch alternative, but the public Markdown API's equation support must not be assumed to apply to the file importer. |

## Public API shape

The minimal public rich-text representation for the existing failing fixture is:

```json
{
  "object": "block",
  "type": "paragraph",
  "paragraph": {
    "rich_text": [
      { "type": "text", "text": { "content": "Before " } },
      { "type": "equation", "equation": { "expression": "x^2" } },
      { "type": "text", "text": { "content": "." } }
    ]
  }
}
```

This example is a design illustration derived from the documented schema, not a recorded write. It belongs in a public API request, not under a guessed clipboard MIME type. The corresponding enhanced Markdown input is `Before $x^2$.`.

Notion currently documents personal access tokens (PATs) that act with the creator's workspace/page permissions, and internal connections that operate as a bot limited to shared pages. PATs avoid the per-page bot sharing step but have wider user-level access and workspace policy/expiry constraints. For a small Personal MVP experiment, a narrowly shared internal connection and dedicated test page can keep scope concrete. For a distributed integration, review the public-connection OAuth flow rather than shipping a developer's token. [PAT documentation](https://developers.notion.com/guides/get-started/personal-access-tokens), [Internal connections](https://developers.notion.com/guides/get-started/internal-connections), [Public connections](https://developers.notion.com/guides/get-started/public-connections).

## Clipboard status and existing implementation

The local [Issue 07](../issues/07-notion-inline-math.md) and [Ticket 03 evidence](../evidence/ticket03-notion-copy-2026-10-21.md) already establish that MyMathpix writes HTML, source fallback, native block data, and Chromium custom clipboard data. Presence of those bytes is not destination acceptance. A native-equation placeholder could result from payload shape, an unsupported import path, a fallback parser, or destination-version behavior; this research does not establish which one caused the owner's `‣`.

Notion's undocumented clipboard and browser-local virtual clipboard must not be confused with its public REST schema. Public equation support does not certify a hand-built private clipboard payload. The parent investigation covers clipboard-specific source evidence separately; no stable clipboard solution is asserted here.

The parallel clipboard investigation established these narrower findings:

- [REA's original investigation](https://rea.today/showcase/notion) examines the Notion Desktop 7.6.1 clipboard bridge and separate cached web modules. It describes a `notionvc` HTML comment whose ID refers to browser-local virtual clipboard data. Its testing section explicitly distinguishes module probes from a real desktop UI paste. This is evidence of a possible private transport dependency, not proof that externally reconstructing one field fixes current Notion. The web-module cache date is July 13, 2026; its findings must not be generalized to every later release.
- `Sources/MyMathpix/NotionClipboardDocument.swift` already creates MathML, v3 block data, and a Chromium custom-data envelope. Its native rich text uses a `‣` placeholder together with an `e`/LaTeX annotation. The appearance of `‣` in the owner's pasted result is compatible with a lost/unrecognized equation decoration, but does not establish that the placeholder character itself is wrong or identify the responsible parser.
- EquaPaste's actual [Notion target at commit 6bc8509](https://github.com/halilibrahimyesirci/EquaPaste/blob/6bc8509f6219368a6525d2a8709409466978714d/src/core/targets.ts) writes `text/plain` containing bare LaTeX and instructs the user to enter `/math` or Command-Shift-E first. Its [unit test](https://github.com/halilibrahimyesirci/EquaPaste/blob/6bc8509f6219368a6525d2a8709409466978714d/tests/unit/targets.test.ts) checks bare LaTeX, not native conversion in a Notion destination. Its general editable-equation marketing therefore does not establish a direct mixed-text inline-paste fix.
- [Notion Formula Copier's Chrome Web Store listing](https://chromewebstore.google.com/detail/notion-formula-copier/ihgjbgdolkcnipledofdelcdebdaemjj), version 1.1.0 updated May 26, claims an HTML-stripping/delimiter-conversion paste workflow. No public source or real destination acceptance was verified in this investigation. It is an unverified candidate, so the conclusion is **no documented/reproduced general direct-paste solution found**, not a claim that no solution could exist.

## Recommended next experiment

1. Use an explicit, non-sensitive fixture: `Before $x^2$.`, two adjacent inline formulas, Chinese surrounding text, a display equation, and a simple table containing an inline equation. Include code literals and currency negative cases.
2. Record Notion desktop/browser version. Compare a native Notion-to-Notion copied equation against MyMathpix output, without reading unrelated clipboard history or document content. Inspect whether the formula can be clicked and its source edited, then re-open the page to check persistence.
3. In a bounded compatibility experiment, change one clipboard representation at a time: plain `$$…$$` text, minimal HTML variants, and private v3 data, separately on browser and desktop. A local round-trip, rendered HTML, or source code shape is insufficient to close Issue 07.
4. If the clipboard mechanism remains version-dependent, prototype authenticated **Send to Notion** into a dedicated destination, preferably a new child page or explicitly selected append target. Verify public API readback contains `type: "equation"`, and verify the destination visibly renders and edits it.
5. Keep the existing accepted three copy rows and working Markdown/Lark/display-math/table behavior. Do not silently substitute images or add account authorization to an ordinary copy action.

## Limits of this investigation

The initial web-research pass executed no destination conversion or API request.
Subsequent destination experiments are separately recorded in the update above;
no Notion API write was executed. Official documentation establishes supported
schemas and workflows, not that this App's current implementation passes them.
Browser extensions are possible implementation references, not a validated
recommendation to install. The unresolved issue remains open pending production
implementation and real Paste Target acceptance.

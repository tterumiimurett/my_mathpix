# Snippet Recognition

This context defines a personal-first tool for turning selected visual content into reusable structured text. Its initial purpose is to satisfy the owner's own recognition workflow before it becomes a public App Store product.

## Language

**Snippet**:
A user-selected visual region containing one or more expressions, tables, or surrounding text to be recognized as a single unit.
_Avoid_: Document, page, scan

**Upload Payload**:
The final pixels inside a Screen Capture selection that are sent for recognition. It excludes the complete screen, window titles, foreground application identity, and visual context outside the selection.
_Avoid_: Screen recording, full screenshot

**Screen Capture**:
The act of selecting a rectangular region of the Mac screen to create a Snippet.
_Avoid_: Screenshot file, document import

**Recognition Mode**:
The interpretation requested for a Snippet. Automatic mode is the default; formula or table mode may be selected when recognition is retried.
_Avoid_: File type, export format

**Recognition Attempt**:
One submission of a Snippet for recognition. The initial attempt prioritizes speed; a High-Quality Retry reuses the same Snippet with a more accurate processing mode.
_Avoid_: Capture, version

**Usage Record**:
The request count and cost breakdown associated with Recognition Attempts, retained so the owner can understand current use and later design a free allowance and subscription.
_Avoid_: Subscription, invoice

**High-Quality Retry**:
A new Recognition Attempt that exchanges additional processing time for potentially better output without requiring another Screen Capture.
_Avoid_: Error retry, recapture

**Formula Output**:
The editable LaTeX representation recognized from the mathematical content of a Snippet.
_Avoid_: OCR result, formula image

**Pure Formula**:
A Snippet whose recognized content consists of one formula and whitespace only. It may be copied automatically; any ordinary text, multiple independent content blocks, or table content excludes this classification.
_Avoid_: Math-containing Snippet, equation page

**Table Output**:
The editable Markdown table representation recognized from the tabular content of a Snippet.
_Avoid_: Spreadsheet, table image

**Combined Output**:
A single Markdown representation that preserves the text, inline and block formulas, and tables recognized from a Snippet.
_Avoid_: Raw response, OCR text

**Canonical Markdown**:
The conservatively normalized GitHub-Flavored Markdown and KaTeX-compatible form used by Combined Output and the Result Editor preview. Normalization is deterministic and does not use a second generative model to rewrite recognized content.
_Avoid_: Notion Markdown, Feishu Markdown

**Complex Table Output**:
An HTML table representation supplied alongside Table Output when Markdown cannot preserve the recognized table structure.
_Avoid_: Markdown table

**Paste Target**:
An editor, initially Notion or Feishu, into which a user pastes recognized content for reuse.
_Avoid_: Export destination, integration

**Result Editor**:
The surface in which Combined Output source is edited while its rendered preview updates. It is not a block-based or word-processing editor.
_Avoid_: Visual document editor, document library

**Copy Format**:
A representation explicitly placed on the clipboard for reuse: LaTeX, Markdown, TSV table, rich table, image, or Combined Output.
_Avoid_: Export format, file type

**Native Paste**:
A later integration capability that creates editable native formulas, tables, and text inside a Paste Target. It is distinct from copying source through the clipboard.
_Avoid_: Copy, Markdown paste

**Recent History**:
The locally retained collection of the twenty most recent Snippets, their original images, and their final edited outputs. Adding a twenty-first record deletes the oldest record.
_Avoid_: Document library, archive

**Failed Record**:
A Recent History entry whose original Snippet was retained after recognition failed, allowing the user to retry or copy the image.
_Avoid_: Error log, successful output

**Diagnostic Log**:
A local record of operational events that excludes credentials, Snippet pixels, and complete recognized output. It may be exported deliberately for troubleshooting but is not uploaded automatically.
_Avoid_: Usage Record, recognition history

**Golden Set**:
A fixed development-only collection of representative Snippets with expected outputs, used to decide whether recognition behavior is acceptable. Its initial ordinary cases contain thirty pure formulas, twenty simple tables, and twenty mixed-content Snippets; ten deliberately difficult boundary cases are reported separately.
_Avoid_: Demo data, training set

**Golden Result**:
The reviewed expected output for one Golden Set Snippet. Recognition is judged by mathematical meaning and layout, table cells and ordering, mixed-content reading structure, and editable behavior in a Paste Target rather than exact source-string equality.
_Avoid_: Datalab response, Mathpix output

**Passing Threshold**:
At least 95 percent of the ordinary Golden Set must pass, with no ordinary content category below 90 percent. Deliberately difficult boundary cases are reported separately and do not determine this threshold.
_Avoid_: Perfect accuracy, Mathpix parity

**Dogfood Gate**:
The evidence required before Public Product work begins: the Passing Threshold, fourteen consecutive days of daily use without history loss or credential exposure, at least 90 percent of daily Snippets captured successfully without recapture, most fast attempts completing within five seconds, and the owner choosing this product over Mathpix for routine use.
_Avoid_: App Store readiness, internal demo

**Personal MVP**:
The first usable version optimized for the owner's own Snippet workflow, before public distribution requirements are added.
_Avoid_: Public beta, App Store release

**Public Product**:
The later English-language macOS product publicly distributed first in the United States Mac App Store, offered with a free usage allowance and a paid subscription.
_Avoid_: Personal MVP

**Public User**:
A STEM student or researcher who needs screen content containing formulas, tables, or mixed technical material converted into editable source.
_Avoid_: General OCR user, enterprise document-processing customer

**External Beta**:
A TestFlight validation stage with thirty external users that precedes phased public release.
_Avoid_: Personal MVP, public launch

**Public Success**:
At least ten External Beta users using the product weekly for four consecutive weeks and at least one user purchasing the subscription, in addition to successful App Review.
_Avoid_: App Review approval, download count

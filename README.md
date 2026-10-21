# MyMathpix

A personal-first native macOS snippet recognizer for formulas, tables, and mixed technical content. It captures a selected screen region, sends only that PNG to Datalab's hosted Convert API, and returns editable Markdown/LaTeX with an offline preview.

## Current scope

- Global `Control-Command-M` screen capture
- Datalab `fast` recognition and `balanced` high-quality retry
- Compact offline KaTeX preview, with independent Original and Edit actions
- Whole-result Markdown / Lark / Notion copy actions; Lark keeps rich tables and Markdown formulas
- Local history containing the 20 most recent snippets
- API token stored in a private `0600` file inside the App Sandbox container

No account, subscription, backend, analytics, or cloud history is included in the Personal MVP.

Known deferred issues: Notion inline equations may paste as placeholders, and the menu-bar icon may be invisible. Use the normal application window. The experimental Notion clipboard adapter does not guarantee native editable blocks in every target version. See the accepted contract and evidence limits in [the Personal MVP spec](.scratch/personal-mvp/spec.md).

## Run

Double-click `启动 MyMathpix.command`, or run:

```sh
./scripts/build_app.sh
open ./dist/MyMathpix.app
```

The current machine needs Swift 6.2 or later. The first capture requires macOS Screen Recording permission. Enter a Datalab API token in Settings; it is stored in a private `0600` file inside the App Sandbox container and never written to preferences, history, or logs. MyMathpix does not read, migrate, write, or delete Keychain items.

## Self-test

```sh
./scripts/test.sh
```

The current standalone Command Line Tools installation does not include XCTest, so this runs deterministic core checks through the app's `--self-test` entry point. Move them into XCTest after installing full Xcode.

## Third-party software

The offline formula preview bundles KaTeX under the MIT License. See `THIRD_PARTY_NOTICES.md`.

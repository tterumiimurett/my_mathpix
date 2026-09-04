---
status: accepted
---

# Store the Personal MVP token in a sandbox file

At the owner's explicit request, the Personal MVP stores the verified Datalab token in a local file with 0600 permissions inside the App Sandbox and does not access macOS Keychain. This supersedes only the Keychain-storage part of ADR 0002: direct Datalab access remains unchanged, existing Keychain items are neither read nor migrated nor deleted, and credentials remain prohibited from preferences, history, diagnostic artifacts, and command output.

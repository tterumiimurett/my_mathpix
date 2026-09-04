---
status: accepted
---

# Call the Datalab API directly in the Personal MVP

The Personal MVP will call Datalab's hosted Convert API directly from the native macOS client and store the owner's API token in Keychain. This avoids operating a backend before the recognition workflow is validated, but it is deliberately limited to the owner's installation: a public product must move the shared credential, usage enforcement, and subscription entitlement checks behind a controlled backend rather than embedding a developer-funded token in the distributed app.

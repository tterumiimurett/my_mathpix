# Ticket 01 mock status URL integration regression

Date: 2026-10-21. Baseline: integration `26ebddd`.

The signed App's existing mock-recognition self-test failed after the accepted
Ticket 02 integration: the mock returned `/mock/ticket01-check`, while the
production status-URL contract requires `/api/v1/convert/{id}`. The client rejected
the response before polling. Only the mock response URL and matching GET route
were updated to `/api/v1/convert/ticket01-check`; production URL trust is unchanged.

The isolated worktree's signed baseline reproduced the failure:

```text
TICKET01_MOCK_PROTOCOL_FAIL submit=1 polls=0 png=yes fields=yes fixture=yes guard=yes result=no
RED: expected safe mock protocol evidence was not emitted (status=1)
```

After the two-line fix and signed rebuild, the same public test passed:

```text
TICKET01_MOCK_PROTOCOL_OK submit=1 polls=multiple png=yes fields=yes fixture=yes guard=yes result=yes
TICKET02_RECOGNITION_OK
```

Validation: `scripts/ticket01_mock_recognition_test.sh`,
`scripts/ticket02_recognition_test.sh` (including untrusted poll redirect rejection),
strict deep signature verification, and `git diff --check` passed.

This repairs the deterministic capture-to-mock prerequisite. It does not establish
a real Screen Capture, live-service, Golden Set, or final Ticket 06 acceptance pass.
No credential, private history, production trust policy, or running Golden Set
artifact was changed.

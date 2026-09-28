# Step 2 — Write the tests
Every test below is runnable code at the project's Test Layout. The report records them; it does not
duplicate them.

## Backend
- **Unit** — the code units this slice added or changed: happy path, validation errors, boundaries, and
  every invariant from the unit knowledge base.
- **Integration** — each write and read path through the service and its storage or pipeline. Name the
  cases that are N/A by construction, with the reason.
- **Provider contract** — `contracts.verify` set: run it from the repo root and map each operation of
  contract-changes.md to the check that covers it; write no provider test it already proves (a non-zero
  exit is a failure). Unset: one test per operation of contract-changes.md — happy path, error and auth
  cases from its Provider test plan, and a negative assertion for each removed operation.
- **Regression** — the existing behaviour this change must not break.

## Frontend / Mobile
- **Component** — each surface's components and screens against the acceptance criteria: rendering,
  state, forms, loading, empty and error states, and accessibility where a pack or rule sets it.
- **Consumer contract** — from its `### Consumer ({Project})` section: only the operations and fields
  this surface uses, each confirmed in the spec, with the backend mocked from the spec's responses and
  the error states it must handle.
- **E2E** — only when this platform runs E2E here rather than in sk.uat, with its E2E Tooling; `none` →
  map those criteria to component or integration tests.
- **Regression** — as above.

## test-report.md
```
---
project: {Project}
unit: {unit-id}
result: PASS | FAIL | NOT-RUN
---
# Tests: {Project}
## Suite — runner and command; cases written, green, red; coverage vs thresholds (or SKIP).
## Acceptance criteria — | AC | Test (path::name) | Status |; out-of-scope criteria named as such.
## Contract — contracts.verify command, exit and date, or | Operation | Provider / consumer test | Status |.
## Regression — what is covered.
## Findings — defects and mismatches found, never patched here.
## Skips — every `SKIP — {field}: none`, and every skipped test with its reason.
```
`result: PASS` only when every case ran green. `NOT-RUN` when Test Runner is `none` (a SKIP, not a failure).

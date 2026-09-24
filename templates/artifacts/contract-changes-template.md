---
unit: {unit-id}
intent: {intent-id}
updated: {date}
compat_rules: {path from contracts.compat_rules, or "default: additive | deprecating | breaking"}
---

# Contract changes: {unit-name}
The canonical contracts are edited in place on this branch; this file only lists what changed.
Review the change by reading the diff of the files below.

## Canonical files touched
- `specs/openapi/{audience}.yaml`
- `specs/asyncapi/{module}.yaml`

## Operations
| File | Operation (method path · channel) | Change | Compatibility | Consumers |
|---|---|---|---|---|
| specs/openapi/{audience}.yaml | `POST /orders` (createOrder) | added | additive | {Project}, {Project} |

<!-- Change: added | changed | removed.
     Compatibility: a class from compat_rules. A `breaking` row names its versioned replacement or the ADR
     that accepts the break. -->

## Verification
- Command: `{contracts.verify, or "none — provider contract tests in 05-test/{BackendProject}/"}`
- Result: {PASS | FAIL | not run} — {date}

## Test plan

### Provider ({BackendProject})
| Operation | Happy path | Error cases | Auth cases |
|---|---|---|---|

Edge cases, integration scenarios and test data:
- {…}

### Consumer ({Frontend or Mobile project}) — one section per consuming project
| Operation | Fields used | Error states handled |
|---|---|---|

UI scenarios and accessibility flows that drive these calls:
- {…}

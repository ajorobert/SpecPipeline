# ADR Index
A router: load the ALWAYS block, then every block whose signals match the task.

## Loading rules
1. Always load the ALWAYS block.
2. Load blocks whose signals match story tags, changed files or the request.

## ALWAYS
- [ADR-0001: Modular monolith](0001-modular-monolith.md) — modules own their data

## Signals

### http api, endpoint, contract, openapi, breaking change
- [ADR-0003: Contract compatibility](0003-contract-compatibility.md) — COMPAT classes for every contract change

### command, retry, idempotency, payment
- [ADR-0002: Idempotent commands](0002-idempotent-commands.md) — how duplicates are detected

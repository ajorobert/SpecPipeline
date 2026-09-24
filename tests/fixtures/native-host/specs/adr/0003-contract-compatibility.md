# ADR-0003: Contract compatibility

## Status
Accepted — 2026-03-15

## Rules
- Every contract change is classed COMPAT-ADD, COMPAT-DEPRECATE or COMPAT-BREAK.
- COMPAT-BREAK requires a new version of the operation.

## Decision
Canonical specs in specs/openapi and specs/asyncapi; three compatibility classes.

## Context
Three apps consume the same backend.

## Consequences
- Positive: breaks are visible in review.
- Negative: versioned operations accumulate.

## Alternatives rejected
| Option | Why rejected |
|---|---|
| Code-first specs | drift |
| No classes | silent breaks |

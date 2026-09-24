# ADR-0002: Idempotent commands

## Status
Accepted — 2026-02-02

## Rules
- Payment commands MUST carry a client idempotency key.

## Decision
Deduplicate payment commands by client key.

## Context
Payment providers retry.

## Consequences
- Positive: no double charge.
- Negative: a key store to operate.

## Alternatives rejected
| Option | Why rejected |
|---|---|
| Server-generated ids | cannot detect client retries |
| No dedup | double charges |

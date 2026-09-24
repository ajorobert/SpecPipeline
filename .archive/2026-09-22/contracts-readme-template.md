---
unit: {unit-id}
intent: {intent-id}
version: v1
updated: {date}
---

# Contracts: {unit-name}

## Endpoints
| Method | Path | Description | Auth |
|--------|------|-------------|------|

## Events Published
<!-- For each event:
| Event | Schema | Delivery | Ordering | Consumer Model | Outbox |
|-------|--------|----------|----------|---------------|--------|
| {EventName} | {schema-ref} | at-least-once \| exactly-once \| at-most-once | none \| per-partition \| global | consumer-group \| broadcast | yes \| no |
If no events published: "None"
Outbox = yes: event is written to outbox table in same transaction as state change.
Required when: command handler modifies state AND publishes events (prevents dual-write).
-->

## Events Consumed
<!-- For each event:
| Event | Source Service | Delivery | Ordering | Idempotent Handler | Dedup Strategy |
|-------|---------------|----------|----------|--------------------|----------------|
| {EventName} | {service} | at-least-once \| exactly-once \| at-most-once | none \| per-partition \| global | yes \| no | commandId-store \| event-id-store \| db-unique-constraint \| natural |
If no events consumed: "None"
Dedup Strategy options:
  commandId-store      — handler checks commandId against dedup table/cache before executing
  event-id-store       — handler checks message-id against dedup table/cache
  db-unique-constraint — handler uses a DB unique constraint to reject duplicate writes
  natural              — no state side effects; idempotent by construction (document why)
-->

## Breaking Change Policy

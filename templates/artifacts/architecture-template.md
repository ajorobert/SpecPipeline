---
unit: {unit-id}
intent: {intent-id}
status: draft | approved
stories-covered: []
created: {date}
updated: {date}
---

# Architecture: {unit-name}

## Service Responsibility
## Bounded Context
## Communication Patterns
## Internal Components
## Data Flow
## Access Patterns
<!-- What queries does this data serve?
     List reads (query shape, frequency) and writes (rate, size, key distribution).
     Example:
     - Read: fetch order by ID (point lookup, high frequency)
     - Read: list orders by user (range scan, paged)
     - Write: create order (low rate, must be atomic with inventory check) -->

## Consistency Requirements
<!-- Per write path — strong | eventual | causal — with rationale.
     Example:
     - createOrder → strong (inventory reservation must be linearizable)
     - updateOrderStatus → eventual (status fanout to notifications ok)
     REQUIRED: every write path must have an entry.
     Also declare per write path how duplicate delivery and event publication are handled, following the
     project's constitution and the ADRs routed by specs/adr/adr-index.md. -->

## Failure Modes
<!-- Per external dependency — what fails, timeout, fallback.
     Example:
     - payment provider: timeout → fail the request, do not debit; retry per the project's retry policy
     - inventory context: unavailable → hold order in PENDING, process asynchronously
     REQUIRED: every external dependency must have an entry. -->

## External Dependencies
<!-- List every upstream service, database, or third-party API this unit depends on.
     REQUIRED: every entry here must have a corresponding Failure Mode entry above.
     Format:
     - {dependency-name}: {protocol} — {SLA / expected latency} — {data exchanged}
     Example:
     - payment provider: HTTPS (external) — p99 < 500ms — charge requests and confirmation receipts
     - orders database: TCP — p99 < 10ms — order reads and writes -->

## Security Approach
<!-- Auth model, data sensitivity, and encryption strategy for this unit.
     Example:
     - Auth: bearer tokens validated on every request; no local session state
     - Data sensitivity: order totals and line items are PII-adjacent; encrypted at rest
     - Transport: TLS enforced; no plaintext internal communication
     - Input validation: every mutation validates its payload before processing -->

## Error Handling
<!-- Error propagation strategy: what errors are surfaced to callers vs. handled internally, in the form
     the project's constitution, routed ADRs and .claude/rules/ prescribe.
     Example:
     - Validation errors: surfaced with field-level detail (never swallowed)
     - Upstream timeouts: surfaced as unavailable; upstream retried per the project's retry policy
     - Unexpected errors: logged with context; generic message returned (no internals leaked)
     - Business rule violations: machine-readable error code (e.g. INSUFFICIENT_STOCK) -->

## Observability
<!-- The observability strategy for this unit, in the terms the project's rules and ADRs define.
     Cover:
     - Which significant business events are logged
     - Which external calls are measured
     - How the unit's health and its dependencies are checked
     Optional:
     - Domain-level metrics emitted
     - Key business operations traced
     - Alert thresholds for error rate or latency -->

## Stories Coverage
<!-- List every story delivered by this unit. Update as stories are added.
     Format: - [{story-id}] {title}: {one-line summary of what this story delivers in this unit}
     Example:
     - [INV-001-ORD-001] Create Order: createOrder operation, validation, inventory reservation
     - [INV-001-ORD-002] Cancel Order: status transition to CANCELLED, inventory release -->

## Open Questions
<!-- Unresolved decisions. Mark a decision with cross-module reach "ADR required" (raised via sk.adr). -->

---
name: design-principles
description: "Load when: designing service architecture, data models, or API contracts — DDD bounded context rules, DDIA access-pattern-first data modeling, consistency declarations, failure modes, idempotency"
---

# Design Principles
Reference for DDD and DDIA principles applied during architecture, data modeling, and contract design.

---

## DDD Principles

- One bounded context per unit — entities do not leak across service boundaries
- Aggregates own their invariants; a command targets a single aggregate
- Domain events for cross-context side effects — not direct service-to-service calls
- Repository pattern: domain layer never calls infrastructure directly
- Ubiquitous language: entity and field names match the domain language used by stakeholders
- Anti-corruption layer required when integrating with external systems that use a different model

---

## DDIA Principles

Items marked **[REQUIRED]** are blocking — the quality bar will fail without them.
Items marked **[Advisory]** are non-blocking recommendations to surface and consider.

### Data Modeling
- **[REQUIRED]** Design the data model for access patterns first: what queries will this data serve? (read-heavy vs write-heavy, point lookup vs range scan, hot keys)
- **[REQUIRED]** Define transaction boundaries: which writes must be atomic? What is the isolation level required? Identify read-modify-write cycles as race condition risks.
- **[Advisory]** If a collection is expected to exceed 10M rows: define partition key strategy (key range vs hash) and document hot-spot risk
- **[Advisory]** If using a read replica: define read-your-own-writes strategy to prevent stale reads after mutations

### Consistency
- **[REQUIRED]** Declare consistency requirement per write path: `strong` | `eventual` | `causal` — with rationale
  - Strong: linearizable reads required (e.g. inventory reservation, financial debit)
  - Eventual: lag is acceptable, convergence guaranteed (e.g. analytics counters, search indexes)
  - Causal: ordering matters within a session but not globally (e.g. comment threads)
- **[Advisory]** If switching from strong to eventual consistency on an existing path: this is an ADR-level decision — flag and confirm before proceeding

### Failure Modes
- **[REQUIRED]** For every external dependency: document what fails when it is unavailable, the timeout strategy, and the fallback behavior (circuit breaker / graceful degradation / hard fail)
- **[Advisory]** Consider idempotent retries for any network call to an external service

### API Contracts
- **[REQUIRED]** All mutation endpoints (POST / PUT / PATCH / DELETE) must declare idempotency key support — see api-standards.md Idempotency section
- **[Advisory]** For collections expected to grow unbounded: use cursor-based pagination, not offset-based
- **[Advisory]** If read and write patterns diverge significantly: consider CQRS — separate read model optimized for queries, write model enforcing invariants

### Events and Command Handlers

- **[REQUIRED]** For every event published: declare delivery guarantee (at-least-once | exactly-once | at-most-once), ordering guarantee (none | per-partition | global), and consumer model (consumer-group | broadcast).
- **[REQUIRED]** If delivery guarantee is at-least-once: consumer handler MUST be idempotent. Document the deduplication strategy (commandId-store, event-id-store, db-unique-constraint, or natural idempotency).
- **[REQUIRED]** If a command handler publishes events AND modifies state: use the transactional outbox pattern — write state + outbox row in one transaction; relay publishes from outbox. Eliminates dual-write failure (DDIA Ch 11).
- **[Advisory]** For async command dispatch: include commandId (UUID v4) in the command envelope. Handlers check commandId against a dedup store (TTL ≥ 24h or broker retention window) before executing.
- **[Advisory]** "Exactly-once" is a broker-level claim — treat consumers as at-least-once in practice; handler idempotency is still required.

### Knowledge Base
DDIA-significant decisions — why a consistency model was chosen, why a partition key was selected, why a transaction boundary was drawn — belong in the unit knowledge base, not just in architecture.md.
Record the *why*, not the *what* (the what is in the code and specs).

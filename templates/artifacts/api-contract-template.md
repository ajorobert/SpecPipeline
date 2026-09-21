---
unit: {unit-id}
intent: {intent-id}
version: v1
status: draft | approved
created: {date}
updated: {date}
---

# API Contract: {unit-name}

Human-readable companion to the machine artifacts in `contracts/`
(`api-spec.json` is the canonical OpenAPI source; this document explains it).
Do NOT invent endpoints here that are absent from `contracts/api-spec.json` —
keep the two in sync.

## Communication Overview
<!-- One paragraph: which projects talk to which, over what protocol (REST / event / command).
     Reference impact-analysis.md → Cross-Project Contracts. -->

## Endpoints
| Method | Path | Description | Auth | Idempotency-Key |
|--------|------|-------------|------|-----------------|
<!-- Mirror contracts/api-spec.json. Idempotency-Key = required on every POST/PUT/PATCH/DELETE. -->

## Request / Response Shapes
<!-- Per endpoint: request body, success response, and the documented error responses
     (the project's error-result → HTTP mapping, per api-standards.md). Reference the schema names from api-spec.json. -->

## Events
<!-- Published and consumed events for this unit (mirror contracts/README.md → Events sections).
     If none: "None". -->

## Consumers
<!-- Which impacted project consumes which endpoints/events. One sub-list per consumer project.
     Only list endpoints that consumer actually calls. Mirror contracts/test-plan.md consumer sections. -->

## Versioning & Breaking-Change Policy
<!-- How this contract evolves. Breaking changes add a versioned endpoint; never mutate in place. -->

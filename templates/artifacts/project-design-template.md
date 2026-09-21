---
project: {project-name}
project_type: Backend | Frontend | Mobile
code_root: {code-root-path}
unit: {unit-id}
intent: {intent-id}
status: draft | approved
created: {date}
updated: {date}
---

# Project Design: {project-name}

Per-project slice of this unit's design. Synthesises the project-relevant parts of
`architecture.md`, `database-design.md`, and `api-contract.md` into a single page the
implementing team can work from. This is a VIEW over the canonical design docs — it
references them, it does not redefine boundaries, schema, or endpoint ownership.

Source: `unit-brief.md` → Impacted Projects (this project's row).

## Role in this Unit
<!-- Copy the "Role in this unit" cell from unit-brief.md, then expand to one short paragraph. -->

## Scope of Change
<!-- new project work | modify existing | config-only. What this project must build for the unit. -->

## Design Slice
<!-- Backend: endpoints owned, handlers/commands/queries, entities touched, security (auth/RBAC/ABAC),
     consistency + outbox per write path, external dependencies + failure modes.
     Frontend/Mobile: routes/screens, components, state homes, consumed endpoints (from api-contract.md),
     fetch strategy, accessibility targets, loading/empty/error states.
     Reference the canonical doc for each item (architecture.md §, database-design.md §, api-contract.md §). -->

## Contracts This Project Touches
<!-- Endpoints/events this project produces or consumes. Link to api-contract.md rows.
     Frontend/Mobile: every consumed field must exist in contracts/api-spec.json. -->

## Stories Covered
<!-- - [{story-id}] {title}: {what this project delivers for the story} -->

## Open Questions
<!-- Project-specific unknowns. Missing-contract items must name the endpoint and flag the architect. -->

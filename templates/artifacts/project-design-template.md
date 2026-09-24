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
`architecture.md`, `database-design.md`, and `contract-changes.md` into a single page the
implementing team can work from. This is a VIEW over the canonical design docs — it
references them and the canonical spec operations; it does not redefine boundaries, schema, or
operation ownership.

Source: `unit-brief.md` → Impacted Projects (this project's row).

## Role in this Unit
<!-- Copy the "Role in this unit" cell from unit-brief.md, then expand to one short paragraph. -->

## Scope of Change
<!-- new project work | modify existing | config-only. What this project must build for the unit. -->

## Design Slice
<!-- Backend: operations owned, handlers/commands/queries, entities touched, security (auth/RBAC/ABAC),
     consistency per write path, external dependencies + failure modes.
     Frontend/Mobile: routes/screens, components, state homes, consumed operations (from contract-changes.md),
     fetch strategy, accessibility targets, loading/empty/error states.
     Reference the source for each item (architecture.md §, database-design.md §, the canonical spec operation). -->

## Contracts This Project Touches
<!-- Operations/channels this project produces or consumes, as listed in 02-design/contract-changes.md,
     each with its canonical file (specs/openapi/{audience}.yaml, specs/asyncapi/{module}.yaml).
     Frontend/Mobile: every consumed field must exist in the canonical spec. -->

## Stories Covered
<!-- - [{story-id}] {title}: {what this project delivers for the story} -->

## Open Questions
<!-- Project-specific unknowns. Missing-contract items must name the operation and flag the architect. -->

---
name: sk.design_sub_datamodel
description: "INTERNAL sub-skill of sk.design. Never invoke directly or in response to a user request — only when sk.design's prompt.md directs it. Designs data entities, schema strategy, and access patterns for a unit. Role: architect. Reads: 02-design/architecture.md, specs/domain/bounded-contexts.md + the owning specs/domain/{module}.md, the existing entity code, specs/adr/adr-index.md → routed ADRs, .specify/memory/constitution.md, .claude/skills/README.md (design packs). Writes: 02-design/database-design.md, specs/domain/{module}.md (domain invariants and rationale)."
subagent_type: SpecKit Architect Agent
inject_files:
  - .specify/memory/constitution.md
  - specs/adr/adr-index.md
  - specs/domain/bounded-contexts.md
---

Defines data model for a unit. ONE document per unit.
Requires active_unit_id in .specify/state/session.yaml and 02-design/architecture.md to exist.

Internal sub-skill — invoked by sk.design. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.

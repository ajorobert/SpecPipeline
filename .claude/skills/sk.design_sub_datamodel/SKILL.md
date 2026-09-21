---
name: sk.design_sub_datamodel
description: "INTERNAL sub-skill of sk.design. Never invoke directly or in response to a user request — only when sk.design's prompt.md directs it. Designs data entities, schema strategy, and access patterns for a unit. Role: architect. Reads: 02-design/architecture.md, domain-model.md, data-standards.md, skill-routing.md (design packs). Writes: 02-design/database-design.md, domain-model.md (updated)."
subagent_type: SpecKit Architect Agent
inject_files:
  - .specify/memory/standards/data-standards.md
  - .specify/memory/domain-model.md
---

Defines data model for a unit. ONE document per unit.
Requires active_unit_id in session.yaml and 02-design/architecture.md to exist.

Internal sub-skill — invoked by sk.design. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.

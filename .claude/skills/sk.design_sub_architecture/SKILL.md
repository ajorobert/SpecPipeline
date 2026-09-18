---
name: sk.design_sub_architecture
description: "INTERNAL sub-skill of sk.design. Never invoke directly or in response to a user request — only when sk.design's prompt.md directs it. Defines service boundaries, bounded contexts, and design for a unit. Role: architect. Reads: unit-brief.md, 01-story/, domain-model.md, service-registry.md, architecture-decisions.md, skill-routing.md (design packs). Writes: 02-design/architecture.md, 02-design/impact-analysis.md, knowledge-base.md."
subagent_type: SpecKit Architect Agent
inject_files:
  - .specify/memory/architecture-decisions.md
  - .specify/memory/domain-model.md
  - .specify/memory/service-registry.md
---

Defines service boundaries and design for a unit. ONE document per unit — covers all stories.
Requires active_unit_id in session.yaml.

Internal sub-skill — invoked by sk.design. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.

---
name: sk.design_sub_architecture
description: "INTERNAL sub-skill of sk.design. Never invoke directly or in response to a user request — only when sk.design's prompt.md directs it. Defines service boundaries, bounded contexts, and design for a unit. Role: architect. Reads: unit-brief.md, 01-story/, specs/domain/bounded-contexts.md + the relevant specs/domain/{module}.md, specs/adr/adr-index.md → routed ADRs, .specify/memory/projects/index.md, .specify/memory/constitution.md, .claude/skills/README.md (design packs). Writes: 02-design/architecture.md, 02-design/impact-analysis.md, knowledge-base.md, specs/domain/bounded-contexts.md + specs/domain/{module}.md (new bounded context only)."
subagent_type: SpecKit Architect Agent
inject_files:
  - .specify/memory/constitution.md
  - .specify/memory/projects/index.md
  - specs/adr/adr-index.md
  - specs/domain/bounded-contexts.md
---

Defines service boundaries and design for a unit. ONE document per unit — covers all stories.
Requires active_unit_id in .specify/state/session.yaml.

Internal sub-skill — invoked by sk.design. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.

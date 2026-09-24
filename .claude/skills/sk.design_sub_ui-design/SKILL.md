---
name: sk.design_sub_ui-design
description: "INTERNAL sub-skill of sk.design. Never invoke directly or in response to a user request — only when sk.design's prompt.md directs it. Designs the frontend surface for a unit — route/page tree, component architecture, state placement, API-consumption contracts, performance and accessibility strategy. Role: frontend. Reads: 02-design/architecture.md, 02-design/contract-changes.md (operations + consumer test-plan sections), the canonical specs/openapi|asyncapi operations it lists, unit-brief.md, 01-story/, .specify/memory/projects/index.md (Type), .specify/memory/projects/{Project}/tech-stack.md (Platform), specs/domain/bounded-contexts.md, .claude/skills/README.md (packs). Writes: 02-design/ui-model.md, 02-design/projects/{Frontend/Mobile project}.md."
subagent_type: SpecKit Frontend Engineer Agent
inject_files:
  - .specify/memory/projects/index.md
  - specs/domain/bounded-contexts.md
---

Defines the frontend UI model for a unit — page/route tree, component decomposition, state architecture, API-consumption types, performance and accessibility strategy. ONE document per unit — covers the frontend surface for all stories.

Consumes the architecture and the canonical contract operations the architect already changed. Does NOT redefine service boundaries, schema, or which operations exist — it elaborates how the frontend is structured and how it consumes those contracts. Framework-specific rules come from the project's registered frontend packs and its `.claude/rules/`, never from this skill.

Internal sub-skill — invoked by sk.design Phase 6 when frontend signals are present. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.

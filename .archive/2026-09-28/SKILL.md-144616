---
name: sk.design_sub_contracts
description: "INTERNAL sub-skill of sk.design. Never invoke directly or in response to a user request — only when sk.design's prompt.md directs it. Edits the canonical API contracts in place on the feature branch and records the change list, compatibility classes, verification and provider/consumer test plan for a unit. Role: architect. Reads: 02-design/architecture.md, 02-design/database-design.md, unit-brief.md, specs/openapi/{audience}.yaml, specs/asyncapi/{module}.yaml, .specify/profile.yaml (contracts.*), .specify/memory/projects/index.md, specs/adr/adr-index.md → routed ADRs, .specify/memory/constitution.md, .claude/skills/README.md (design packs). Writes: specs/openapi/{audience}.yaml, specs/asyncapi/{module}.yaml, 02-design/contract-changes.md, 02-design/projects/{BackendProject}.md."
subagent_type: SpecKit Architect Agent
inject_files:
  - .specify/memory/constitution.md
  - .specify/memory/projects/index.md
  - specs/adr/adr-index.md
---

Edits the canonical contracts for a unit and records what changed.
Requires 02-design/architecture.md and 02-design/database-design.md to exist.

Internal sub-skill — invoked by sk.design. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.

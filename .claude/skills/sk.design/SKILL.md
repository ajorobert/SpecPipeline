---
name: sk.design
description: "Invoke when: running the full design pipeline for a unit in one shot. Role: architect (orchestrator). Invokes: sk.design_sub_architecture → [review gate] → sk.design_sub_datamodel → [review gate] → sk.design_sub_contracts in sequence. Each sub-skill runs in its own isolated context."
subagent_type: SpecKit Architect Agent
inject_files:
  - .claude/skills/governance/checkpoint-rules.md
  - .specify/memory/system-context.md
  - .specify/memory/architecture-decisions.md
  - .specify/memory/domain-model.md
  - .specify/memory/service-registry.md
preconditions:
  - "file_contains: {unit_dir}/unit-brief.md :: ^[|][^|]+[|][[:space:]]*(Backend|Frontend|Mobile)[[:space:]]*[|]"
---

Orchestrator skill — full design pipeline for a unit.
Invokes sk.design_sub_architecture -> sk.design_sub_datamodel -> sk.design_sub_contracts in sequence.
Auto-generates the unit guide.yaml index after completion.
Each sub-skill runs in its own isolated context. Review gates enforced between phases.

Read and execute the full workflow in `prompt.md` in this directory.

---
name: sk.design
description: "Invoke when: running the full design pipeline for a unit in one shot. Role: architect (orchestrator). Dispatches with the Agent tool, one worker at a time: sk.design_sub_architecture → [review gate] → sk.design_sub_datamodel → [review gate] → sk.design_sub_contracts → [review gate] → sk.design_sub_ui-design (frontend units). Gates and ADRs stay with this orchestrator. Reads: .specify/state/session.yaml, unit-brief.md, 01-story/, specs/adr/adr-index.md, specs/domain/bounded-contexts.md, .specify/memory/projects/index.md. Writes: unit guide.yaml (sub-skills write 02-design/)."
subagent_type: SpecKit Architect Agent
inject_files:
  - .claude/skills/governance/checkpoint-rules.md
  - .specify/memory/projects/index.md
  - specs/adr/adr-index.md
  - specs/domain/bounded-contexts.md
preconditions:
  - "file_contains: {unit_dir}/unit-brief.md :: ^[|][^|]+[|][[:space:]]*(Backend|Frontend|Mobile)[[:space:]]*[|]"
---

Orchestrator skill — full design pipeline for a unit.
Dispatches sk.design_sub_architecture -> sk.design_sub_datamodel -> sk.design_sub_contracts in sequence
with the Agent tool, then sk.design_sub_ui-design when the unit has a user-facing surface.
Writes the unit guide.yaml index after completion.
Each worker runs in a forked context and returns a short report (`governance/worker-dispatch.md`). Review gates run in the orchestrator, between phases — a worker cannot talk to a human.

Read and execute the full workflow in `prompt.md` in this directory.

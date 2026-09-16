---
name: sk.implement
description: "Invoke when: executing the implementation phase for a unit, producing one delivery folder per impacted project. Role: lead (orchestrator). Runs at unit level. Invokes: sk.implementproject (for each impacted project). Produces 04-implementation/{Project}/ (implementation.md, progress.md, validation.md) per impacted project. Reads: session.yaml, unit-brief.md, 02-design/**, 03-plan/{Project}/ (plan.md, tasks.md, checklist.md), coding-standards.md."
subagent_type: SpecKit Lead Agent
inject_files:
  - .claude/skills/governance/checkpoint-rules.md
  - .specify/memory/standards/tech-stack.md
preconditions:
  - "story.checkpoint_mode in [autopilot, confirm, validate]"
  - "file_exists: {unit_dir}/03-plan/*/plan.md"
  - "when story.checkpoint_mode in [confirm, validate] => file_contains: {unit_dir}/03-plan/*/plan.md :: ^status:[[:space:]]*approved"
---

Orchestrator skill — full implementation pipeline for a unit.
Invokes `sk.implementproject` for each impacted project (from the unit's Impacted Projects table),
each consuming that project's `03-plan/{Project}/` and producing a delivery folder under
`04-implementation/{Project}/`. Each sub-skill runs in its own isolated context — state is passed
via the file system (session.yaml + spec/plan artifacts).

Requires `03-plan/{Project}/plan.md` for each targeted project (approved when checkpoint_mode is
confirm or validate). Refine mode activated per project if a `review-{story-id}.md` exists.

Read and execute the full workflow in `prompt.md` in this directory.

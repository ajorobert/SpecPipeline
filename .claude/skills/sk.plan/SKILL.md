---
name: sk.plan
description: "Invoke when: creating a technical implementation plan. Role: lead (orchestrator). Runs at unit level. Invokes: sk.plan_sub_planproject (for each impacted project) → sk.plan_sub_analyze. Produces 03-plan/{Project}/ (plan.md, tasks.md, checklist.md, jira-subtask.md, estimation.md) per impacted project. Reads: session.yaml, 02-design/architecture.md, 02-design/impact-analysis.md, 02-design/database-design.md, 02-design/api-contract.md, contracts/api-spec.json, tech-stack.md."
subagent_type: SpecKit Lead Agent
inject_files:
  - .claude/skills/governance/checkpoint-rules.md
  - .specify/memory/standards/tech-stack.md
preconditions:
  - "file_contains: {unit_dir}/unit-brief.md :: ^[|][^|]+[|][[:space:]]*(Backend|Frontend|Mobile)[[:space:]]*[|]"
---

Orchestrator skill — full planning pipeline for a unit.
Invokes sk.plan_sub_planproject for each impacted project (from the unit's Impacted Projects table),
then sk.plan_sub_analyze to validate constraints. Output is one execution-plan folder per project under
`03-plan/{Project}/`. Each sub-skill runs in its own isolated context.

Read and execute the full workflow in `prompt.md` in this directory.

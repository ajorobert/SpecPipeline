---
name: sk.plan_sub_planproject
description: "INTERNAL sub-skill of sk.plan. Never invoke directly or in response to a user request — only when sk.plan's prompt.md directs it. Creates the execution plan folder (plan.md, tasks.md, checklist.md, jira-subtask.md, estimation.md) for ONE impacted project of a unit. Role: lead | backend | frontend | mobile."
subagent_type: SpecKit Lead Agent
inject_files:
  - .specify/memory/standards/tech-stack.md
  - .specify/memory/standards/coding-standards.md
---

Creates the per-project execution plan for a single impacted project of a unit.
Aggregates all of the unit's stories' work that touches that one project into
`03-plan/{Project}/` (plan.md, tasks.md, checklist.md, jira-subtask.md, estimation.md).

Internal sub-skill — invoked by the sk.plan orchestrator, once per impacted project.
Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.

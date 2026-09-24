---
name: sk.plan_sub_planproject
description: "INTERNAL sub-skill of sk.plan. Never invoke directly or in response to a user request — only when sk.plan's prompt.md directs it. Creates the execution plan folder (plan.md, tasks.md, checklist.md, jira-subtask.md, estimation.md) for ONE impacted project of a unit. Role: lead | backend | frontend | mobile. Reads: 02-design/ (architecture.md, impact-analysis.md, projects/{Project}.md, database-design.md, contract-changes.md, ui-model.md), the canonical specs/openapi|asyncapi operations contract-changes.md lists, .specify/memory/projects/{Project}/tech-stack.md (refreshed when older than 90 days), specs/adr/adr-index.md → routed ADRs, .specify/memory/constitution.md, .claude/skills/README.md (packs). Writes: 03-plan/{Project}/, tech-stack.md (refresh only)."
subagent_type: SpecKit Lead Agent
inject_files:
  - .specify/memory/constitution.md
  - specs/adr/adr-index.md
---

Creates the per-project execution plan for a single impacted project of a unit.
Aggregates all of the unit's stories' work that touches that one project into
`03-plan/{Project}/` (plan.md, tasks.md, checklist.md, jira-subtask.md, estimation.md).

Internal sub-skill — invoked by the sk.plan orchestrator, once per impacted project.
Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.

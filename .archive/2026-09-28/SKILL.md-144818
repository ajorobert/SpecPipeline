---
name: sk.implement_sub_scaffolding
description: "INTERNAL sub-skill of sk.implement. Never invoke directly or in response to a user request — only when the sk.implement pipeline directs it. Performs structural scaffolding (creating files, classes, stubs, test fixtures) for ONE project within its {CodeRoot}, with no business logic. Runs contracts.codegen from .specify/profile.yaml when set. Role: backend | frontend | mobile. Reads: 03-plan/{Project}/ (plan.md, tasks.md), 02-design/ (architecture.md, projects/{Project}.md, contract-changes.md → canonical specs/openapi|asyncapi operations, database-design.md, ui-model.md), specs/domain/{module}.md of the touched contexts, .specify/memory/projects/{Project}/tech-stack.md, the project's .claude/rules/{stack}/ (rules.stacks), specs/adr/adr-index.md → routed ADRs, .specify/memory/constitution.md, .claude/skills/README.md (implement packs). Writes: {CodeRoot}, 04-implementation/{Project}/progress.md."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .specify/memory/constitution.md
  - specs/adr/adr-index.md
---

Structural scaffolding step for one impacted project of a unit.
Creates classes, interfaces, DTOs, stubs, and test fixtures within the project's {CodeRoot} — no
business logic. Consumes `03-plan/{Project}/tasks.md`; tracks status in `04-implementation/{Project}/progress.md`.

Internal sub-skill — invoked by sk.implement_sub_implementproject (once per project). Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.

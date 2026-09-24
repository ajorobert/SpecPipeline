---
name: sk.implement_sub_implementproject
description: "INTERNAL sub-skill of sk.implement. Never invoke directly or in response to a user request — only when sk.implement's prompt.md directs it. Executes the implementation for ONE impacted project of a unit: scaffolds then generates code within {CodeRoot} from 03-plan/{Project}/, and writes the 04-implementation/{Project}/ delivery docs. Invokes with the Skill tool: sk.implement_sub_scaffolding → sk.implement_sub_codegen. Role: lead | backend | frontend | mobile. Reads: 03-plan/{Project}/, 02-design/ (contract-changes.md → canonical specs/openapi|asyncapi operations), .specify/memory/projects/{Project}/tech-stack.md, the project's .claude/rules/{stack}/ (rules.stacks), specs/adr/adr-index.md → routed ADRs, .specify/memory/constitution.md. Writes: {CodeRoot}, 04-implementation/{Project}/."
subagent_type: SpecKit Lead Agent
inject_files:
  - .specify/memory/constitution.md
  - specs/adr/adr-index.md
---

Executes the implementation for a single impacted project of a unit.
Reads that project's approved plan (`03-plan/{Project}/`), runs structural scaffolding then code
generation within the project's `{CodeRoot}` (each invoked with the Skill tool), and writes the delivery-tracking docs
(implementation.md, progress.md, validation.md) to `04-implementation/{Project}/`.

Internal sub-skill — invoked by the sk.implement orchestrator, once per impacted project.
Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.

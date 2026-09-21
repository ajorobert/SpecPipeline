---
name: sk.implement_sub_codegen
description: "INTERNAL sub-skill of sk.implement. Never invoke directly or in response to a user request — only when the sk.implement pipeline directs it. Implements business logic inside stubs created by sk.implement_sub_scaffolding for ONE project within its {CodeRoot}. Role: backend | frontend | mobile."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .specify/memory/standards/coding-standards.md
  - .specify/memory/standards/observability-standards.md
  - .specify/memory/architecture-decisions.md
---

Business logic implementation step for one impacted project of a unit.
Implements the rules, conditions, transformations, and validations inside the structures scaffolded
within the project's {CodeRoot}. Executes `03-plan/{Project}/tasks.md`; tracks status in
`04-implementation/{Project}/progress.md`.

Internal sub-skill — invoked by sk.implement_sub_implementproject (once per project). Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.

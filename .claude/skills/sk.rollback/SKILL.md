---
name: sk.rollback
description: "Invoke when: reverting a shipped story — automated or manual rollback plan. Role: lead. Reads: session.yaml, 01-story/story.md, 03-plan/{Project}/plan.md, skill-routing.md (## Migrations). Writes: rollback-plan.md (unit root). Hard block: requires shipped story."
subagent_type: SpecKit Lead Agent
disable-model-invocation: true
inject_files:
  - .specify/memory/standards/data-standards.md
  - .specify/memory/architecture-decisions.md
  - .specify/memory/service-registry.md
preconditions:
  - story.status.current == shipped
---

Revert a shipped story — automated or manual rollback plan.
Requires story status = shipped (or explicitly overridden). Produces step-by-step rollback-plan.md covering code, migrations, config, and dependent services.

Read and execute the full workflow in `prompt.md` in this directory.

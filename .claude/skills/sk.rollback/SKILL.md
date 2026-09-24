---
name: sk.rollback
description: "Invoke when: reverting a shipped story — automated or manual rollback plan. Role: lead. Reads: .specify/state/session.yaml, .specify/profile.yaml (vcs.*), 01-story/story.md, unit-brief.md, 03-plan/{Project}/plan.md, 02-design/contract-changes.md, promotion.md, .specify/memory/projects/index.md, the schema-owning project's tech-stack.md (## Migrations), specs/adr/adr-index.md → routed ADRs, .specify/memory/constitution.md. Writes: rollback-plan.md (unit root, allowed in the frozen unit); status.current → rolled-back via story-status.sh. Hard block: requires shipped story."
subagent_type: SpecKit Lead Agent
disable-model-invocation: true
inject_files:
  - .specify/profile.yaml
  - specs/adr/adr-index.md
preconditions:
  - story.status.current == shipped
---

Revert a shipped story — automated or manual rollback plan.
Requires story status = shipped. Produces a step-by-step rollback-plan.md covering code, migrations, config,
promoted knowledge and dependent consumers, and moves the story to `rolled-back` when the rollback completes.

Read and execute the full workflow in `prompt.md` in this directory.

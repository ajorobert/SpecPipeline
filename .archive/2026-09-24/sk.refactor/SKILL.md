---
name: sk.refactor
description: "Invoke when: scoped technical debt resolution without full spec artifacts. Role: backend or frontend. Reads: .specify/state/session.yaml, .specify/memory/projects/index.md, 02-design/architecture.md, the project's .claude/rules/{stack}/ (rules.stacks), specs/adr/adr-index.md → routed ADRs, .specify/memory/constitution.md, .claude/skills/README.md (refactor packs). Writes: the target project's {CodeRoot}, refactor-plan.md. No new behaviour introduced."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .specify/memory/constitution.md
  - specs/adr/adr-index.md
  - .specify/memory/projects/index.md
---

Scoped refactor — no new behaviour, no spec artifacts required.
Role determines agent: backend → SpecKit Backend Engineer Agent, frontend → SpecKit Frontend Engineer Agent.
Requires a clearly scoped target area. Writes refactor-plan.md before touching code.

Read and execute the full workflow in `prompt.md` in this directory.

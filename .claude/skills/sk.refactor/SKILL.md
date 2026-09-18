---
name: sk.refactor
description: "Invoke when: scoped technical debt resolution without full spec artifacts. Role: backend or frontend. Reads: session.yaml, 02-design/architecture.md, coding-standards.md, skill-routing.md (refactor packs). Writes: the target project's {CodeRoot}, refactor-plan.md. No new behaviour introduced."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .specify/memory/standards/coding-standards.md
  - .specify/memory/standards/observability-standards.md
  - .specify/memory/architecture-decisions.md
---

Scoped refactor — no new behaviour, no spec artifacts required.
Role determines agent: backend → SpecKit Backend Engineer Agent, frontend → SpecKit Frontend Engineer Agent.
Requires a clearly scoped target area. Writes refactor-plan.md before touching code.

Read and execute the full workflow in `prompt.md` in this directory.

---
name: sk.hotfix
description: "Invoke when: P0 incident fast path — emergency fix to production. Role: lead. Reads: .specify/state/session.yaml, .specify/profile.yaml (vcs.*), 01-story/, 02-design/architecture.md, specs/adr/adr-index.md → routed ADRs, .specify/memory/constitution.md, the project's .claude/rules/{stack}/, .specify/memory/projects/{Project}/tech-stack.md. Writes: 03-plan/{Project}/hotfix-plan.md (also in a frozen unit), source within {CodeRoot}, fix branch and PR per vcs.*. 3-gate: plan → implement → ship (no full spec cycle)."
subagent_type: SpecKit Lead Agent
disable-model-invocation: true
inject_files:
  - .specify/profile.yaml
  - specs/adr/adr-index.md
---

P0 incident fast path. Bypasses sk.design (architecture / data model / contracts).
3 hard gates: plan → implement → ship.
Requires a hotfix story (story_type: hotfix) as the active story.

Read and execute the full workflow in `prompt.md` in this directory.

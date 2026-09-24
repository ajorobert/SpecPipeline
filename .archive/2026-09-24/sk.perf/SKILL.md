---
name: sk.perf
description: "Invoke when: performance profiling and optimization — load test results or profiler output → diagnosis → tasks. Role: backend or frontend. Reads: .specify/state/session.yaml, profiler output, .specify/memory/projects/index.md, 02-design/architecture.md, the project's .claude/rules/{stack}/ (rules.stacks), specs/adr/adr-index.md → routed ADRs, .claude/skills/README.md (perf packs). Writes: 04-implementation/{Project}/perf-findings.md, perf-tasks.md."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - specs/adr/adr-index.md
  - .specify/memory/projects/index.md
---

Performance profiling and optimization cycle.
Input: load test results or profiler output (required). Output: diagnosis, prioritised tasks, and measurable acceptance criteria.
Role determines agent: backend → SpecKit Backend Engineer Agent, frontend → SpecKit Frontend Engineer Agent.

Read and execute the full workflow in `prompt.md` in this directory.

---
name: sk.perf
description: "Invoke when: performance profiling and optimization — load test results or profiler output → diagnosis → tasks. Role: backend or frontend. Reads: session.yaml, profiler output, 02-design/architecture.md, skill-routing.md (perf packs). Writes: 04-implementation/{Project}/perf-findings.md, perf-tasks.md."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .specify/memory/standards/observability-standards.md
---

Performance profiling and optimization cycle.
Input: load test results or profiler output (required). Output: diagnosis, prioritised tasks, and measurable acceptance criteria.
Role determines agent: backend → SpecKit Backend Engineer Agent, frontend → SpecKit Frontend Engineer Agent.

Read and execute the full workflow in `prompt.md` in this directory.

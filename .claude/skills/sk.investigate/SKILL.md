---
name: sk.investigate
description: "Invoke when: debugging a story, finding root causes, or classifying bugs as implementation bugs vs spec/contract mismatches. Role: backend or frontend (required). Reads: .specify/state/session.yaml, 01-story/, 02-design/contract-changes.md and the canonical specs/openapi|asyncapi operations it lists, 03-plan/{Project}/plan.md, specs/adr/adr-index.md → routed ADRs, specs/domain/{module}.md of the touched contexts. Writes: investigation-report.md (unit root), knowledge-base.md (candidate invariants — promotion moves them to their home at ship)."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - specs/adr/adr-index.md
---

Spec-aware root-cause debugging. Role determines agent: backend → SpecKit Backend Engineer Agent, frontend → SpecKit Frontend Engineer Agent.
Classifies findings: Implementation Bug vs Spec/Contract Mismatch.

Read and execute the full workflow in `prompt.md` in this directory.

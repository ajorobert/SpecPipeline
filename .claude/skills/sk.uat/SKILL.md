---
name: sk.uat
description: "Invoke when: performing user acceptance testing for a unit against its acceptance criteria, across every impacted user-facing surface. Role: frontend-qa. Runs at unit level. Reads: session.yaml, unit-brief.md, skill-routing.md (## Surfaces), 01-story acceptance criteria, 02-design/contracts/test-plan.md consumer sections, knowledge-base.md. Writes: 06-uat/ (acceptance-result.md, user-flow-test.md, signoff.md) and the unit story test-status."
subagent_type: QA Frontend Agent
inject_files:
  - .claude/skills/governance/checkpoint-rules.md
  - .specify/memory/standards/tech-stack.md
---

User Acceptance Testing for a unit against its acceptance criteria, across every impacted user-facing
surface (every Frontend/Mobile project). Frontend only — backend uses sk.test for contract and
integration tests.

Produces the flat `06-uat/` folder for the unit (not per-project): `acceptance-result.md`,
`user-flow-test.md`, `signoff.md`. Validates business rules, acceptance criteria, end-user workflow,
and records the final approval. Tooling per surface comes from `.specify/memory/skill-routing.md` →
`## Surfaces` (native surfaces never use browser tooling).

Read and execute the full workflow in `prompt.md` in this directory.

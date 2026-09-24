---
name: sk.uat
description: "Invoke when: performing user acceptance testing for a unit against its acceptance criteria, across every impacted user-facing surface. Role: frontend-qa. Runs at unit level. Reads: .specify/state/session.yaml, unit-brief.md (Impacted Projects rows of Type Frontend/Mobile), .specify/memory/projects/{Project}/tech-stack.md (Platform, E2E Tooling), 01-story acceptance criteria, 02-design/contract-changes.md consumer sections, 02-design/ui-model.md, knowledge-base.md. Writes: 06-uat/ (acceptance-result.md, user-flow-test.md, signoff.md); uat-status and test-status via story-status.sh."
subagent_type: QA Frontend Agent
inject_files:
  - .claude/skills/governance/checkpoint-rules.md
  - .specify/memory/projects/index.md
---

User Acceptance Testing for a unit against its acceptance criteria, across every impacted user-facing
surface (every Impacted Projects row of Type Frontend or Mobile). Frontend only — backend uses sk.test
for contract and integration tests.

Produces the flat `06-uat/` folder for the unit (not per-project): `acceptance-result.md`,
`user-flow-test.md`, `signoff.md`. Validates business rules, acceptance criteria, end-user workflow,
and records the final approval. Tooling per surface comes from the project's tech-stack.md
**Platform** and **E2E Tooling** (native surfaces never use browser tooling; `E2E Tooling: none` runs a
documented manual/assisted walk-through). Results reach the story through `story-status.sh`, never by
editing its frontmatter.

Read and execute the full workflow in `prompt.md` in this directory.

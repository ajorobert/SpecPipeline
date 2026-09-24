---
name: sk.test
description: "Invoke when: generating and running the test suite for a unit, producing one test folder per impacted project. Role: lead (orchestrator). Runs at unit level. Invokes with the Skill tool: sk.test_sub_testproject (once per impacted project). Produces 05-test/{Project}/ — Backend: unit-test.md, integration-test.md, contract-test.md; Frontend/Mobile: component-test.md, contract-test.md. Reads: .specify/state/session.yaml, .specify/profile.yaml (contracts.verify), unit-brief.md, knowledge-base.md, 02-design/contract-changes.md, the canonical specs/openapi|asyncapi files it lists, 01-story acceptance criteria, .specify/memory/projects/{Project}/tech-stack.md."
subagent_type: SpecKit Lead Agent
inject_files:
  - .claude/skills/governance/checkpoint-rules.md
  - .specify/memory/projects/index.md
rubric:
  name: test-coverage
  checks:
    - every acceptance criterion maps to at least one E2E, integration or component test
    - no skipped or focused tests (Forbidden Skip Idioms per the project's tech-stack.md) without a documented reason
    - contract verification covers every operation in 02-design/contract-changes.md (contracts.verify when set, otherwise provider contract tests)
    - every consumed changed operation has a consumer contract test
    - coverage thresholds met where the project's tech-stack.md declares them
    - all tests pass
preconditions:
  - "file_contains: {unit_dir}/unit-brief.md :: ^[|][^|]+[|][[:space:]]*(Backend|Frontend|Mobile)[[:space:]]*[|]"
---

Orchestrator skill — full testing phase for a unit.
Invokes `sk.test_sub_testproject` with the Skill tool for each impacted project (from the unit's
Impacted Projects table), each consuming that project's design slice + the unit's contract change list
and producing a test folder under `05-test/{Project}/`. Each sub-skill runs in its own isolated
context — state is passed via the file system (session.yaml + spec/design/plan artifacts).

Per project type the worker produces:
- **Backend** → `unit-test.md`, `integration-test.md`, `contract-test.md` (provider contracts, or the
  `contracts.verify` result when the profile sets it)
- **Frontend / Mobile** → `component-test.md`, `contract-test.md` (consumer contracts)

Each folder documents test cases, expected results, provider/consumer contracts, and regression
checks; the runnable tests themselves are written at each project's Test Layout under its `{CodeRoot}`.

Read and execute the full workflow in `prompt.md` in this directory.

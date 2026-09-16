---
name: sk.test
description: "Invoke when: generating and running the test suite for a unit, producing one test folder per impacted project. Role: lead (orchestrator). Runs at unit level. Invokes: sk.testproject (for each impacted project). Produces 05-test/{Project}/ — Backend: unit-test.md, integration-test.md, contract-test.md; Frontend/Mobile: component-test.md, contract-test.md. Reads: session.yaml, unit-brief.md, knowledge-base.md, 02-design/contracts/ (api-spec.json, test-plan.md), 01-story acceptance criteria, tech-stack.md."
subagent_type: SpecKit Lead Agent
inject_files:
  - .claude/skills/governance/checkpoint-rules.md
  - .specify/memory/standards/tech-stack.md
rubric:
  name: test-coverage
  checks:
    - every acceptance criterion maps to at least one E2E or integration test
    - no skipped or focused tests (Forbidden Skip Idioms per the project's tech-stack.md) without a documented reason
    - contract tests exist for every endpoint in api-spec.json
    - idempotency replay test present for non-idempotent operations
    - coverage threshold met per coding-standards.md
    - all tests pass
---

Orchestrator skill — full testing phase for a unit.
Invokes `sk.testproject` for each impacted project (from the unit's Impacted Projects table),
each consuming that project's design slice + the unit contracts and producing a test folder under
`05-test/{Project}/`. Each sub-skill runs in its own isolated context — state is passed via the
file system (session.yaml + spec/design/plan artifacts).

Per project type the worker produces:
- **Backend** → `unit-test.md`, `integration-test.md`, `contract-test.md` (provider contracts)
- **Frontend / Mobile** → `component-test.md`, `contract-test.md` (consumer contracts)

Each folder documents test cases, expected results, provider/consumer contracts, and regression
checks; the runnable tests themselves are written at each project's Test Layout under its `{CodeRoot}`.

Read and execute the full workflow in `prompt.md` in this directory.

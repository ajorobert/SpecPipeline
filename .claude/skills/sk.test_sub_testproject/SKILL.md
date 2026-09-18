---
name: sk.test_sub_testproject
description: "INTERNAL sub-skill of sk.test. Never invoke directly or in response to a user request — only when sk.test's prompt.md directs it. Generates and runs the test suite for ONE impacted project of a unit: writes runnable tests within {CodeRoot}'s test tree and the 05-test/{Project}/ test-design docs (Backend: unit-test.md, integration-test.md, contract-test.md; Frontend/Mobile: component-test.md, contract-test.md). Role: backend | frontend | mobile."
subagent_type: QA Backend Agent
inject_files:
  - .specify/memory/standards/tech-stack.md
  - .specify/memory/standards/coding-standards.md
---

Generates and runs the test suite for a single impacted project of a unit.
Reads that project's design slice (`02-design/projects/{Project}.md`), the unit contracts
(`02-design/contracts/`), and what was actually built (`04-implementation/{Project}/`), then writes
runnable tests inside the project's `{CodeRoot}` test tree and the test-design / tracking docs to
`05-test/{Project}/`.

Per project type the worker produces under `05-test/{Project}/`:
- **Backend** → `unit-test.md`, `integration-test.md`, `contract-test.md` (provider contracts)
- **Frontend / Mobile** → `component-test.md`, `contract-test.md` (consumer contracts)

For Frontend/Mobile projects, adopt the QA Frontend Agent testing perspective (consumer contracts,
component/UI behaviour, accessibility) even though the worker's default persona is QA Backend Agent.

Internal sub-skill — invoked by the sk.test orchestrator, once per impacted project.
Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.

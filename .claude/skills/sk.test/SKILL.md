---
name: sk.test
description: "Test one implemented project of a unit (--projects <name>): write and run its unit, integration, component and contract tests against the acceptance criteria and the canonical contracts, and record one test report."
role: qa
rubric:
  name: test-coverage
  checks:
    - every acceptance criterion maps to at least one E2E, integration or component test
    - no skipped or focused tests (the project's Forbidden Skip Idioms) without a documented reason
    - contract verification covers every operation in 02-design/contract-changes.md (contracts.verify when set, otherwise provider contract tests)
    - every consumed changed operation has a consumer contract test
    - coverage thresholds met where the project's tech-stack.md declares them
    - all tests pass
preconditions:
  - "file_contains: {unit_dir}/unit-brief.md :: ^[|][^|]+[|][[:space:]]*(Backend|Frontend|Mobile)[[:space:]]*[|]"
---

# sk.test
Tests one project of the unit, in one session, as QA. Runnable tests go into the project's Test Layout
under `{CodeRoot}`; the record is `05-test/{Project}/test-report.md`. Run it once per impacted project,
Backend first (consumers are tested against a verified provider), each in a fresh session.

## Invocation
- `sk.test --projects <name>` — test that project. `--refine` — repair only the failing tests.

## Pre-flight
Run `.claude/skills/governance/preflight.md` with command `test --projects <name>`. Read from the project's
tech-stack.md: Test Runner, Test Layout, Forbidden Skip Idioms, E2E Tooling, Coverage Thresholds. A field
set to `none` makes its step log `SKIP — {field}: none`; never invent a tool. A missing field: follow the
existing test tree and say the field should be filled in.

## Steps
1. **Scope** — the project's design page, contract-changes.md and delivery.md say what this project owns
   and what was built. Test only that; never invent an operation or field the spec lacks.
2. **Tests** — `steps/test-project.md`.
3. **Run** — the Test Runner; record pass/fail per case, coverage against the thresholds, and flag every
   changed operation without contract coverage and every acceptance criterion without a test.
4. **Gate — Tests** (`.claude/skills/governance/review-gate.md`; pauses in confirm and validate). Show
   test-report.md. Check for: the test-coverage rubric above; every `none` logged as SKIP, never
   replaced by an invented tool; no test contradicts the spec or what was built. Autopilot: the result
   decides.

## Rules
- Never change the implementation or the spec to make a test pass; a defect or a mismatch is a finding.
- Inspect the existing test tree first and match its framework, layout and fixtures; keep passing tests.
- Tests run without manual setup; names describe scenarios.

## Completion report and signal
```
sk.test — {unit-id} / {Project}
Cases: {written} written, {green} green, {red} red   Coverage: {value | SKIP}
Contract: {contracts.verify PASS | provider tests n/n | consumer tests n/n}
Projects still to test: {names | none}
Next: /sk.test --projects {next} — or, when none is left, /sk.review --projects {first} — in a fresh session
```
Last line, exactly one of:
- `SK_RESULT: PASS` — this suite is green and every other impacted project's test report says `result: PASS`
- `SK_RESULT: PARTIAL` — this suite is green; other projects are still to test
- `SK_RESULT: FAIL` — this suite has failures

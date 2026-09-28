# sk.test_sub_testproject
Generates and runs the test suite for ONE impacted project of a unit.
Role: backend | frontend | mobile (from the project type) | Level: project

Internal sub-skill — invoked by the sk.test orchestrator with the Skill tool, once per impacted project.
Do not invoke directly.

## What "one project" means
A unit may impact several projects (for example one Backend API, a customer web surface, an admin web
surface and a mobile app). This sub-skill tests exactly ONE of them, named `{Project}` with code root
`{CodeRoot}`. It generates and runs the tests that verify that project's slice of the unit. It does NOT
test the other projects.

The orchestrator passes the target project as `{Project}` / `{CodeRoot}` / `{ProjectType}`, the
effective `--role`, and the execution mode, resolved from `unit-brief.md` → Impacted Projects.

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `test`,
in-scope project = `{Project}` (`{ProjectType}`), working text = story + `03-plan/{Project}/plan.md` Test Plan.

## Input Artifacts
Resolve `UNIT_DIR = specs/intents/{intent}/units/{unit}/`, `DESIGN_DIR = UNIT_DIR/02-design/`,
`IMPL_DIR = UNIT_DIR/04-implementation/{Project}/`, `TEST_DIR = UNIT_DIR/05-test/{Project}/`.

- DESIGN_DIR/contract-changes.md                     (operations touched, compatibility class, Verification,
                                                      and the Provider / Consumer test plan — primary source)
- The canonical `specs/openapi/{audience}.yaml` / `specs/asyncapi/{module}.yaml` — only the files and
  operations `contract-changes.md` lists (`governance/profile.md` → Loading rules)
- DESIGN_DIR/projects/{Project}.md                   (if exists — the per-project design slice)
- DESIGN_DIR/architecture.md                         (system architecture)
- DESIGN_DIR/database-design.md                      (if exists — DB/data model; Backend)
- DESIGN_DIR/ui-model.md                             (if exists — REQUIRED for Frontend/Mobile)
- UNIT_DIR/03-plan/{Project}/plan.md                 (if exists — its Test Plan section)
- IMPL_DIR/implementation.md, validation.md          (if exists — what was actually built)
- UNIT_DIR/01-story/ story.md, requirement.md, acceptance-criteria.md  (the unit's story)
- UNIT_DIR/knowledge-base.md                         (if exists — tier 3 invariants inform test design)
- `.specify/profile.yaml` → `contracts.verify`
- `.specify/memory/projects/{Project}/tech-stack.md` → **Test Runner**, **Test Layout**, **Forbidden Skip
  Idioms**, **E2E Tooling**, **Coverage Thresholds** (`.claude/skills/governance/project-resolution.md`)
- The project's `.claude/rules/{stack}/` folders (mapped by `rules.stacks`) — test conventions the
  project has written down

## Pre-flight
1. Verify the target `{Project}` appears in `unit-brief.md` → Impacted Projects (with `{CodeRoot}`).
   Missing: STOP — report "Project {Project} is not an impacted project of this unit."
2. Verify DESIGN_DIR/contract-changes.md exists.
   Missing: WARN — proceed against acceptance criteria only, and flag the contract gap.
3. For a Frontend or Mobile project, verify DESIGN_DIR/ui-model.md exists.
   Missing: WARN — proceed, but flag that the component plan is unanchored.
4. Read the project's tech-stack fields listed above.
   - A field set to `none` → the step that needs it logs `SKIP — {field}: none` and is not a failure.
     Never invent a tool, runner or threshold. `Test Runner: none` means runnable tests cannot be
     executed here: write them where a Test Layout kind exists, log the SKIP, and record the suite
     result as `not run`.
   - A field missing (not `none`) → inspect the existing test tree under `{CodeRoot}`, follow what is
     there, and WARN that the tech-stack.md field should be filled in (sk.init → tech-stack).
5. Determine execution mode:
   - **REFINE** if the orchestrator passed REFINE, OR `TEST_DIR` exists with documented failing cases —
     repair/regenerate only the failing tests; keep passing ones.
   - **RESUME** if `TEST_DIR` exists with open (unwritten) cases — continue from the first open case.
   - **CREATE** otherwise — full suite.

## Output Layout
Two destinations — keep them distinct:
- **Runnable tests** are written inside `{CodeRoot}` at the locations the project's Test Layout declares
  (unit, integration, contract, component, e2e). A kind whose layout is `none` logs
  `SKIP — Test Layout {kind}: none`. Never write runnable tests under `05-test/`.
- **Test-design / tracking docs** are written under `UNIT_DIR/05-test/{Project}/`:

**Backend project:**
```
05-test/{Project}/
├── unit-test.md         # unit-level cases + expected results
├── integration-test.md  # service + database/pipeline integration cases + expected results
└── contract-test.md     # PROVIDER side: contracts.verify result, or one provider test per changed operation; regression checks
```

**Frontend / Mobile project:**
```
05-test/{Project}/
├── component-test.md     # component / UI / screen cases + expected results (a11y where applicable)
└── contract-test.md      # CONSUMER contracts: the operations and fields this surface depends on + regression checks
```

`{Project}` is the exact project name from the Impacted Projects table. Do NOT invent or abbreviate it.

## Execution

### 1. Scope the project slice
Read `02-design/projects/{Project}.md` (if present), `02-design/contract-changes.md`, and
`04-implementation/{Project}/` first — they define what THIS project owns and what was actually built.
Everything tested MUST stay inside this slice — do not write tests for behaviour another project owns,
and do not invent operations or fields that are not in the canonical contract.

### 2A. Backend — generate the three docs + runnable tests
Read `contract-changes.md` → Operations and `### Provider ({Project})`, and the listed operations in the
canonical spec (inventory each operation's responses and error codes).

- **unit-test.md** — unit cases for the code units the project implements for this slice. Each case: id,
  scenario, given, expected result. Cover happy path, validation errors, boundary values, and any
  invariant from knowledge-base.md. Map cases to the code under test.
- **integration-test.md** — service + database / request-pipeline integration cases for the project's
  write and read paths. Each case: id, scenario, given, expected result. State explicitly which cases
  are **N/A by construction** with the reason, per the Provider test plan.
- **contract-test.md** — PROVIDER side:
  - **`contracts.verify` set** → run the command from the repo root. Record the command, exit code, date
    and a summary of the output, and map each operation in `contract-changes.md` to the check that covers
    it. A non-zero exit is FAIL. Do not write provider tests that duplicate what the command proves.
  - **`contracts.verify` unset** → one row per operation in `contract-changes.md` (happy path, error
    cases and auth cases from the Provider test plan), plus negative assertions for any operation the
    change list marks `removed`.
  - Either way, end with a **Regression checks** section: the existing behaviour that must keep passing
    after this change.

Then write the runnable tests under `{CodeRoot}` at the Test Layout: provider contract tests (only when
`contracts.verify` is unset — one per changed operation, asserting against the canonical spec),
integration tests (one per scenario), and unit tests alongside the project's existing unit-test layout —
in the project's test framework and naming convention.

### 2B. Frontend / Mobile — generate the two docs + runnable tests
Read `contract-changes.md` → the `### Consumer ({Project})` section and the canonical operations it names
(identify the fields this surface consumes).

- **component-test.md** — component / screen / UI cases mapped to acceptance criteria: rendering,
  state, form behaviour, error/empty/loading states, and accessibility expectations (per any
  accessibility pack loaded in Step 0 or the project's rules). Each case: id, scenario, given, expected
  result, AC mapped.
- **contract-test.md** — CONSUMER contract: the operations and fields this surface depends on (each
  confirmed present in the canonical spec — never invent one), the mocked backend responses used, and
  the error states the Consumer section says must be handled. End with a **Regression checks** section.

Then write the runnable tests under `{CodeRoot}` at the Test Layout: consumer contract tests (backend
mocked from the canonical spec's responses), component tests, and — if the platform runs E2E here
rather than in sk.uat — E2E tests mapped to acceptance criteria, using the project's tech-stack
**E2E Tooling**. `E2E Tooling: none` → log `SKIP — E2E Tooling: none` and map those criteria to
component or integration tests instead.

### 3. Run the suite
Run the project's tests with its **Test Runner** (`none` → `SKIP — Test Runner: none`, suite result
`not run`). Record pass/fail per case in the relevant doc. Flag any operation in `contract-changes.md`
with no provider/consumer coverage, and any acceptance criterion with no mapped test.

### 4. Roll up
At the bottom of each doc, record the suite result (cases written, green/red/not run, coverage vs the
tech-stack **Coverage Thresholds** — `none` → `SKIP — Coverage Thresholds: none`). Report the project's
overall PASS/FAIL to the orchestrator; a logged SKIP is not a FAIL, a `contracts.verify` failure is.

## Doc front-matter
Every doc under `05-test/{Project}/` starts with:
```
---
project: {Project}
project_type: {Backend | Frontend | Mobile}
code_root: {CodeRoot}
unit: {unit-id}
intent: {intent-id}
role: {backend | frontend | mobile}
created: {today}
updated: {today}
---
```

## IMPORTANT Test Rules (enforced)
- Do NOT modify the implementation under test to make a test pass — tests verify behaviour, they do not
  reshape it. A genuine defect is reported as a finding, not patched here.
- Do NOT edit the canonical spec to make a test pass — a contract mismatch is a finding.
- MUST inspect the existing test tree before adding — match the established framework, layout, and
  fixtures (per tech-stack.md and the project's `.claude/rules/{stack}/`). Do not rewrite passing tests.
- Tests must run without manual setup; test names describe scenarios, not implementation.
- Never invent an operation, field or tool that is not in the canonical contract or the tech stack.
- No skipped or focused tests (the project's Forbidden Skip Idioms) without a documented reason.

## Quality Bar
- Tests exactly ONE project; writes runnable tests only within `{CodeRoot}` at its Test Layout; writes docs
  only within `05-test/{Project}/`.
- Stays inside the project's design/contract slice — no behaviour belonging to another project.
- Backend: every operation in `contract-changes.md` is covered by the `contracts.verify` result or a
  provider contract test; integration cases cover service+DB/pipeline; N/A cases are justified.
- Frontend/Mobile: every consumed changed operation has a consumer contract test (all present in the
  canonical contract); component cases map to acceptance criteria; accessibility covered.
- Consumers expect only what the canonical contract guarantees.
- Every `none` tech-stack field produced a `SKIP — {field}: none` line, never a substitute tool.
- Regression checks present in every contract doc; coverage thresholds met where declared.
- All required test docs written for the project type (Backend: 3; Frontend/Mobile: 2).

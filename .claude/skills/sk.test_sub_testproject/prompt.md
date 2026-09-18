# sk.test_sub_testproject
Generates and runs the test suite for ONE impacted project of a unit.
Role: backend | frontend | mobile (from the project type) | Level: project

Internal sub-skill — invoked by the sk.test orchestrator, once per impacted project.
Do not invoke directly.

## What "one project" means
A unit may impact several projects (for example one Backend API, a customer web surface, an admin web
surface and a mobile app). This sub-skill tests exactly ONE of them, named `{Project}` with code root
`{CodeRoot}`. It generates and runs the tests that verify that project's slice of the unit. It does NOT
test the other projects.

The orchestrator passes the target project as `{Project}` / `{CodeRoot}` / `{ProjectType}` and the
effective `--role`, resolved from `unit-brief.md` → Impacted Projects.

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `test`,
in-scope project = `{Project}` (`{ProjectType}`), signals = story tags + `03-plan/{Project}/plan.md` Test Plan.

## Input Artifacts
Resolve `UNIT_DIR = specs/intents/{intent}/units/{unit}/`, `DESIGN_DIR = UNIT_DIR/02-design/`,
`IMPL_DIR = UNIT_DIR/04-implementation/{Project}/`, `TEST_DIR = UNIT_DIR/05-test/{Project}/`.

- DESIGN_DIR/contracts/test-plan.md                  (provider/consumer test plan — primary source)
- DESIGN_DIR/contracts/api-spec.json                 (canonical machine API contract)
- DESIGN_DIR/projects/{Project}.md                   (if exists — the per-project design slice)
- DESIGN_DIR/architecture.md                         (system architecture)
- DESIGN_DIR/database-design.md                      (if exists — DB/data model; Backend)
- DESIGN_DIR/ui-model.md                             (if exists — REQUIRED for Frontend/Mobile)
- UNIT_DIR/03-plan/{Project}/plan.md                 (if exists — its Test Plan section)
- IMPL_DIR/implementation.md, validation.md          (if exists — what was actually built)
- UNIT_DIR/01-story/ story.md, requirement.md, acceptance-criteria.md  (the unit's story)
- UNIT_DIR/knowledge-base.md                         (if exists — tier 3 invariants inform test design)
- The project's tech-stack.md (test framework, **Test Layout**, **Forbidden Skip Idioms**) and
  coding-standards.md (coverage thresholds) — resolved per `.claude/skills/governance/project-resolution.md`

## Pre-flight
1. Verify the target `{Project}` appears in `unit-brief.md` → Impacted Projects (with `{CodeRoot}`).
   Missing: STOP — report "Project {Project} is not an impacted project of this unit."
2. Verify DESIGN_DIR/contracts/test-plan.md exists (or api-spec.json).
   Missing: WARN — proceed against acceptance criteria only, and flag the contract gap.
3. For a Frontend or Mobile project, verify DESIGN_DIR/ui-model.md exists.
   Missing: WARN — proceed, but flag that the component plan is unanchored.
4. Read the project's Test Layout and Forbidden Skip Idioms from its tech-stack.md.
   Missing: inspect the existing test tree under `{CodeRoot}`, follow what is there, and WARN that the
   tech-stack.md fields should be filled in (sk.init → tech-stack).
5. Determine execution mode:
   - **REFINE** if the orchestrator passed REFINE, OR `TEST_DIR` exists with documented failing cases —
     repair/regenerate only the failing tests; keep passing ones.
   - **RESUME** if `TEST_DIR` exists with open (unwritten) cases — continue from the first open case.
   - **CREATE** otherwise — full suite.

## Output Layout
Two destinations — keep them distinct:
- **Runnable tests** are written inside `{CodeRoot}` at the locations the project's Test Layout declares
  (unit, integration, contract, component, e2e). Never write runnable tests under `05-test/`.
- **Test-design / tracking docs** are written under `UNIT_DIR/05-test/{Project}/`:

**Backend project:**
```
05-test/{Project}/
├── unit-test.md         # unit-level cases (handlers, mappers, validators, identity projection) + expected results
├── integration-test.md  # service + database/pipeline integration cases + expected results
└── contract-test.md     # PROVIDER contracts: every endpoint in api-spec.json + regression checks
```

**Frontend / Mobile project:**
```
05-test/{Project}/
├── component-test.md     # component / UI / screen cases + expected results (a11y where applicable)
└── contract-test.md      # CONSUMER contracts: endpoints/claims/session fields this surface depends on + regression checks
```

`{Project}` is the exact project name from the Impacted Projects table. Do NOT invent or abbreviate it.

## Execution

### 1. Scope the project slice
Read `02-design/projects/{Project}.md` (if present), `02-design/contracts/test-plan.md`, and
`04-implementation/{Project}/` first — they define what THIS project owns and what was actually built.
Everything tested MUST stay inside this slice — do not write tests for behaviour another project owns,
and do not invent endpoints/claims not in the contract.

### 2A. Backend — generate the three docs + runnable tests
Read `test-plan.md` → Provider section and `api-spec.json` (inventory every endpoint + error code).

- **unit-test.md** — unit cases for the handlers, mappers, validators, and identity/claim projection
  the project implements. Each case: id, scenario, given, expected result. Cover happy path, validation
  errors, boundary values, and any invariant from knowledge-base.md. Map cases to the code under test.
- **integration-test.md** — service + database / request-pipeline integration cases (e.g. middleware
  chain, the project's write and read data paths, outbox/saga where applicable). Each case: id, scenario,
  given, expected result. State explicitly which cases are **N/A by construction** (e.g. no mutation
  endpoints → no idempotency-replay/outbox cases) with the reason, per test-plan.md.
- **contract-test.md** — PROVIDER contract: one row per endpoint in api-spec.json (happy path, auth
  rejection 401, authorization rejection 403, validation error, not-found, boundary), plus negative /
  anti-fabrication assertions (routes that must NOT exist). End with a **Regression checks** section:
  the existing behaviour that must keep passing after this change.

Then write the runnable tests under `{CodeRoot}` at the Test Layout: provider contract tests (one per
endpoint), integration tests (one per scenario), and unit tests alongside the project's existing unit-test
layout — in the project's test framework and naming convention.

### 2B. Frontend / Mobile — generate the two docs + runnable tests
Read `test-plan.md` → the `### {Project}` consumer section and `api-spec.json` (identify the
fields/claims this surface consumes).

- **component-test.md** — component / screen / UI cases mapped to acceptance criteria: rendering,
  state, form behaviour, error/empty/loading states, and accessibility expectations (per any
  accessibility pack loaded in Step 0, else WCAG 2.2 AA / platform guidelines). Each case: id, scenario,
  given, expected result, AC mapped.
- **contract-test.md** — CONSUMER contract: the endpoints, claims, and session fields this surface
  depends on (each confirmed present in api-spec.json — never invent one), the mocked backend responses
  used, and error-handling expectations (generic non-enumerating copy, 401 handling, no partial
  session). End with a **Regression checks** section.

Then write the runnable tests under `{CodeRoot}` at the Test Layout: consumer contract tests (backend
mocked from api-spec.json responses), component tests, and — if the platform runs E2E here rather than in
sk.uat — E2E tests mapped to acceptance criteria, using the surface's E2E tooling from
`.specify/memory/skill-routing.md` → `## Surfaces`.

### 3. Run the suite
Run the project's tests. Record pass/fail per case in the relevant doc. Flag any endpoint in
api-spec.json with no provider/consumer test, and any acceptance criterion with no mapped test.

### 4. Roll up
At the bottom of each doc, record the suite result (cases written, green/red, coverage vs the
coding-standards.md threshold). Report the project's overall PASS/FAIL to the orchestrator.

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
- MUST inspect the existing test tree before adding — match the established framework, layout, and
  fixtures (per tech-stack.md / coding-standards.md). Do not rewrite passing tests.
- Tests must run without manual setup; test names describe scenarios, not implementation.
- Never invent an endpoint, claim, or field that is not in api-spec.json.
- No skipped or focused tests (the project's Forbidden Skip Idioms) without a documented reason.

## Quality Bar
- Tests exactly ONE project; writes runnable tests only within `{CodeRoot}` at its Test Layout; writes docs
  only within `05-test/{Project}/`.
- Stays inside the project's design/contract slice — no behaviour belonging to another project.
- Backend: every endpoint in api-spec.json has a provider contract test; integration cases cover
  service+DB/pipeline; unit cases cover handlers/mappers/validators; N/A cases are justified.
- Frontend/Mobile: every consumed endpoint/claim has a consumer contract test (all present in the
  contract); component cases map to acceptance criteria; accessibility covered.
- Provider contracts (backend) and consumer contracts (frontend/mobile) agree — consumers expect only
  what the provider contract guarantees.
- Regression checks present in every contract doc; coverage threshold per coding-standards.md met.
- All required test docs written for the project type (Backend: 3; Frontend/Mobile: 2).

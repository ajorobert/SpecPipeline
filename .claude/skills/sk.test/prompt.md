# sk.test — Testing Pipeline (Orchestrator)
Orchestrates the testing phase for a unit, producing one test folder per impacted project.
Role: lead (orchestrator) | Level: unit

This skill orchestrates the per-project test worker. It resolves the impacted projects from the
unit's Impacted Projects table, invokes `sk.testproject` once per project (each consuming that
project's design slice plus the unit's `02-design/contracts/`), and gates the result before
reporting. Each sub-skill runs in its own isolated context. Orchestrators do not resolve capability
packs — each worker resolves its own (phase = test).

## Test Output Layout
All test-design / test-tracking artifacts for the unit live under
`specs/intents/{intent}/units/{unit}/05-test/{Project}/` (tree: `.claude/skills/governance/phase-layout.md`),
one folder per impacted project:
- Backend projects: `unit-test.md`, `integration-test.md`, `contract-test.md` (PROVIDER contracts)
- Frontend / Mobile projects: `component-test.md`, `contract-test.md` (CONSUMER contracts)

Folder names are the project names from `unit-brief.md` (the same names used for `02-design/projects/`,
`03-plan/` and `04-implementation/`). The runnable tests are written at each project's **Test Layout**
(declared in its tech-stack.md) under its `{CodeRoot}`, NOT under `05-test/`.

## Invocation Forms
- `sk.test`                                   — test ALL impacted projects that have an implementation
- `sk.test --role {role} --projects {key}`    — test exactly ONE project (TARGETED)
- `sk.test --projects {key}`                  — test one project; infer `--role` from project type
- `sk.test --refine`                          — re-run test generation only, for projects whose tests failed

`--role` is one of `backend | frontend | mobile`. `--projects` is resolved per
`.claude/skills/governance/project-resolution.md` (exact name or the `api | web | admin | mobile` aliases).

When no `--projects` is given, the target set is EVERY row in the Impacted Projects table that has an
implementation under `04-implementation/{Project}/` (or, if implementation tracking is absent, an
approved plan under `03-plan/{Project}/`).

## Pre-flight
1. Run the unit pre-flight in `.claude/skills/governance/preflight.md` (session focus, UNIT_DIR/DESIGN_DIR/
   IMPL_DIR/TEST_DIR, Impacted Projects, `checkpoint_mode` from `01-story/story.md`, knowledge bases —
   tier 3 invariants inform test design).
2. Verify `DESIGN_DIR/contracts/test-plan.md` and `DESIGN_DIR/contracts/api-spec.json` exist.
   Missing: WARN — proceed, but flag that contract tests are unanchored (sk.design --contracts not run).
3. Read the unit's story under `01-story/` to know the acceptance criteria the tests must cover.

## Mode Detection and Resume Logic
Determine mode based on arguments and existing files. First match wins.

**TARGETED** (`--projects {key}`, with or without `--role`)
- Resolve the project (project-resolution.md).
- Run Phase 1 for that one project only (resume/overwrite its `05-test/{Project}/` folder).
- Run Phase 2 (Review Gate) and report.

**REFINE** (`--refine`, OR a project's `05-test/{Project}/` reports failing tests)
- For each in-scope project whose last run reported failures: invoke `sk.testproject` in REFINE mode
  (regenerate/repair only the failing tests; do not discard passing ones).
- Run Phase 2 (Review Gate) and report.

**NORMAL / RESUME** (no flags)
- Let `P` = every project in the Impacted Projects table that has an implementation
  (`04-implementation/{Project}/`) or an approved plan (`03-plan/{Project}/plan.md`).
- For each project in `P`:
  - If `05-test/{Project}/` is missing or reports open/failing cases: run Phase 1 for it.
  - If `05-test/{Project}/` is complete (all cases written, suite green): skip it (log "already tested").
- Run Phase 2 (Review Gate) and report.

Projects in the Impacted Projects table with NO implementation and NO approved plan are skipped and
logged with a reason (`no implementation — run sk.implement --projects {key}`).

## Orchestration

### Phase 1 — Per-Project Testing
Condition: run for the project(s) determined by Mode Detection.
For each target project `{Project}` (with `{CodeRoot}`, `{ProjectType}` from the resolved row):
Invoke skill: `sk.testproject`
- Pass: `{Project}`, `{CodeRoot}`, `{ProjectType}`, the effective `--role`
  (backend for Backend, frontend for Frontend, mobile for Mobile), and the execution mode
  (NORMAL or REFINE).
- Context injected: `02-design/contracts/test-plan.md`, `02-design/contracts/api-spec.json`,
  `02-design/projects/{Project}.md` (if exists), `02-design/architecture.md`,
  `02-design/database-design.md` (if exists), `02-design/ui-model.md` (if exists — Frontend/Mobile),
  `03-plan/{Project}/plan.md` → Test Plan (if exists), `04-implementation/{Project}/` (if exists —
  what was actually built), the unit's story under `01-story/`, `UNIT_DIR/knowledge-base.md`,
  and the project's tech-stack.md.
- Waits for: `05-test/{Project}/` containing the per-type test docs (Backend: unit-test.md,
  integration-test.md, contract-test.md; Frontend/Mobile: component-test.md, contract-test.md), and
  the actual runnable tests written at the project's Test Layout under `{CodeRoot}`.
- Subagents are isolated from each other. Backend provider contracts are the source of truth for
  Frontend/Mobile consumer contracts — if both run, honor that direction; independent projects may
  run in parallel.

### Phase 2 — Review Gate
Protocol: `.claude/skills/governance/review-gate.md`. Active for `confirm` and `validate` when any project
was tested this run; per-project approval (`approved {Project} …`) is allowed.
Review: every `05-test/{Project}/` folder just generated/updated, with each project's cases written,
suite PASS/FAIL/n green, AC covered/total and endpoints covered.
Check for:
  - Every endpoint in api-spec.json has a provider contract test (backend projects)
  - Every consumed endpoint/claim has a consumer contract test (frontend/mobile projects)
  - Every acceptance criterion maps to at least one integration/component/E2E test
  - Regression checks present and passing; no Forbidden Skip Idioms without a documented reason
  - No test contradicts the api-spec.json contract or the implementation actually built
  - test-coverage rubric (this skill's SKILL.md) is satisfied
Approval effect: set `test-status` in `01-story/story.md` frontmatter — `pass` only if EVERY in-scope
project's suite is green; otherwise `fail` with the failing projects noted.
Autopilot: roll up `test-status` automatically from the per-project results (pass iff all green) and log it.

## Completion Report
After the pipeline completes, display:
```
sk.test complete.
Unit: {unit-id}
Mode: {NORMAL/RESUME | TARGETED | REFINE}

Phases run:
  Phase 1 (Projects: {list of {Project}})
  Phase 2 (Review Gate)

Test folders written:
  {list 05-test/{Project}/ folders, each with its per-type test docs}

Test roots touched:
  {list each project's Test Layout under {CodeRoot}}

Projects skipped:
  {list impacted projects not tested this run, with reason: no implementation | already tested | not targeted}

Results: {per project — suite PASS/FAIL/n green, AC covered/total, endpoints covered/total}

Roll-up: test-status = {pass | fail}

Next step: /sk.uat (user-facing surfaces) or /sk.security-audit
```

## Quality Bar
- Mode is detected and logged at the start — never ambiguous.
- The impacted-project list is sourced from `unit-brief.md`; every impacted project is either tested
  or explicitly logged as skipped with a reason.
- `--projects` resolution is logged; `--role`/type conflicts STOP rather than guess.
- Each `sk.testproject` invocation is self-contained — no state leaks between projects.
- Tests realize `02-design/contracts/` and the unit's acceptance criteria — the orchestrator does not
  redesign contracts or invent endpoints.
- Existing tests are never discarded on REFINE; only failing cases are repaired.
- Active gates must receive explicit 'approved' before `test-status` changes; skipped gates are logged.
- 'cancel' at the gate preserves all artifacts and tests written up to that point.
- `test-status` rolls up honestly — `pass` only when every in-scope project's suite is green.
- Completion report lists only what actually ran and what was skipped, with reasons.

## Completion Signal
Last line of output must be exactly one of:
`SK_RESULT: PASS` — all in-scope projects' suites passed
`SK_RESULT: FAIL` — one or more projects have failing or missing required tests

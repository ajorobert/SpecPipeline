# sk.test — Testing Pipeline (Orchestrator)
Orchestrates the testing phase for a unit, producing one test folder per impacted project.
Role: lead (orchestrator) | Level: unit

This skill orchestrates the per-project test worker. It resolves the impacted projects from the
unit's Impacted Projects table, dispatches `sk.test_sub_testproject` with the **Agent tool** once per
project — one at a time, per `.claude/skills/governance/worker-dispatch.md` — and gates the result
before reporting. Each worker runs in a forked context and returns only a short report, so this
window holds the reports and the gate, never the workers' working sets. The gate runs HERE: a worker
cannot talk to a human.
Orchestrators do not resolve capability packs — each worker resolves its own (phase = test).

## Test Output Layout
All test-design / test-tracking artifacts for the unit live under
`specs/intents/{intent}/units/{unit}/05-test/{Project}/` (tree: `.claude/skills/governance/phase-layout.md`),
one folder per impacted project:
- Backend projects: `unit-test.md`, `integration-test.md`, `contract-test.md` (PROVIDER contracts)
- Frontend / Mobile projects: `component-test.md`, `contract-test.md` (CONSUMER contracts)

Folder names are the project names from `unit-brief.md` (the same names used for `02-design/projects/`,
`03-plan/` and `04-implementation/`). The runnable tests are written at each project's **Test Layout**
(declared in `.specify/memory/projects/{Project}/tech-stack.md`) under its `{CodeRoot}`, NOT under `05-test/`.

## Contract verification (who does what)
The canonical contracts are `specs/openapi/{audience}.yaml` / `specs/asyncapi/{module}.yaml`, edited on
the feature branch; `02-design/contract-changes.md` lists the operations this unit touched.
- **`contracts.verify` set** in `.specify/profile.yaml` → the Backend project's worker runs that command
  and records the command, exit code and output summary in `05-test/{BackendProject}/contract-test.md`.
  It writes no provider contract tests of its own for what the command already proves.
- **`contracts.verify` unset** → the Backend project's worker writes and runs provider contract tests
  against the canonical operations listed in `contract-changes.md` (one per operation).
- **Consumers** — each Frontend/Mobile worker writes consumer contract tests from its own
  `### Consumer ({Project})` section of `contract-changes.md`, against the canonical operations.

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
   IMPL_DIR/TEST_DIR, Impacted Projects, `checkpoint_mode` from `01-story/story.md`, knowledge,
   `.specify/profile.yaml` — tier 3 invariants inform test design).
2. Verify `DESIGN_DIR/contract-changes.md` exists.
   Missing: if the unit changes no contract, log `no contract changes — contract tests cover regression only`;
   otherwise WARN — proceed, but flag that contract tests are unanchored (sk.design contracts phase not run).
3. Note `contracts.verify` from the profile (set / unset) and log which contract path applies.
4. Read the unit's story under `01-story/` to know the acceptance criteria the tests must cover.

## Mode Detection and Resume Logic
Determine mode based on arguments and existing files. First match wins.

**TARGETED** (`--projects {key}`, with or without `--role`)
- Resolve the project (project-resolution.md).
- Run Phase 1 for that one project only (resume/overwrite its `05-test/{Project}/` folder).
- Run Phase 2 (Review Gate) and report.

**REFINE** (`--refine`, OR a project's `05-test/{Project}/` reports failing tests)
- For each in-scope project whose last run reported failures: invoke `sk.test_sub_testproject` in REFINE mode
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
Dispatch one worker per project, **one at a time**, per `.claude/skills/governance/worker-dispatch.md`:

1. `bash .claude/hooks/set-worker-role.sh sk.test_sub_testproject {qa-role}`
   Testing runs as QA, not as the engineer role: Backend → `backend-qa` / QA Backend Agent;
   Frontend and Mobile → `frontend-qa` / QA Frontend Agent. The static `subagent_type:` in the
   worker's SKILL.md is a default and is overridden here.
2. Dispatch `sk.test_sub_testproject` with the Agent tool and that agent, using the dispatch prompt in
   worker-dispatch.md with this project's parameter block (`{Project}`, `{CodeRoot}`, `{ProjectType}`,
   Role, `{UNIT_DIR}`), plus the execution mode (NORMAL or REFINE) and whether `contracts.verify` is
   set. The worker resolves its own inputs and packs from its prompt.md.
3. `bash .claude/hooks/set-worker-role.sh clear`

Keep the dispatch prompt's prefix byte-identical across projects — only the parameter block varies.
- Context the worker reads: `02-design/contract-changes.md` (operations + its Provider / Consumer test
  plan section), the canonical `specs/openapi|asyncapi` operations it lists,
  `02-design/projects/{Project}.md` (if exists), `02-design/architecture.md`,
  `02-design/database-design.md` (if exists), `02-design/ui-model.md` (if exists — Frontend/Mobile),
  `03-plan/{Project}/plan.md` → Test Plan (if exists), `04-implementation/{Project}/` (if exists —
  what was actually built), the unit's story under `01-story/`, `UNIT_DIR/knowledge-base.md`,
  the project's `tech-stack.md` and its `.claude/rules/{stack}/` folders.
- Waits for: `05-test/{Project}/` containing the per-type test docs (Backend: unit-test.md,
  integration-test.md, contract-test.md; Frontend/Mobile: component-test.md, contract-test.md), and
  the actual runnable tests written at the project's Test Layout under `{CodeRoot}`.
- Subagents are isolated from each other. The canonical contract is the source of truth for both
  sides; run the Backend project first when it is in scope, so consumer tests see the verified
  provider. Independent projects may run in parallel.

### Phase 2 — Review Gate
Protocol: `.claude/skills/governance/review-gate.md`. Active for `confirm` and `validate` when any project
was tested this run; per-project approval (`approved {Project} …`) is allowed.
Review: every `05-test/{Project}/` folder just generated/updated, with each project's cases written,
suite PASS/FAIL/n green, AC covered/total, operations covered/total, and any `SKIP — {field}: none` lines.
Check for:
  - Contract verification for every operation in `contract-changes.md`: the `contracts.verify` result
    (when set) or a provider contract test per operation (Backend project)
  - Every consumed changed operation has a consumer contract test (frontend/mobile projects)
  - Every acceptance criterion maps to at least one integration/component/E2E test
  - Regression checks present and passing; no Forbidden Skip Idioms without a documented reason
  - No test contradicts the canonical contract or the implementation actually built
  - Every `none` step is logged as `SKIP — {field}: none`, never replaced by an invented tool
  - test-coverage rubric (this skill's SKILL.md) is satisfied
Approval effect: the gate verdict decides the completion signal. `test-status` is written by the Stop
hook from this skill's `SK_RESULT` (`governance/status-model.md`) — `pass` only if EVERY in-scope
project's suite is green. Never edit story frontmatter.
Autopilot: derive the verdict automatically from the per-project results (PASS iff all green) and log it.

## Completion Report
After the pipeline completes, display:
```
sk.test complete.
Unit: {unit-id}
Mode: {NORMAL/RESUME | TARGETED | REFINE}
Contract verification: {contracts.verify: <command> → PASS/FAIL | provider contract tests}

Phases run:
  Phase 1 (Projects: {list of {Project}})
  Phase 2 (Review Gate)

Test folders written:
  {list 05-test/{Project}/ folders, each with its per-type test docs}

Test roots touched:
  {list each project's Test Layout under {CodeRoot}}

Projects skipped:
  {list impacted projects not tested this run, with reason: no implementation | already tested | not targeted}

Steps skipped (none-valued tech-stack fields):
  {SKIP — {field}: none, per project}

Results: {per project — suite PASS/FAIL/n green, AC covered/total, operations covered/total}

Roll-up: test-status = {pass | fail} (written by the Stop hook from SK_RESULT)

Next step: /sk.uat (user-facing surfaces) or /sk.security-audit
  Optional: a fresh session is cheap here (`.claude/skills/governance/session-boundaries.md`).
  Reorient with /sk.session status.
```

## Quality Bar
- Mode is detected and logged at the start — never ambiguous.
- The impacted-project list is sourced from `unit-brief.md`; every impacted project is either tested
  or explicitly logged as skipped with a reason.
- `--projects` resolution is logged; `--role`/type conflicts STOP rather than guess.
- Every worker is dispatched with the Agent tool, one at a time, as the QA role for its project type,
  markers set then cleared — never with the Skill tool, and never two in flight.
- The gate runs in this context; no gate or question is delegated to a worker.
- Worker reports carry paths, counts, failures and blockers only — no test source pasted back.
- Tests realize the canonical contract operations listed in `contract-changes.md` and the unit's
  acceptance criteria — the orchestrator does not redesign contracts or invent operations.
- A tech-stack field set to `none` is a logged SKIP, not a failure; no tool is ever invented.
- Existing tests are never discarded on REFINE; only failing cases are repaired.
- Active gates must receive explicit 'approved' before the verdict is emitted; skipped gates are logged.
- 'cancel' at the gate preserves all artifacts and tests written up to that point.
- `test-status` rolls up honestly — PASS only when every in-scope project's suite is green.
- Completion report lists only what actually ran and what was skipped, with reasons.

## Completion Signal
Last line of output must be exactly one of:
`SK_RESULT: PASS` — all in-scope projects' suites passed
`SK_RESULT: FAIL` — one or more projects have failing or missing required tests

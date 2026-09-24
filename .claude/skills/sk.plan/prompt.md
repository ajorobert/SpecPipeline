# sk.plan — Implementation Planning (Orchestrator)
Orchestrates technical planning for a unit, producing one execution-plan folder per impacted project.
Role: lead (orchestrator) | Level: unit

This skill orchestrates two internal workers. It prepares a planning brief, dispatches
`sk.plan_sub_planproject` once per impacted project (resolved from the unit's Impacted Projects table), and
runs `sk.plan_sub_analyze` at the end to catch cross-project / cross-artifact conflicts before implementation.

Every worker is dispatched with the **Agent tool**, one at a time, per
`.claude/skills/governance/worker-dispatch.md`: set the role markers, dispatch, clear the markers.
Each worker runs in its own forked context and returns only a short report, so this orchestrator's
window holds the brief, the reports and the gate — never the workers' working sets. Orchestrators do
not resolve capability packs — each worker resolves its own (phase = plan).

## Plan Output Layout
All plan artifacts for the unit live under `specs/intents/{intent}/units/{unit}/03-plan/{Project}/`
(tree: `.claude/skills/governance/phase-layout.md`), one folder per impacted project, each holding
`plan.md`, `tasks.md`, `checklist.md`, `jira-subtask.md` and `estimation.md`. Folder names are the
project names from `unit-brief.md` (the same names sk.design used for `02-design/projects/`).
`planning-brief.md` stays at the unit root (it is the orchestrator's cross-project synthesis).

## Invocation Forms
- `sk.plan`                                   — plan ALL impacted projects missing a plan.md, then analyze
- `sk.plan --role {role} --projects {key}`    — plan exactly ONE project (TARGETED), then analyze
- `sk.plan --projects {key}`                  — plan one project; infer `--role` from project type
- `sk.plan --analyze-only`                    — skip planning, just re-run analyze
- `sk.plan --refresh "{change}"`              — update brief with change, re-plan affected projects, analyze

`--role` is one of `backend | frontend | mobile`. `--projects` is resolved per
`.claude/skills/governance/project-resolution.md` (exact name or the `api | web | admin | mobile` aliases).

When no `--projects` is given, the target set is EVERY row in the Impacted Projects table.

## Pre-flight
1. Run the unit pre-flight in `.claude/skills/governance/preflight.md` (session focus, UNIT_DIR/DESIGN_DIR,
   Impacted Projects, `checkpoint_mode` from `01-story/story.md`, knowledge bases).
2. Verify `DESIGN_DIR/architecture.md` exists.
   Missing: STOP — run sk.design first.
3. Read `DESIGN_DIR/impact-analysis.md` (per-project blast radius + sequencing). If absent, fall
   back to the unit-brief Impacted Projects table and log the degraded source.
4. Read `DESIGN_DIR/contract-changes.md` (if exists) — the list of canonical operations this unit adds,
   changes or removes in `specs/openapi/{audience}.yaml` / `specs/asyncapi/{module}.yaml`. If absent,
   log `contract-changes.md not present — no contract change in this unit`.

## Mode Detection and Resume Logic
Determine mode based on arguments and existing files. First match wins.

**TARGETED** (`--projects {key}`, with or without `--role`)
- Skip Phase 0 (Planning Brief).
- Resolve the project (project-resolution.md).
- Run Phase 1 for that one project only (resume/overwrite its existing folder).
- Run Phase 2 (Analyze) and enter the Review Gate.

**TARGETED** (`--analyze-only`)
- Skip Phase 0 and Phase 1.
- Run Phase 2 (Analyze) and enter the Review Gate.

**REFRESH** (`--refresh "{change}"`)
- Run Phase 0 (Planning Brief) including the `{change}`.
- Run Phase 1 only for the projects affected by `{change}` (determine from the change text and
  impact-analysis.md; if ambiguous, re-plan all impacted projects and log the reasoning).
- Run Phase 2 (Analyze) and enter the Review Gate.

**NORMAL / RESUME** (no flags)
- If `planning-brief.md` is missing or empty: run Phase 0.
- Let `P` = every project in the Impacted Projects table.
- For each project in `P` missing `03-plan/{Project}/plan.md`: run Phase 1.
- Run Phase 2 (Analyze) and enter the Review Gate.

## Orchestration

### Phase 0 — Planning Brief
Condition: run in NORMAL/RESUME if missing; run in REFRESH. (Skipped in TARGETED.)
1. Read the unit's story (`01-story/`) and `impact-analysis.md` to identify what is shared.
2. Write `UNIT_DIR/planning-brief.md`:
   - **Recommended Execution Order across projects** — sequence the impacted projects using
     `impact-analysis.md` → Sequencing & Dependencies (e.g. "identity-provider configuration first;
     the backend pipeline and the user-facing surfaces can then proceed in parallel").
   - **Shared Infrastructure / Config Notes** — cross-project preconditions (e.g. "per-surface
     identity clients and the tenant claim mapping must exist before any surface integrates").
   - **Cross-Project Dependencies** — explicit linkages and their direction.
   *(In REFRESH mode, document the `{change}` and its per-project impact here as well.)*

### Phase 1 — Project Planning
Condition: run for the project(s) determined by Mode Detection.
For each target project `{Project}` (with `{CodeRoot}`, `{ProjectType}` from the resolved row):
Dispatch one worker per project, **one at a time**, per `.claude/skills/governance/worker-dispatch.md`:

1. `bash .claude/hooks/set-worker-role.sh sk.plan_sub_planproject`
   No role override. Planning artifacts live under `03-plan/**`, which only `lead` may write —
   overriding to the project's type would block the worker from its own output folder.
2. Dispatch `sk.plan_sub_planproject` with the Agent tool, using its `subagent_type:` and the dispatch
   prompt in worker-dispatch.md, with this project's parameter block (`{Project}`, `{CodeRoot}`,
   `{ProjectType}`, Role `lead`, `{UNIT_DIR}`). The worker resolves its own inputs from its
   prompt.md — do not restate them here.
3. `bash .claude/hooks/set-worker-role.sh clear`
4. Record the report. Expect `03-plan/{Project}/` to hold plan.md, tasks.md, checklist.md,
   jira-subtask.md and estimation.md; note any that is missing for the gate.

Keep the dispatch prompt's prefix byte-identical across projects — only the parameter block changes.
That prefix is the cache key for the second and third project of the fan-out.

### Phase 2 — Cross-Artifact Analysis
Condition: always runs (except if the pipeline aborted early before any plan exists).
Dispatch per `.claude/skills/governance/worker-dispatch.md`:
1. `bash .claude/hooks/set-worker-role.sh sk.plan_sub_analyze`
2. Dispatch `sk.plan_sub_analyze` with the Agent tool. It is READ-ONLY — it writes no file and
   returns its findings as its report.
3. `bash .claude/hooks/set-worker-role.sh clear`

Carry the report's CRITICAL / HIGH / MEDIUM findings into the Review Gate.

### Phase 3 — Review Gate
Protocol: `.claude/skills/governance/review-gate.md`. Active for `confirm` and `validate` when any new plan
was generated or analyze ran; per-project approval (`approved {Project} …`) is allowed.
Review: `planning-brief.md` (if generated/updated), every `03-plan/{Project}/` folder just generated/updated,
and the sk.plan_sub_analyze report (highlight findings).
Check for:
  - Project plans do not contradict each other or architecture.md
  - Every impacted project from unit-brief.md has a plan folder (or a logged reason it was skipped)
  - Files Affected / tasks.md / estimation.md are mutually consistent per project
  - No CRITICAL, HIGH, or MEDIUM findings in the analyze report
Approval effect: set `03-plan/{Project}/plan.md` front-matter `status: approved` for each approved project.
This is the approval sk.implement's preconditions (checked by skill-start.sh) require in confirm/validate mode.
sk.plan never moves `status.current` (`.claude/skills/governance/status-model.md`).

## Completion Report
After the pipeline completes, display:
```
sk.plan complete.
Unit: {unit-id}
Mode: {NORMAL/RESUME | TARGETED | REFRESH | ANALYZE-ONLY}

Phases run:
  {Phase 0 (Planning Brief) | Phase 1 (Projects: {list of {Project}}) | Phase 2 (Analyze)}

Plan folders written:
  {list 03-plan/{Project}/ folders, each with its five artifacts}

Projects skipped:
  {list impacted projects not planned this run, with reason: already planned | not targeted}

Analyze: {PASS | findings — {counts by severity}}

Next step: /sk.implement
  Optional: a fresh session is cheap here and keeps the implement window clean
  (`.claude/skills/governance/session-boundaries.md`). Reorient with /sk.session status.
```

## Quality Bar
- Mode is detected and logged at the start — never ambiguous.
- The impacted-project list is sourced from `unit-brief.md`; every impacted project is either
  planned or explicitly logged as skipped with a reason.
- `--projects` resolution is logged; `--role`/type conflicts STOP rather than guess.
- Every worker is dispatched with the Agent tool, one at a time, with its role markers set before and
  cleared after — never with the Skill tool, and never two in flight at once.
- Worker reports carry paths, decisions and blockers only; no file contents are pasted back into this
  context. Each invocation is self-contained — no state leaks between projects.
- Plans never contradict `02-design/` artifacts; the orchestrator does not redesign.
- Active gates must receive explicit 'approved' before statuses change; skipped gates are logged.
- 'cancel' at the gate preserves all artifacts written up to that point.
- Completion report lists only what actually ran and what was skipped, with reasons.

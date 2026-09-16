# sk.plan — Implementation Planning (Orchestrator)
Orchestrates technical planning for a unit, producing one execution-plan folder per impacted project.
Role: lead (orchestrator) | Level: unit

This skill orchestrates two internal sub-skills. It prepares a planning brief, invokes
`sk.planproject` once per impacted project (resolved from the unit's Impacted Projects table), and
runs `sk.analyze` at the end to catch cross-project / cross-artifact conflicts before implementation.

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
Invoke skill: `sk.planproject`
- Pass: `{Project}`, `{CodeRoot}`, `{ProjectType}`, and the effective `--role`
  (backend for Backend, frontend for Frontend, mobile for Mobile).
- Context injected: `planning-brief.md`, `02-design/architecture.md`, `02-design/impact-analysis.md`,
  `02-design/projects/{Project}.md` (if exists), `02-design/database-design.md` (if exists),
  `02-design/api-contract.md` (if exists), `02-design/contracts/api-spec.json` (if exists),
  `02-design/ui-model.md` (if exists — required for Frontend/Mobile), the unit's story under
  `01-story/`, and the project's tech-stack.md and coding-standards.md.
- Waits for: `03-plan/{Project}/` containing plan.md, tasks.md, checklist.md, jira-subtask.md,
  estimation.md.
- Subagents are isolated from each other; independent projects may be planned in parallel.

### Phase 2 — Cross-Artifact Analysis
Condition: always runs (except if the pipeline aborted early before any plan exists).
Invoke skill: `sk.analyze`
- Context injected: all design artifacts under `02-design/`, all `03-plan/{Project}/plan.md` files.
- Waits for: the Analyze report (read-only) identifying any CRITICAL / HIGH / MEDIUM findings.

### Phase 3 — Review Gate
Protocol: `.claude/skills/governance/review-gate.md`. Active for `confirm` and `validate` when any new plan
was generated or analyze ran; per-project approval (`approved {Project} …`) is allowed.
Review: `planning-brief.md` (if generated/updated), every `03-plan/{Project}/` folder just generated/updated,
and the sk.analyze report (highlight findings).
Check for:
  - Project plans do not contradict each other or architecture.md
  - Every impacted project from unit-brief.md has a plan folder (or a logged reason it was skipped)
  - Files Affected / tasks.md / estimation.md are mutually consistent per project
  - No CRITICAL, HIGH, or MEDIUM findings in the analyze report
Approval effect: set `03-plan/{Project}/plan.md` front-matter `status: approved` for each approved project.
This is the approval check-skill-preconditions.sh requires before sk.implement in confirm/validate mode.

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
```

## Quality Bar
- Mode is detected and logged at the start — never ambiguous.
- The impacted-project list is sourced from `unit-brief.md`; every impacted project is either
  planned or explicitly logged as skipped with a reason.
- `--projects` resolution is logged; `--role`/type conflicts STOP rather than guess.
- Each sk.planproject invocation is self-contained — no state leaks between projects.
- Plans never contradict `02-design/` artifacts; the orchestrator does not redesign.
- Active gates must receive explicit 'approved' before statuses change; skipped gates are logged.
- 'cancel' at the gate preserves all artifacts written up to that point.
- Completion report lists only what actually ran and what was skipped, with reasons.

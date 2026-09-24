# sk.implement — Implementation Pipeline (Orchestrator)
Orchestrates the implementation phase for a unit, producing one delivery folder per impacted project.
Role: lead (orchestrator) | Level: unit

This skill orchestrates the per-project implementation worker. It resolves the impacted projects from
the unit's Impacted Projects table, invokes `sk.implement_sub_implementproject` once per project (each consuming that
project's already-approved `03-plan/{Project}/` plan), and gates the result before reporting. Each worker is
invoked with the **Skill tool** (`Skill(sk.implement_sub_implementproject)`), never by reading its
prompt.md, so `skill-start.sh` runs its preconditions and sets its role
(`.claude/skills/governance/status-model.md` → How a skill starts).
This pipeline is NOT yet migrated to Agent dispatch, so its workers still run with the Skill tool
inside this orchestrator's context (`.claude/skills/governance/worker-dispatch.md` is the target
shape). State is passed via the file system either way, so resume is unaffected.
Orchestrators do not resolve capability packs — each worker resolves its own (phase = implement).

## Implementation Output Layout
All implementation tracking artifacts for the unit live under
`specs/intents/{intent}/units/{unit}/04-implementation/{Project}/` (tree:
`.claude/skills/governance/phase-layout.md`), one folder per impacted project, each holding
`implementation.md` (what was built), `progress.md` (live task tracker) and `validation.md`
(build/test/AC status). Folder names are the project names from `unit-brief.md` — the same names used
for `02-design/projects/` and `03-plan/`. Source code is written within each project's `{CodeRoot}`,
never under `04-implementation/`.

## Invocation Forms
- `sk.implement`                                 — implement ALL impacted projects that have an approved plan
- `sk.implement --role {role} --projects {key}`  — implement exactly ONE project (TARGETED)
- `sk.implement --projects {key}`                — implement one project; infer `--role` from project type
- `sk.implement --refine`                        — re-run code generation only, for projects with a review report

`--role` is one of `backend | frontend | mobile`. `--projects` is resolved per
`.claude/skills/governance/project-resolution.md` (exact name or the `api | web | admin | mobile` aliases).

When no `--projects` is given, the target set is EVERY row in the Impacted Projects table that has an
approved `03-plan/{Project}/plan.md`.

## Pre-flight
1. Run the unit pre-flight in `.claude/skills/governance/preflight.md` (session focus, UNIT_DIR/PLAN_DIR/
   IMPL_DIR/DESIGN_DIR, Impacted Projects, `checkpoint_mode` from `01-story/story.md`, knowledge bases).
2. Verify `PLAN_DIR` exists with at least one `03-plan/{Project}/plan.md`.
   Missing: STOP — run sk.plan first.
3. Read the unit's story under `01-story/` to know the acceptance criteria the implementation must satisfy.

## Mode Detection and Resume Logic
Determine mode based on arguments and existing files. First match wins.

**TARGETED** (`--projects {key}`, with or without `--role`)
- Resolve the project (project-resolution.md).
- Run Phase 1 for that one project only (resume/overwrite its `04-implementation/{Project}/` folder).
- Run Phase 2 (Review Gate) and report.

**REFINE** (`--refine`, OR a `04-implementation/{Project}/review-{story-id}.md` exists for a targeted/impacted project)
- For each in-scope project that has a `review-{story-id}.md`: invoke `sk.implement_sub_implementproject` in REFINE
  mode (code generation only — resolve review findings, no re-scaffolding).
- Run Phase 2 (Review Gate) and report.

**NORMAL / RESUME** (no flags)
- Let `P` = every project in the Impacted Projects table that has an approved `03-plan/{Project}/plan.md`.
- For each project in `P`:
  - If `04-implementation/{Project}/progress.md` is missing or has open tasks: run Phase 1 for it.
  - If `04-implementation/{Project}/` is complete (all tasks done, validation PASS): skip it (log "already implemented").
- Run Phase 2 (Review Gate) and report.

Projects in the Impacted Projects table with NO approved plan are skipped and logged with a reason
(`no plan — run sk.plan --projects {key}` or `plan not approved`).

## Status Transitions
Per `.claude/skills/governance/status-model.md`. Before invoking the first project worker, run:
```
bash .claude/hooks/story-status.sh set in-progress --by sk.implement
```
It validates the value, writes `status.current` and `entered_at`, logs the transition and queues the
tracker mirror. Never edit `status.current` in `01-story/story.md` with Edit/Write. If the command
fails, STOP and report its output — do not start a worker.

Do NOT write any later status here. `status.current` → `testing` is owned by the Stop hook and fires
only when this skill emits `SK_RESULT: PASS`, so a run that is cancelled at the gate correctly leaves
the story at `in-progress`.

## Orchestration

### Phase 1 — Per-Project Implementation
Condition: run for the project(s) determined by Mode Detection.
For each target project `{Project}` (with `{CodeRoot}`, `{ProjectType}` from the resolved row):
Invoke with the Skill tool: `Skill(sk.implement_sub_implementproject)`, one call per project.
This one stays on the Skill tool deliberately — it owns the Scaffolding Review gate, and a gate cannot
run inside a subagent. It dispatches scaffolding and codegen as subagents itself, so the heavy context
(plan, design slice, rules, source tree) never reaches this window
(`.claude/skills/governance/worker-dispatch.md`).
- Pass (as the skill's args): `{Project}`, `{CodeRoot}`, `{ProjectType}`, the effective `--role`
  (backend for Backend, frontend for Frontend, mobile for Mobile), `checkpoint_mode`, and the execution
  mode (NORMAL or REFINE).
- The worker reads: `03-plan/{Project}/plan.md`, `03-plan/{Project}/tasks.md`,
  `03-plan/{Project}/checklist.md`, `02-design/projects/{Project}.md` (if exists),
  `02-design/architecture.md`, `02-design/contract-changes.md` (if exists) and the canonical
  `specs/openapi|asyncapi` operations it lists, `02-design/database-design.md` (if exists),
  `02-design/ui-model.md` (if exists — Frontend/Mobile), the unit's story under `01-story/`, the
  project's `.claude/rules/{stack}/` folders, and `04-implementation/{Project}/review-{story-id}.md`
  (if REFINE mode).
- Waits for: `04-implementation/{Project}/` containing implementation.md, progress.md, validation.md,
  and the actual source written within `{CodeRoot}`.
- Subagents are isolated from each other. Honor cross-project sequencing from
  `02-design/impact-analysis.md` → Sequencing & Dependencies: a project blocked on another project's
  output (or shared infra/config) runs after its precondition; independent projects may run in parallel.

### Phase 2 — Review Gate
Protocol: `.claude/skills/governance/review-gate.md`. Active for `confirm` and `validate` when any project
was implemented this run; per-project approval (`approved {Project} …`) is allowed.
Review: every `04-implementation/{Project}/` folder just generated/updated, with each project's build
status, test status, AC coverage and open issues from its validation.md.
Check for:
  - Implementation stays inside each project's plan slice (no scope creep into another project)
  - Existing functionality was not modified beyond the planned change set
  - progress.md tasks match 03-plan/{Project}/tasks.md (every task accounted for)
  - validation.md reports build + tests + acceptance-criteria status honestly (failures surfaced, not hidden)
  - No project contradicts architecture.md or the canonical contract operations in contract-changes.md
Approval effect: set `04-implementation/{Project}/implementation.md` front-matter `status: approved`
for each approved project.

## Completion Report
After the pipeline completes, display:
```
sk.implement complete.
Unit: {unit-id}
Mode: {NORMAL/RESUME | TARGETED | REFINE}

Phases run:
  Phase 1 (Projects: {list of {Project}})
  Phase 2 (Review Gate)

Implementation folders written:
  {list 04-implementation/{Project}/ folders, each with implementation.md, progress.md, validation.md}

Source roots touched:
  {list each project's {CodeRoot}}

Projects skipped:
  {list impacted projects not implemented this run, with reason: no plan | plan not approved | already implemented | not targeted}

Validation: {per project — build PASS/FAIL, tests PASS/FAIL/n, AC covered/total}

Next step: /sk.test or /sk.review
  Recommended: start a fresh session first (`.claude/skills/governance/session-boundaries.md`).
  This window holds one implementproject run per project plus their gates; 04-implementation/ holds the result.
  Reorient there with /sk.session status.
```

## Quality Bar
- Mode is detected and logged at the start — never ambiguous.
- The impacted-project list is sourced from `unit-brief.md`; every impacted project is either
  implemented or explicitly logged as skipped with a reason.
- `--projects` resolution is logged; `--role`/type conflicts STOP rather than guess.
- Each `sk.implement_sub_implementproject` invocation is self-contained — no state leaks between projects.
- Implementation realizes `03-plan/{Project}/` and `02-design/` — the orchestrator does not redesign or re-plan.
- Existing functionality is never modified beyond the planned change set; new code is added, files are
  inspected before editing, and complete files are not rewritten unless required.
- Active gates must receive explicit 'approved' before statuses change; skipped gates are logged.
- 'cancel' at the gate preserves all artifacts and source written up to that point.
- Completion report lists only what actually ran and what was skipped, with reasons.

## Completion Signal
Last line of output must be exactly one of (see `.claude/skills/governance/status-model.md`):
`SK_RESULT: PASS` — every targeted project reached validation with nothing left blocked
`SK_RESULT: FAIL` — one or more projects are blocked or failed validation

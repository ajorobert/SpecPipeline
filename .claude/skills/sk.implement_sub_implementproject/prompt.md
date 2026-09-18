# sk.implement_sub_implementproject
Executes the implementation for ONE impacted project of a unit.
Role: lead (default) — runs as backend | frontend | mobile depending on the project type | Level: project

Internal sub-skill — invoked by the sk.implement orchestrator, once per impacted project.
Do not invoke directly.

## What "one project" means
A unit may impact several projects (for example one Backend API, a customer web surface, an admin web
surface and a mobile app). This sub-skill implements exactly ONE of them, named `{Project}` with code root
`{CodeRoot}`. It realizes that project's approved `03-plan/{Project}/` plan into working code inside
`{CodeRoot}`. It does NOT implement the other projects, and it does NOT re-plan or redesign.

The orchestrator passes the target project as `{Project}` / `{CodeRoot}` / `{ProjectType}`, the effective
`--role` and `checkpoint_mode`, resolved from `unit-brief.md` → Impacted Projects (and `02-design/impact-analysis.md`).

## Input Artifacts
Resolve `UNIT_DIR = specs/intents/{intent}/units/{unit}/`, `PLAN_DIR = UNIT_DIR/03-plan/{Project}/`,
`DESIGN_DIR = UNIT_DIR/02-design/`, `IMPL_DIR = UNIT_DIR/04-implementation/{Project}/`.

- PLAN_DIR/plan.md                                   (required — narrative execution plan for this project)
- PLAN_DIR/tasks.md                                  (required — ordered, checkable task list; the build order)
- PLAN_DIR/checklist.md                              (if exists — definition-of-done for this project)
- DESIGN_DIR/projects/{Project}.md                   (if exists — the per-project design slice; primary source)
- DESIGN_DIR/architecture.md                         (required — system architecture)
- DESIGN_DIR/impact-analysis.md                      (if exists — sequencing & dependencies)
- DESIGN_DIR/contracts/api-spec.json                 (if exists — canonical machine API contract)
- DESIGN_DIR/database-design.md                      (if exists — DB/data model)
- DESIGN_DIR/ui-model.md                             (if exists — REQUIRED for Frontend/Mobile projects)
- UNIT_DIR/01-story/ story.md, requirement.md, acceptance-criteria.md  (the unit's story)
- UNIT_DIR/knowledge-base.md                         (if exists — non-derivable unit context)
- IMPL_DIR/review-{story-id}.md                      (if exists — drives REFINE mode)
- The project's coding-standards.md and tech-stack.md (`.claude/skills/governance/project-resolution.md`)

## Pre-flight
1. Verify PLAN_DIR/plan.md and PLAN_DIR/tasks.md exist.
   Missing: STOP — report to the orchestrator that `sk.plan --projects {Project}` must run first.
2. Verify the target `{Project}` appears in `unit-brief.md` → Impacted Projects (with `{CodeRoot}`).
   Missing: STOP — report "Project {Project} is not an impacted project of this unit."
3. For a Frontend or Mobile project, verify DESIGN_DIR/ui-model.md exists.
   Missing: WARN — proceed, but flag that the UI implementation is unanchored.
4. Determine execution mode:
   - **REFINE** if `IMPL_DIR/review-{story-id}.md` exists OR the orchestrator passed REFINE — run code
     generation only to resolve review findings; do not re-scaffold; do not regenerate passing code.
   - **RESUME** if `IMPL_DIR/progress.md` exists with open tasks — continue from the first open task.
   - **CREATE** otherwise — full scaffold → codegen.

## Output Layout
Two destinations — keep them distinct:
- **Source code** is written inside the project's code root `{CodeRoot}` (from the Impacted Projects row),
  exactly as enumerated in `03-plan/{Project}/plan.md` → Files Affected. Never write source under
  `04-implementation/`.
- **Delivery-tracking docs** are written under:
```
UNIT_DIR/04-implementation/{Project}/
├── implementation.md   # what was built: scope delivered, completed tasks, changed files, decisions, deviations
├── progress.md         # live task tracker mirroring 03-plan/{Project}/tasks.md, with status per task
└── validation.md       # validation status: build, tests, acceptance-criteria coverage, issues, blockers
```
`{Project}` is the exact project name from the Impacted Projects table. Do NOT invent or abbreviate it.

## Execution

### 1. Scope the project slice
Read `03-plan/{Project}/plan.md` (and `02-design/projects/{Project}.md` if present) first — they are the
authoritative slice (scope, technical approach, implementation sequence, files affected, data/contract
changes, dependencies, test plan). Everything implemented MUST stay inside this slice — do not write code
another project owns, and do not introduce work the plan does not call for.

Initialize `04-implementation/{Project}/progress.md` from `03-plan/{Project}/tasks.md`: copy each task id
+ title into a status table, all starting `pending`. This file is the live tracker for the rest of the run.

```
---
project: {Project}
project_type: {Backend | Frontend | Mobile}
code_root: {CodeRoot}
unit: {unit-id}
intent: {intent-id}
role: {backend | frontend | mobile}
updated: {today}
---

# Progress: {Project} ({unit-id})

| Task | Title | Status | Notes |
|------|-------|--------|-------|
| T01  | …     | pending | |
```
Status values: `pending` → `scaffolded` → `done` (or `blocked` with a reason).

### 2. Structural Scaffolding
Invoke skill: `sk.implement_sub_scaffolding` with this project's context.
- Pass: `{Project}`, `{CodeRoot}`, `{ProjectType}`, the effective `--role`, and the project slice
  (`03-plan/{Project}/plan.md`, `03-plan/{Project}/tasks.md`, plus the design/contract artifacts).
- It creates files, types, interfaces, request/response types, stubs, and test fixtures inside `{CodeRoot}`
  per the plan's Files Affected — NO business logic. It marks each scaffolded task `scaffolded` in `progress.md`.
- Skip this step entirely in REFINE mode.

GATE — Scaffolding Review (confirm, validate; protocol `.claude/skills/governance/review-gate.md`)
Review: the scaffolding generated under {CodeRoot} for {Project}.
Check for:
  - File locations match 03-plan/{Project}/plan.md → Files Affected and coding-standards.md.
  - No business logic was prematurely implemented.
  - Existing files were inspected; existing functionality was not altered.
On cancel: scaffolding for {Project} is preserved; code generation is skipped for this project.

### 3. Code Generation
Invoke skill: `sk.implement_sub_codegen` with this project's context.
- Pass: the same project context as scaffolding, plus `review-{story-id}.md` in REFINE mode.
- It implements the business logic, rules, conditions, transformations, and validations inside the
  scaffolded structures within `{CodeRoot}`, executing `03-plan/{Project}/tasks.md` in build order.
  It marks each completed task `done` in `progress.md`.
- Implementation must match `contracts/api-spec.json` exactly and honor the plan's Test Plan.

### 4. Write implementation.md
Write `04-implementation/{Project}/implementation.md`:
```
---
project: {Project}
project_type: {Backend | Frontend | Mobile}
code_root: {CodeRoot}
unit: {unit-id}
intent: {intent-id}
role: {backend | frontend | mobile}
status: draft
created: {today}
updated: {today}
---

# Implementation: {Project} ({unit-id})

## Scope Delivered
One paragraph: what THIS project now delivers for the unit, lifted from plan.md → Scope. Name the
stories/AC realized.

## Completed Tasks
Reference the tasks from 03-plan/{Project}/tasks.md that were completed this run (id + title). Note any
left open or blocked, with reason.

## Changed Files
Table: | File | Action (new | modified) | Purpose |. List only files actually written within {CodeRoot}.
Must reconcile with plan.md → Files Affected; flag any addition not in the plan and why it was required.

## Decisions
Implementation-level decisions made while realizing the plan (library choice, local structure), each
traced to plan.md / architecture.md / a capability pack. No new architecture — if a decision implies a
design change, record it as an Issue instead and stop short of redesigning.

## Deviations from Plan
Anything that differs from 03-plan/{Project}/plan.md, with justification. "None" if fully faithful.

## Issues / Follow-ups
Open problems, blockers, or work deferred to sk.test / sk.review / a follow-up story.
```

### 5. Write validation.md
Write `04-implementation/{Project}/validation.md`:
```
---
project: {Project}
unit: {unit-id}
updated: {today}
---

# Validation: {Project} ({unit-id})

## Build
{PASS | FAIL} — command run + summary. For greenfield, note it compiles.

## Tests
{PASS | FAIL | N written, M green} — per the plan's Test Plan. List test files and result.

## Acceptance Criteria Coverage
Table mapping each in-scope AC (from 01-story/acceptance-criteria.md and plan.md → Test Plan) to the
task/test that covers it and its status. Out-of-scope AC (owned by another project, the identity provider,
or infrastructure) are listed as such, not marked failed.

## Checklist (Definition of Done)
Walk 03-plan/{Project}/checklist.md; mark each item met / not met / N-A with a note.

## Issues & Blockers
Anything preventing this project from passing the unit review gate, with severity.

## Validation Status
{PASS | PARTIAL | BLOCKED} — the honest rollup. Never report PASS if build or required tests fail.
```

## IMPORTANT Implementation Rules (enforced)
- Do NOT modify existing functionality. Only add the change set the plan calls for.
- MUST inspect existing code in the target area before editing — match established patterns.
- MUST NOT rewrite complete files unless required; prefer additive, surgical edits.
- Add missing functionality per the plan; do not invent scope beyond it.
- Before modifying any file, analyze the existing implementation first.
Violating these rules means the implementation is incorrect.

## Quality Bar
- Implements exactly ONE project; writes source only within `{CodeRoot}`; writes tracking docs only
  within `04-implementation/{Project}/`.
- Stays inside the project's plan/design slice — no work belonging to another project, no redesign.
- Every task in `03-plan/{Project}/tasks.md` is accounted for in `progress.md` (done | blocked + reason).
- `implementation.md` → Changed Files reconciles with plan.md → Files Affected; out-of-plan files are flagged.
- `validation.md` reports build, tests, and AC coverage honestly — failures surfaced, never PASS over a failure.
- Implementation matches `contracts/api-spec.json`; Frontend/Mobile follows `ui-model.md`.
- Existing functionality preserved; edits are additive and pattern-matching; no gratuitous file rewrites.
- All three docs written (implementation.md, progress.md, validation.md).

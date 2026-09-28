---
name: sk.implement
description: "Implement one impacted project of a planned unit (--projects <name>): build its approved tasks inside its code root, run the build and tests, check the diff against the plan, and record delivery."
role: engineer
preconditions:
  - "file_contains: {unit_dir}/unit-brief.md :: ^[|][^|]+[|][[:space:]]*(Backend|Frontend|Mobile)[[:space:]]*[|]"
  - "story.checkpoint_mode in [autopilot, confirm, validate]"
  - "file_exists: {unit_dir}/03-plan/*/plan.md"
  - "when story.checkpoint_mode in [confirm, validate] => file_contains: {unit_dir}/03-plan/*/plan.md :: ^status:[[:space:]]*approved"
---

# sk.implement
Implements one project of the unit, in one session, as that project's engineer.
Source goes into the project's `{CodeRoot}`; tracking into `04-implementation/{Project}/` (`progress.md`,
`delivery.md`). Run it once per impacted project, each in a fresh session, in the order of
impact-analysis.md → Sequencing & Dependencies. With no `--projects`, a unit with one impacted project
implements that one; a small unit may implement all of them in this session, one after another.

## Invocation
- `sk.implement --projects <name>` — implement that project.
- `sk.implement --projects <name> --refine` — resolve the findings of `04-implementation/{Project}/review.md`.

## Pre-flight
1. Run `.claude/skills/governance/preflight.md` with command `implement --projects <name>`.
2. The project's plan.md is missing, or not `status: approved` in confirm/validate: STOP — `/sk.plan --projects <name>`.
3. A project this one depends on (impact-analysis → Sequencing) has no `validation: PASS` delivery yet:
   say so and ask whether to continue.
4. First implement run of the unit: `bash .claude/hooks/story-status.sh set in-progress --by sk.implement`.
   If it fails, STOP with its output.

## Steps
1. **Progress** — `progress.md` missing: create it from tasks.md — front-matter (project, type, code_root,
   unit), then `| Task | Title | Status | Notes |`, every task `pending`. Present: resume from the first
   task that is not `done`.
2. **Build** — `steps/build.md`: tasks in order, inside {CodeRoot}. With a schema change in
   database-design.md for this project, `steps/migration.md` runs where the tasks place it.
   `--refine`: only the review's blocking findings, then its non-blocking ones the human accepts.
   Validate mode on a CREATE run: after the structural tasks (types, contracts, stubs, fixtures), pause at
   a **Structure** gate — file locations match Files Affected and the rules, generated code untouched, no
   logic yet — before the logic tasks.
3. **Validate** — run the project's build, then its tests (tech-stack.md commands; `none` → log
   `SKIP — {field}: none`). Fix failures the change caused. Record what ran and the results.
4. **Diff check** — dispatch one `sk-reviewer` subagent: "Review the diff of {CodeRoot} against
   {base}...HEAD for the active unit against 03-plan/{Project}/plan.md, tasks.md and
   02-design/contract-changes.md. Report: tasks not implemented, files changed outside Files Affected,
   operations or fields that differ from the spec, acceptance criteria with no test. Correctness and
   stated requirements only." Fix what it finds, or record why not.
5. **delivery.md** — write it (below).
6. **Gate — Implementation** (`.claude/skills/governance/review-gate.md`; pauses in confirm and
   validate). Show delivery.md and the diff summary. Check for: the change stays inside the plan's slice;
   existing behaviour changed only where planned; every task accounted for; validation reported honestly.
   Approval: set `status: approved` in delivery.md.

## delivery.md
```
---
project: {Project}
unit: {unit-id}
validation: PASS | PARTIAL | BLOCKED
status: draft
---
# Delivery: {Project}
## Delivered — what this project now does for the unit; the acceptance criteria it covers.
## Changed files — | File | new / modified | Purpose |; flag each file not in Files Affected, with why.
## Decisions — implementation-level choices and the source each follows. A choice that changes the
   design is an issue, not a decision.
## Deviations from plan — or "None".
## Validation — build (command, result); tests (command, n passed / failed); acceptance criteria →
   covering test, with status; out-of-scope criteria named as such.
## Issues — open problems and follow-ups, with severity.
```
`validation: PASS` only when the build passes, the required tests pass and no task is blocked.

## Rules
- Change only what the plan calls for. Read the existing code in an area before changing it, reuse what
  exists, and edit surgically — never rewrite a file the task does not require rewriting.
- The ADRs, the project rules and the principles outrank the plan: on a conflict follow them and record a
  deviation. Domain rules discovered while coding go to Issues, never into `specs/domain/` from here.
- Never edit `03-plan/`, `02-design/` or the canonical contracts. A contract mismatch is an issue.

## Completion report and signal
```
sk.implement — {unit-id} / {Project}
Tasks: {done}/{total}  Blocked: {list | none}   Validation: {PASS | PARTIAL | BLOCKED}
Projects still to implement: {names | none}
Next: /sk.implement --projects {next} — or, when none is left, /sk.test --projects {first} — in a fresh session
```
The last line of output is exactly one of:
- `SK_RESULT: PASS` — this project validated and every other impacted project already has `validation: PASS`
- `SK_RESULT: PARTIAL` — this project validated; other impacted projects are still to implement
- `SK_RESULT: FAIL` — this project is blocked or failed validation

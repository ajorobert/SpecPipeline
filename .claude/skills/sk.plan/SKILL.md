---
name: sk.plan
description: "Plan a designed unit: one execution plan and ordered task list per impacted project, checked for consistency against the design by a read-only reviewer, then gated for approval."
role: lead
preconditions:
  - "file_contains: {unit_dir}/unit-brief.md :: ^[|][^|]+[|][[:space:]]*(Backend|Frontend|Mobile)[[:space:]]*[|]"
  - "file_exists: {unit_dir}/02-design/architecture.md"
---

# sk.plan
Plans one unit, in one session. Outputs `03-plan/{Project}/plan.md` and `tasks.md` per impacted project
(`.claude/skills/governance/phase-layout.md`). A plan realizes the design; it never redesigns.

## Invocation
- `sk.plan` — plan every impacted project without a plan.md, then check and gate.
- `sk.plan --projects <name>` — plan (or re-plan) that one project, then check and gate. Use it per
  project, in separate sessions, when the unit's projects are large.
- `sk.plan --check` — consistency check and gate only.
- `sk.plan --refresh "<change>"` — re-plan the projects the change affects (ambiguous → all).

## Pre-flight
Run `.claude/skills/governance/preflight.md` with command `plan` (add `--projects <name>` when given).

## Steps
1. **Project plans** — for each target project, in the order of impact-analysis.md → Sequencing &
   Dependencies, follow `steps/project-plan.md`.
2. **Consistency check** — dispatch one `sk-reviewer` subagent with this prompt, unchanged:
   "Run the consistency check in .claude/skills/sk.plan/steps/consistency.md for the active unit. Report
   only its findings table and summary." It reads and reports; it writes nothing. Carry its CRITICAL,
   HIGH and MEDIUM findings to the gate.
3. **Gate — Plan** (`.claude/skills/governance/review-gate.md`; pauses in confirm and validate; per-project
   approval allowed). Show each plan.md and tasks.md written or changed, and the check's findings.
   Check for: no plan contradicts another or the design; every impacted project has a plan or a logged
   reason; Files Affected and tasks agree; no CRITICAL, HIGH or MEDIUM finding left.
   Approval: set `status: approved` in each approved project's plan.md front-matter — sk.implement
   requires it in confirm and validate. sk.plan never moves the story's status.

## Completion report
```
sk.plan complete — {unit-id}
Planned: {Project: written | refined | kept}   Skipped: {Project: reason}
Check: {PASS | counts by severity}   Approved: {Projects | none}
Next: /sk.implement --projects {first project in sequence} — in a fresh session
```

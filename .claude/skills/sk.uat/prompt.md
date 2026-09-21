# sk.uat — User Acceptance Testing (Unit)
User Acceptance Testing for a unit against its acceptance criteria, across every impacted surface.
Role: frontend-qa | Level: unit
Frontend only — backend uses sk.test for contract and integration tests.

UAT is a unit-level acceptance gate. Its output is a single flat `06-uat/` folder for the unit (NOT
one folder per project): the impacted surfaces are exercised and their results are aggregated into
one acceptance record, one user-flow record, and one sign-off.

## Invocation Forms
- `sk.uat`                          — UAT for ALL impacted user-facing surfaces of the unit
- `sk.uat --platform {surface}`     — UAT for ONE surface only

`--platform` narrows the run to a single surface; otherwise every impacted Frontend/Mobile project in
the unit is exercised.

## Pre-flight
Run the unit pre-flight in `.claude/skills/governance/preflight.md` (session focus, UNIT_DIR/DESIGN_DIR,
Impacted Projects, `checkpoint_mode` from `01-story/story.md`, knowledge bases).
Resolve `UAT_DIR = UNIT_DIR/06-uat/`.

## Surface Resolution
The in-scope surfaces are the `unit-brief.md` → Impacted Projects rows with Type = Frontend or Type = Mobile.
For each, read its `.specify/memory/skill-routing.md` → `## Surfaces` row (match on Project) for
**Framework**, **Platform** (`browser | native`) and **E2E tooling**. If a surface has no Surfaces row, take
the tooling from the project's tech-stack.md and log `surface not registered in skill-routing.md`.
- With `--platform {surface}`: match, in order, the Surfaces row's Surface name, the exact Project name,
  then the aliases `web` / `customer` (Frontend row whose Role mentions customer/portal), `admin` (Frontend row
  whose Role mentions admin), `mobile` (Type = Mobile). If it is not an impacted project: STOP and report.
- Without a flag: the surface set is every Frontend/Mobile row.
Backend rows are NOT user-facing surfaces — they are excluded from UAT (covered by sk.test).
Log the resolution: `UAT surfaces: {Project} ({Framework}, {Platform}, {E2E tooling})`.
If the unit impacts NO user-facing surface: STOP — "Unit {unit-id} has no frontend/mobile surface;
UAT is N/A. Backend verification is covered by sk.test."

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `uat`,
in-scope projects = the resolved surfaces.

## Context loading
- UNIT_DIR/01-story/ story.md, requirement.md, acceptance-criteria.md
  → each acceptance criterion becomes a UAT scenario; the requirement's business rules become the
    validation checklist.
- DESIGN_DIR/contracts/test-plan.md → Consumer Tests → the `### {Project}` section for each surface.
- DESIGN_DIR/ui-model.md (if exists) → the end-to-end user flows to walk.
- UNIT_DIR/knowledge-base.md (if exists) → non-obvious invariants the UAT must respect (e.g.
  no user enumeration, no partial session on failure, security-relevant copy).
- UNIT_DIR/05-test/{Project}/ (if exists) → component/consumer results already produced by sk.test,
  so UAT focuses on end-user workflow rather than re-running unit-level checks.

## Test execution by surface
For each in-scope surface, declare it (`{Project}: {Framework}, {Platform}, {E2E tooling}`), then exercise it
with that row's E2E tooling:
- **Platform = browser** — full browser E2E: user journey flows, responsive layout, error/empty states; for
  admin-type surfaces also CRUD operations, bulk actions, role-based visibility, data-table pagination.
- **Platform = native** — device/simulator flows: offline behaviour, deep links, push-notification handling,
  secure storage of tokens. **Never use browser tooling for a native surface**; if the declared tooling is a
  browser tool, STOP and report the misconfiguration.

Run each surface's scenarios against the acceptance criteria; capture pass/fail per criterion per
surface, plus any business-rule violation observed.

## Output Artifacts
Write the flat unit-level UAT folder `UNIT_DIR/06-uat/`:

### acceptance-result.md
Per-criterion acceptance results across all surfaces.
```
---
unit: {unit-id}
intent: {intent-id}
surfaces: [{list of surfaces exercised}]
created: {today}
updated: {today}
---

# UAT Acceptance Results: {unit name} ({unit-id})

## Acceptance Criteria
Table: | AC | Criterion | {surface} result … | Verdict | Notes |
One row per acceptance criterion; one result column per in-scope surface (PASS / FAIL / N-A).
Verdict is PASS only if every applicable surface passes that criterion.

## Business Rules
Walk the requirement.md business rules; mark each Validated / Violated / N-A with evidence.
Call out any knowledge-base.md invariant verified here (e.g. no user enumeration, no partial session).

## Defects
Each failure: id, surface, the AC/business rule it breaks, severity, repro steps, expected vs actual.
```

### user-flow-test.md
The end-to-end user workflows walked, per surface.
```
---
unit: {unit-id}
intent: {intent-id}
created: {today}
updated: {today}
---

# UAT User-Flow Walkthroughs: {unit name} ({unit-id})

## Flows (per surface)
For each surface and each user flow (from ui-model.md / story.md): the ordered steps, the expected
behaviour at each step, the observed result, and PASS/FAIL. Note tooling used per surface.

## Cross-surface Consistency
Where the same flow runs on multiple surfaces, note any divergence in behaviour or copy
(security-relevant copy must stay consistent — e.g. generic invalid-credentials message).
```

### signoff.md
The final approval record.
```
---
unit: {unit-id}
intent: {intent-id}
uat-status: {pass | fail}
signed-off-by: {role / name — or "pending" until the gate}
created: {today}
updated: {today}
---

# UAT Sign-off: {unit name} ({unit-id})

## Summary
AC passed/total, surfaces exercised, open defects by severity.

## Decision
{ACCEPTED | REJECTED | ACCEPTED WITH FOLLOW-UPS} — with the conditions/follow-ups if any.

## Outstanding Items
Defects or business rules deferred, with owner and tracking reference.
```

## Sign-off Gate
Protocol: `.claude/skills/governance/review-gate.md`. Active for `confirm` and `validate`.
Review: the acceptance summary — AC pass/total per surface, business rules validated/total, open defects by
severity. Inputs: `approved` signs off; `reject` records UAT as failed with the open defects.
- On `approved`: set `06-uat/signoff.md` `uat-status: pass`, fill `signed-off-by`, and set `test-status = pass`
  in `01-story/story.md` ONLY if every applicable AC passed on every in-scope surface.
- On `reject`: `uat-status: fail`; record `test-status = fail` with the failing surfaces/AC.
- If `checkpoint_mode` is `autopilot`: roll up automatically (pass iff all applicable AC pass on all
  surfaces) and log it.

Note: `test-status` is the field sk.ship reads. If sk.test already set it, UAT may only move it to
`pass` when both contract/integration tests AND user acceptance pass; any UAT failure forces `fail`.

## Quality Bar
- Surfaces resolved from unit-brief.md and skill-routing.md ## Surfaces, and declared; correct tooling per
  surface (native surfaces never tested with browser tooling).
- Every acceptance criterion has a mapped result for every applicable surface; none left unmapped.
- Business rules from requirement.md each validated or flagged; knowledge-base invariants respected.
- The three flat artifacts written under `06-uat/` (acceptance-result.md, user-flow-test.md, signoff.md).
- UAT does not modify application code to pass a scenario — failures are recorded as defects.
- `test-status` rolls up honestly — `pass` only when all applicable AC pass on all in-scope surfaces.

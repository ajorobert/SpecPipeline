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
Impacted Projects, `checkpoint_mode` from `01-story/story.md`, knowledge, `.specify/profile.yaml`).
Resolve `UAT_DIR = UNIT_DIR/06-uat/`.

## Surface Resolution
The in-scope surfaces are the `unit-brief.md` → Impacted Projects rows with Type = Frontend or Type = Mobile.
For each, read `.specify/memory/projects/{Project}/tech-stack.md` (`governance/project-resolution.md`):
**Platform** (`browser`, `native …`, or another declared value), **E2E Tooling** (a tool or `none`), and
the UI framework from its Versions table. A missing field (not `none`) is inferred from the project's
manifests under `{CodeRoot}` and logged `tech-stack.md {field} missing — inferred`; a field is never
invented when the manifests do not show it.
- With `--platform {surface}`: match, in order, the exact Project name, then the aliases `web` / `customer`
  (Frontend row whose Role mentions customer/portal), `admin` (Frontend row whose Role mentions admin),
  `mobile` (Type = Mobile). If it is not an impacted project: STOP and report.
- Without a flag: the surface set is every Frontend/Mobile row.
Backend rows are NOT user-facing surfaces — they are excluded from UAT (covered by sk.test).
Log the resolution: `UAT surfaces: {Project} ({Framework}, {Platform}, {E2E Tooling})`.
If the unit impacts NO user-facing surface: STOP — "Unit {unit-id} has no frontend/mobile surface;
UAT is N/A. Backend verification is covered by sk.test."

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `uat`,
in-scope projects = the resolved surfaces.

## Context loading
- UNIT_DIR/01-story/ story.md, requirement.md, acceptance-criteria.md
  → each acceptance criterion becomes a UAT scenario; the requirement's business rules become the
    validation checklist.
- DESIGN_DIR/contract-changes.md → Test plan → the `### Consumer ({Project})` section for each surface.
- DESIGN_DIR/ui-model.md (if exists) → the end-to-end user flows to walk.
- UNIT_DIR/knowledge-base.md (if exists) → non-obvious invariants the UAT must respect.
- UNIT_DIR/05-test/{Project}/ (if exists) → component/consumer results already produced by sk.test,
  so UAT focuses on end-user workflow rather than re-running unit-level checks.

## Test execution by surface
For each in-scope surface, declare it (`{Project}: {Framework}, {Platform}, {E2E Tooling}`), then exercise it:
- **E2E Tooling set, Platform = browser** — automated browser E2E with that tool: user journey flows,
  responsive layout, error/empty states, and the role-based behaviour the acceptance criteria name.
- **E2E Tooling set, Platform = native** — device/simulator flows with that tool: the offline, deep-link,
  notification and secure-storage behaviour the acceptance criteria name. **Never use browser tooling
  for a native surface**; if the declared tooling is a browser tool, STOP and report the misconfiguration.
- **E2E Tooling: none** — log `SKIP — E2E Tooling: none` for automation (not a failure) and run the
  acceptance walk-through as a **documented manual/assisted flow**: for each scenario write the exact
  steps, the expected result, and what was observed — by running the app where it can be run (for
  example a local dev server, a simulator, or a human tester following the steps), else by the human's
  recorded observation. Mark every result obtained this way `manual` and say so in every artifact and
  in the sign-off. Never invent a tool.

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
method: {per surface: automated ({tool}) | manual}
created: {today}
updated: {today}
---

# UAT Acceptance Results: {unit name} ({unit-id})

## Acceptance Criteria
Table: | AC | Criterion | {surface} result … | Method | Verdict | Notes |
One row per acceptance criterion; one result column per in-scope surface (PASS / FAIL / N-A).
Verdict is PASS only if every applicable surface passes that criterion.

## Business Rules
Walk the requirement.md business rules; mark each Validated / Violated / N-A with evidence.
Call out any knowledge-base.md invariant verified here.

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
behaviour at each step, the observed result, and PASS/FAIL. Note the method per surface (the E2E tool,
or `manual — E2E Tooling: none` with who performed the walk-through).

## Cross-surface Consistency
Where the same flow runs on multiple surfaces, note any divergence in behaviour or copy.
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
AC passed/total, surfaces exercised (automated / manual), open defects by severity.

## Decision
{ACCEPTED | REJECTED | ACCEPTED WITH FOLLOW-UPS} — with the conditions/follow-ups if any.

## Outstanding Items
Defects or business rules deferred, with owner and tracking reference.
```

## Sign-off Gate
Protocol: `.claude/skills/governance/review-gate.md`. Active for `confirm` and `validate`.
Review: the acceptance summary — AC pass/total per surface, method per surface, business rules
validated/total, open defects by severity. Inputs: `approved` signs off; `reject` records UAT as failed
with the open defects.
- On `approved`: set `06-uat/signoff.md` `uat-status: pass` and fill `signed-off-by`, then run
  `bash .claude/hooks/story-status.sh field uat-status pass`. Run
  `bash .claude/hooks/story-status.sh field test-status pass` ONLY if every applicable AC passed on every
  in-scope surface and the story's `test-status` is already `pass`.
- On `reject`: set `signoff.md` `uat-status: fail`, then run
  `bash .claude/hooks/story-status.sh field uat-status fail` and
  `bash .claude/hooks/story-status.sh field test-status fail`; list the failing surfaces/AC in the report.
- If `checkpoint_mode` is `autopilot`: roll up automatically (pass iff all applicable AC pass on all
  surfaces), run the same commands, and log it.
- Never edit `01-story/story.md` frontmatter with Edit/Write (`governance/status-model.md`).

Note: `test-status` is the field sk.ship reads. sk.test sets it from its own result; UAT may only leave
it at `pass` when both the contract/integration tests AND user acceptance pass — any UAT failure forces
`fail`.

## Quality Bar
- Surfaces resolved from unit-brief.md (Type Frontend/Mobile) and each project's tech-stack.md
  Platform / E2E Tooling, and declared; correct tooling per surface (native surfaces never tested with
  browser tooling).
- `E2E Tooling: none` produces a logged SKIP and a documented manual/assisted walk-through, stated as
  such in every artifact — never an invented tool.
- Every acceptance criterion has a mapped result for every applicable surface; none left unmapped.
- Business rules from requirement.md each validated or flagged; knowledge-base invariants respected.
- The three flat artifacts written under `06-uat/` (acceptance-result.md, user-flow-test.md, signoff.md).
- UAT does not modify application code to pass a scenario — failures are recorded as defects.
- `uat-status` and `test-status` are written only through `story-status.sh` and roll up honestly —
  `pass` only when all applicable AC pass on all in-scope surfaces.

---
name: sk.uat
description: "User acceptance test a unit across its user-facing projects: walk every acceptance criterion and business rule on each Frontend/Mobile surface, automated where the project declares E2E tooling, and record the sign-off."
role: frontend-qa
---

# sk.uat
Acceptance-tests the unit's user-facing surfaces, in one session. Output: `06-uat/uat-report.md`;
`uat-status` through story-status.sh.

## Invocation
- `sk.uat` — every Frontend/Mobile project of the unit. `sk.uat --projects <name>` — one of them.

## Pre-flight
Run `.claude/skills/governance/preflight.md` with command `uat`. Surfaces: the Impacted Projects rows of
Type Frontend or Mobile, each with Platform and E2E Tooling from its tech-stack.md. None: STOP — UAT is
N/A; the backend is covered by sk.test. Say per surface: `{Project}: {Platform}, {E2E Tooling}`.

## Steps
1. **Scenarios** — each acceptance criterion becomes a scenario; requirement.md's business rules become
   the checklist; ui-model.md gives the flows; the knowledge base the invariants to respect. The test
   reports already cover component and contract level: focus on the user's journey.
2. **Run, per surface:**
   - E2E Tooling set, browser platform: automated browser journeys — flows, responsive layout, error and
     empty states, role-based behaviour the criteria name.
   - E2E Tooling set, native platform: device or simulator flows — offline, deep links, notifications,
     secure storage where the criteria name them. Browser tooling declared for a native surface is a
     misconfiguration: STOP and say so.
   - `E2E Tooling: none`: log `SKIP — E2E Tooling: none` and walk each scenario manually — exact steps,
     expected, observed — by running the app or by the human's recorded observation. Mark these `manual`
     everywhere. Never invent a tool.
3. **uat-report.md** (below).
4. **Gate — Sign-off** (`.claude/skills/governance/review-gate.md`; pauses in confirm and validate; inputs
   `approved` or `reject`). Show AC passed/total per surface, method per surface, business rules
   validated/total, open defects by severity.
   - approved: `uat-status: pass` in the report and `bash .claude/hooks/story-status.sh field uat-status pass`.
   - reject: `uat-status: fail` in the report, then `story-status.sh field uat-status fail` and
     `story-status.sh field test-status fail`.
   - autopilot: pass only when every applicable criterion passed on every surface; same commands.

## uat-report.md
```
---
unit: {unit-id}
surfaces: [{Project}, …]
method: {Project: automated ({tool}) | manual, …}
uat-status: pass | fail
signed-off-by: {name | pending}
---
# UAT: {unit-id}
## Acceptance criteria — | AC | {surface} … | Method | Verdict |  (verdict PASS only when every applicable surface passes)
## Flows — per surface: steps, expected, observed, PASS/FAIL; divergence between surfaces on the same flow.
## Business rules — each validated, violated or N/A, with evidence.
## Defects — id, surface, criterion or rule broken, severity, steps, expected vs actual.
## Decision — ACCEPTED | REJECTED | ACCEPTED WITH FOLLOW-UPS, with owners and tracking references.
```
Never change application code to pass a scenario.

## Completion report
```
sk.uat — {unit-id}: {pass | fail} — AC {passed}/{total}, surfaces {automated / manual}
Next: /sk.security-audit — in a fresh session
```

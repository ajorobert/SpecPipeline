---
name: sk.verify
description: "Final PASS/FAIL quality gate for a unit before sk.ship: collect the mechanical evidence with a script, then judge the remaining quality-gate items and the story, test and security rubrics."
role: architect
---

# sk.verify
The last gate before `sk.ship`, in a fresh session. It re-judges nothing the earlier gates already
decided: their verdicts are evidence. It writes no file; the Stop hook records the result.

## Pre-flight
Run `.claude/skills/governance/preflight.md` with command `verify`. It lists the rule files that match the
unit's diff — read them only if an item below needs them.

## Steps
1. `bash .claude/hooks/verify-evidence.sh` — PASS / FAIL / SKIP for every mechanical item of
   `.claude/skills/governance/quality-gates.md`, including the ADR guard and `contracts.verify`. Copy its
   lines into the report as they are.
2. Judge the items quality-gates.md marks *(judgment)*, reading only the artifact each one names.
3. Apply the rubrics from their skills' front-matter: `story-completeness` (sk.story) to the story,
   `test-coverage` (sk.test) to each project's test-report.md, `security-coverage`
   (sk.security-audit) to security-report.md.
4. Report: every gate item and rubric check PASS / FAIL / SKIP with its reason; each FAIL with the
   specific evidence and the command that fixes it; each rule-level FAIL citing its ADR, rule file or principle.

## Completion report and signal
```
sk.verify — {unit-id}: {PASS | FAIL} — {n} pass, {m} fail, {k} skip
Failures: {item — evidence — fix}
Next: PASS → /sk.ship — in a fresh session
```
PASS moves the story to `done` and sets `verify-status` (Stop hook). Never edit the story front-matter.
Last line, exactly one of: `SK_RESULT: PASS` — every applicable item passed; `SK_RESULT: FAIL` — otherwise.

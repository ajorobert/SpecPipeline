---
name: sk.investigate
description: "Investigate a defect in the active unit: reproduce it, find and prove the root cause, classify each finding as an implementation bug or a spec/contract mismatch, and record candidate invariants."
role: engineer
---

# sk.investigate
Finds root causes, in one session. Output: `investigation-report.md` at the unit root; candidate
invariants in the unit's `knowledge-base.md`. It changes no spec, contract or design.

## Pre-flight
Run `.claude/skills/governance/preflight.md` with command `investigate` (add `--projects <name>` for the
suspected project). Report present: read its front-matter only, increment `session_count`; missing: create
it from `{templates_dir}/artifacts/investigation-report-template.md` with `session_count: 1`.

## Investigate
Hold in view: the acceptance criteria (expected behaviour), the spec operations contract-changes.md lists
(expected shapes), the routed ADRs and domain invariants that bear on the failure, and the project's plan.
Reproduce the failure, read the code on the failing path (for a wide search, an Explore subagent), form a
hypothesis, and confirm it with evidence — a failing test, a log line, a traced call — before calling it a
root cause.

Classify every finding:
- **Implementation bug** — the code deviates from the spec; the fix belongs in {CodeRoot}.
- **Spec/contract mismatch** — the spec, contract or criteria must change first; flag it to the architect.
  Nothing in the spec changes without the architect.

## Record
- Add a session block `## Investigation INV-{NNN} — {date}` directly below the report header, above the
  earlier ones (never edit those). Findings are numbered within the session (`Finding-001`); refer across
  sessions as `INV-NNN / Finding-NNN`. Each finding: symptom, root cause, evidence, classification.
- For each finding, the invariant the bug revealed that the code does not make obvious: append
  `- [INV-NNN] {rule} — story {story-id} ({date})` under `## Candidate Invariants` in the unit's
  knowledge-base.md (create the file from `{templates_dir}/artifacts/unit-knowledge-base-template.md`
  when absent). Skip obvious ones (null checks, input validation) and say so in the report. Promotion at
  ship moves the surviving ones to their home.

## Completion report
```
sk.investigate — INV-{NNN}: {n} findings ({bugs} implementation bugs, {mismatches} spec/contract mismatches)
Report: {unit}/investigation-report.md
Next: all bugs → fix, then /sk.test --projects {Project};
      any mismatch → correct the criteria, or /sk.design --refresh "<change>" for the contract, before code changes
```

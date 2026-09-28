---
name: sk.review
description: "Review one implemented project's branch diff (--projects <name>) against the unit's story, design, contract changes and plan and the project's ADRs and rules — or run the project's own review command when the profile maps one — and record the verdict."
role: engineer
---

# sk.review
Reviews one project's diff, in a fresh session (fresh eyes: not the session that wrote the code). Output:
`04-implementation/{Project}/review.md`. Run once per impacted project.

## Invocation
- `sk.review --projects <name>`. A present review.md with `verdict: REJECTED` makes this a re-review:
  mark each prior finding resolved or still open first, then review the rest of the diff.

## Pre-flight
1. Run `.claude/skills/governance/preflight.md` with command `review --projects <name>`. It lists the
   rule files whose `paths:` match this project's diff: read them.
2. The diff: `git diff {vcs.base_branch}...HEAD -- {CodeRoot}` plus the same for the canonical contract
   files contract-changes.md names (base default `dev`). Empty: STOP — nothing to review.

## Project review command
`review.commands.{Project}` set in `.specify/profile.yaml`: run it with `Skill(<name>)`, on this branch,
and use its report as the review — its findings become this review's findings (blocking stays blocking).
Then add only what it does not cover: the contract compatibility table and unit-scope findings (step 3
below). Link its report in review.md.

## Review
Judge every hunk. Every blocking finding cites what it breaks.
1. **ADRs, rules, principles** — a hunk that breaks a routed ADR, a rule in the matched rule files, or a
   principle (`ADR-NNNN`, `.claude/rules/…`, `principles §N`) is BLOCKING. Where an ADR and existing code
   disagree, the ADR wins.
2. **Contracts** — code must implement exactly the operations in contract-changes.md as the spec defines
   them on this branch; anything in code but not in the spec, or the reverse, is BLOCKING. Each operation's
   diff must fit its compatibility class (`contracts.compat_rules`); a class that understates the change,
   or an unaccepted `breaking` change, is BLOCKING.
3. **Unit scope** — the diff realizes the acceptance criteria and this project's tasks, inside the unit's
   bounded context. Reaching into another context's internals, an entity the design does not have, or
   behaviour the story does not ask for is BLOCKING.
4. **Packs** — the loaded packs' review checks; blocking only where the pack says so and no higher source differs.
5. **Non-blocking** — existing code read before writing? a new abstraction duplicating one that exists?
   failure modes of new external calls handled as designed? consistency per write path honoured? tests
   match the plan?
Flag every conflict between sources, with the winner.

## review.md
```
---
project: {Project}
unit: {unit-id}
verdict: APPROVED | REJECTED
---
# Review: {Project}
Diff: {base}...HEAD — {n} files. Sources: {ADRs, rule files, packs, project review command}
## Blocking — {finding} ({file}:{line}) — breaks {source} → {required change}
## Non-blocking — {finding} ({file}:{line}) — {source or "generic"}
## Contract compatibility — | Operation | Declared class | Observed change | Verdict |
## Prior findings (re-review) — {finding} — resolved | still open
```
Overwrite it on every run; keep it on approval (`sk.implement --refine` reads it).

After an approval that followed a rejection, append to the unit's `knowledge-base.md` under
`## Implementation Pitfalls`: `- [{story-id}] {what was wrong} → {the correct pattern} (source: …)`. A
pitfall that is a checkable rule the project has not written down yet is marked `(candidate rule)`;
promotion at ship moves it to `.claude/rules/`.

## Completion report and signal
```
sk.review — {unit-id} / {Project}: {APPROVED | REJECTED} ({n} blocking, {m} non-blocking)
Next: REJECTED → /sk.implement --projects {Project} --refine; APPROVED → /sk.review --projects {next},
      or /sk.uat (user-facing units) / /sk.security-audit when every project is approved — in a fresh session
```
Last line, exactly one of:
- `SK_RESULT: PASS` — approved, and every other impacted project's review.md says `verdict: APPROVED`
- `SK_RESULT: PARTIAL` — approved; other projects are still to review
- `SK_RESULT: FAIL` — rejected

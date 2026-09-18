# sk.refactor
Scoped technical debt resolution — no new behaviour.
Role: backend | frontend | Level: unit or cross-unit

## Mode declaration
Declare at start: `[REFACTOR MODE] No new behaviour. Scope: {user-supplied scope}.`

## Pre-flight
1. Read session.yaml role
   NULL → ask user: "backend or frontend refactor?"
2. Ask user to state the refactor scope in one sentence:
   "What area are you refactoring and what is the problem being solved?"
   Record as: scope_statement
3. Confirm invariant: "This refactor introduces no new behaviour and changes no public API contracts. Correct? (y/n)"
   On n → STOP: use sk.story + sk.plan + sk.implement instead
4. Identify the target project: the project in `.specify/memory/projects/index.md` whose Code Root contains the
   scope (or the active unit's Impacted Projects row matching the role). Record `{Project}` / `{ProjectType}`.

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `refactor`,
in-scope project = `{Project}` (or the role's project type if no project resolved), signals = scope_statement.
Budget for this skill: at most 4 packs.

## Context loading (cacheable — load first)
1. The project's coding-standards.md (Tier A)
2. .specify/memory/architecture-decisions.md — check no ADR blocks the change (Tier A)

## Target context (tail — load LAST)
Target-area source files are read via Read tool at execution time (results flow post-boundary naturally). Emit prior refactor-plan.md (if present) at end of user-input block, after all cacheable context:
```
<refactor scope="{scope_statement}">
  <prior-plan>…refactor-plan.md (if present)…</prior-plan>
</refactor>
```

## Step 1 — Write refactor plan
Write refactor-plan.md covering:
- Scope statement (from pre-flight)
- Current state: what smells / violations are present (list with file:line references)
- Target state: what patterns/abstractions replace them
- Change list: ordered steps (each step independently compilable/testable)
- Invariants preserved: public API shapes, observable behaviour, data contracts
- Rollback: is this a branch? If yes, note branch name. If inline, note last safe commit.

Write to: specs/intents/{intent}/units/{unit}/refactor-plan.md
(or .specify/refactor-plan.md if not unit-scoped)
Display plan. Ask: "Proceed with this refactor? (y/n)"

## Step 2 — Execute change list
Execute each step in order from refactor-plan.md:
- Read existing code before editing
- Match established patterns — do not introduce new abstractions not listed in the plan
- After each step: verify compilation / type-check where possible
- Mark each step complete in refactor-plan.md as [X]
- No cleanup outside the declared scope

## Step 3 — Verify
Run existing tests (do not write new tests for refactored internals unless tests were also in poor shape and listed in plan):
- All pre-existing tests must still pass
- No test deletions — if a test breaks, fix the test to match the preserved public interface, not the implementation
- Report: tests passed / tests updated / tests requiring attention

## Output Artifacts
specs/intents/{intent}/units/{unit}/refactor-plan.md (or .specify/refactor-plan.md)
{CodeRoot}/** (refactored files, no net new files beyond renames)

## Quality Bar
- No new public API surface introduced
- No story acceptance criteria changed as a side effect
- Every change step in refactor-plan.md marked [X]
- Pre-existing tests pass after refactor
- No ADR violated

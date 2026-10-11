# Promote, then Freeze
Framework-owned. Run by sk.ship before the PR is created, and checked by its ship gate.

A unit folder holds in-flight reasoning. When the unit ships, the knowledge the code cannot give moves
to its one home (`governance/profile.md`), and the unit folder is frozen. Nothing is lost and nothing
is kept twice.

## What to promote
Read the active unit's `knowledge-base.md`, `02-design/architecture.md`, `02-design/contract-changes.md`,
`investigation-report.md` (if any) and each project's `04-implementation/{Project}/review.md`. For each item, choose one target:

| The item is… | Target | How |
|---|---|---|
| A decision with system or cross-module reach, or one that future work must not silently undo | an ADR | `sk.adr` (it routes the ADR in `adr-index.md`) |
| A domain rule, invariant or rationale for one bounded context | `specs/domain/{module}.md` | write into its existing sections; register a new module in `bounded-contexts.md` |
| A checkable coding rule (the reviewer would reject code that breaks it) | `.claude/rules/{area}/<topic>.md` | per the writing rules in `governance/profile.md` |
| A principle the team now holds for every decision | `.claude/rules/principles.md` → Principles | only when the human confirms it |
| Derivable from the code, the contracts or git history | nothing | — |

Do not copy unit prose. Write only the non-derivable essence, in the home's own format.

## Record
Write `UNIT_DIR/promotion.md`:
```
# Promotion — {unit-id}
Date: {date}
| Item | Target | Change |
|---|---|---|
| {one line} | {path} | {added / amended section / ADR-NNNN} |
```
or, when nothing qualifies, the single line `Nothing to promote — {reason}.`

Show the list at the ship gate. Promotion writes happen on the feature branch and ship in the same PR.

## Freeze
When sk.ship emits `SK_RESULT: PASS`, the Stop hook sets `status.current: shipped`. From then on:
- the unit folder is read-only (`validate-path.sh` blocks Edit/Write; only sk.hotfix may write there);
- the folder is excluded from all loading except while it is the active unit (`guard-read.sh`).
New work on the same feature starts a new unit.

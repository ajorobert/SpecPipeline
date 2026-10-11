# Consistency check (read-only)
Run by an `sk-reviewer` subagent for the active unit. Write nothing; report findings only.

## Read
`bash .claude/hooks/context.sh plan` lists the unit's files. Read the unit-brief, the story folder,
`02-design/` (architecture, impact analysis, data model, contract changes, project pages), every
`03-plan/*/plan.md` and `tasks.md`, `specs/domain/bounded-contexts.md` and the touched domain files, and
the ADRs `specs/adr/adr-index.md` routes for this unit. For contracts, read the branch diff:
`git diff $(git merge-base {vcs.base_branch} HEAD) -- specs/openapi specs/asyncapi` (base from
`.specify/profile.yaml`, default `dev`) — only the hunks of the files contract-changes.md names, plus the
file list to catch unlisted changes.

## Checks
| Id | Check | Severity when it fails |
|---|---|---|
| A | The story is covered by architecture.md | CRITICAL |
| B1 | Every operation changed in the diff has a row in contract-changes.md and every row a hunk (same file, operation, kind); a diff without a change list, or the reverse | HIGH |
| B2 | Every row's compatibility class fits the diff (a removal is never `additive`) | HIGH |
| B3 | A `breaking` row names a versioned replacement or an accepting ADR | CRITICAL |
| B4 | Consumers per row are impacted projects (or named out of scope) and agree with the router's Role | HIGH |
| C | Every entity in database-design.md belongs to a registered context and does not contradict its domain file or redefine an existing entity | HIGH |
| D1 | No plan contradicts architecture.md or its project page, or claims another project's work | HIGH |
| D2 | No plan depends on an external service the design does not list | HIGH |
| D3 | Each plan's Sequence follows impact-analysis.md → Sequencing & Dependencies | MEDIUM |
| D4 | A Frontend/Mobile plan consumes only operations present in the spec on this branch | HIGH |
| E1 | Every impacted project has plan.md and tasks.md | HIGH |
| E2 | tasks.md covers every Files Affected row, and every task names files and an acceptance signal | MEDIUM |
| F | No unit entity is owned by another context; cross-context access goes through a contract or a declared relation | CRITICAL |
| G | Nothing violates a routed ADR or a principle | CRITICAL |

## Report
`| Id | Severity | Location | Finding | Recommendation |`, then counts by severity and a coverage line per
project (plan.md, tasks.md present). No findings: "All consistency checks passed" with the coverage lines.

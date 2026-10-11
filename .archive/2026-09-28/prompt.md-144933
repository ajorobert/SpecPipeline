# sk.review
Spec-aware code review: judges the diff against the project's constitution, ADRs and rules, and the
unit's story, design, contracts and plan.
Role: backend, frontend | Level: project within the active unit

The framework ships no review rules of its own. Every blocking finding cites the source it breaks: a
constitution principle, a routed ADR, a rule file under `.claude/rules/{stack}/`, a loaded review pack,
or the unit's own story / design / contract change list / plan.

## Invocation Forms
- `sk.review --projects {key}` — review one impacted project (resolved per `.claude/skills/governance/project-resolution.md`)
- `sk.review` — review the impacted project matching session.yaml `role` (backend → Backend, frontend → the
  Frontend/Mobile project); if more than one matches, STOP and list candidates

## Pre-flight
1. Run the story pre-flight in `.claude/skills/governance/preflight.md` (active story, UNIT_DIR, Impacted
   Projects, knowledge, `.specify/profile.yaml`).
2. Resolve the target `{Project}` / `{CodeRoot}` / `{ProjectType}`. Log the resolution.
3. Determine the diff: `git diff {vcs.base_branch}...HEAD -- {CodeRoot}` (default base `dev`), plus
   `git diff {vcs.base_branch}...HEAD --` the canonical contract files listed in
   `02-design/contract-changes.md`. If the diff is empty: STOP — "Nothing to review for {Project}."
4. Mode: **REFINE** when `04-implementation/{Project}/review-{story-id}.md` exists with `Status: REJECTED`
   — re-review against the prior findings first (each one resolved / still open), then the rest of the
   diff. Otherwise **NEW**.

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `review`,
in-scope project = `{Project}` (`{ProjectType}`), working text = story + `03-plan/{Project}/plan.md`.

## Context loading (cacheable — load first)
Homes and loading rules per `.claude/skills/governance/profile.md`:
- `.specify/memory/constitution.md` — the project's fixed principles (Tier A)
- `specs/adr/adr-index.md` → the ADRs of its ALWAYS block and of every block whose signals match the
  story tags, the unit's text and the files in the diff (Tier A). Never glob `specs/adr/`.
- The project's rules: every file in the `.claude/rules/{stack}/` folders mapped to `{Project}` by
  `rules.stacks` (default Backend → `backend`, Frontend → `web`, Mobile → `mobile`) (Tier A).
  A missing folder logs `.claude/rules/{stack}/ not present — skipped`.
- The review packs loaded in Step 0 (Tier A)
- `specs/domain/bounded-contexts.md` + the `specs/domain/{module}.md` files of the contexts the unit touches (Tier B)
- UNIT_DIR/02-design/architecture.md — bounded context, module boundaries, owned entities (Tier B)
- UNIT_DIR/02-design/contract-changes.md — operations and their compatibility classes (Tier B)
- UNIT_DIR/02-design/projects/{Project}.md — the project's design slice (Tier B, if present)
- `contracts.compat_rules` from the profile — the file defining compatibility classes (Tier B; `null` →
  the classes `additive | deprecating | breaking`)

## Story context (tail — load LAST)
Emit at end of user-input block, after all cacheable context:
```
<story id="{story-id}" project="{Project}">
  <story-md>…UNIT_DIR/01-story/story.md + acceptance-criteria.md…</story-md>
  <plan-md>…UNIT_DIR/03-plan/{Project}/plan.md (if present)…</plan-md>
  <implementation>…UNIT_DIR/04-implementation/{Project}/implementation.md (changed files)…</implementation>
  <prior-review>…UNIT_DIR/04-implementation/{Project}/review-{story-id}.md (if present)…</prior-review>
  <diff>…the code diff and the canonical contract diff from Pre-flight step 3…</diff>
</story>
```

## Review
Surface to the agent, then judge every hunk of the diff:

"Reviewing story: {story-id} — {story title} — project {Project} ({CodeRoot})
Bounded context: {unit name}. This unit owns: {entities/services from architecture.md}.
Must NOT cross into: {other contexts named in architecture.md dependencies / bounded-contexts.md}
Constitution: {principles that bear on this diff}
ADRs routed: {ADR ids + one-line constraint each}
Rules: {rule files read, by stack}
Loaded review packs: {from Step 0} — apply their review checks."

1. **Constitution, ADRs, rules** — for each hunk, does it break a constitution principle, a routed ADR's
   decision or rule, or a rule file in the project's stack folders? Cite the exact source
   (`constitution §…`, `ADR-NNNN`, `.claude/rules/{stack}/<file>.md`). A violation is BLOCKING.
   Where an ADR and the existing code disagree, the ADR wins (`governance/profile.md` → Precedence).
2. **Contracts** — does the code implement exactly the operations in `contract-changes.md`, as the
   canonical spec defines them on this branch? Any operation, field or response shape that is in the
   code but not in the canonical spec (or the reverse) is BLOCKING. For each changed operation, check
   the canonical diff against its declared compatibility class using `contracts.compat_rules`: a class
   that understates the change (for example a removal or a narrowed type marked `additive`), or a
   `breaking` change with no versioned replacement or accepting ADR, is BLOCKING.
3. **Story, design, plan** — does the diff realize the acceptance criteria and the plan's tasks for
   `{Project}`, inside the unit's bounded context? Crossing into another context's internals, an
   undesigned persisted entity, or behaviour the story does not ask for is BLOCKING.
4. **Review packs** — apply the loaded packs' review checks. A pack finding is BLOCKING only when the pack
   marks it so and no higher source (constitution, ADR, rules) decides otherwise.
5. **Generic questions** (non-blocking unless a higher source makes them rules): was the existing code
   in the target area read before writing, or does a new abstraction duplicate an existing one? Are
   failure modes of new external calls handled as the design documents them? Is the declared consistency
   requirement honoured on each write path? Do the tests added match the Test Plan?
6. Flag every conflict between sources (for example a pack contradicting a rule) with the winning source.

## Output Artifact
Write the review report to:
  UNIT_DIR/04-implementation/{Project}/review-{story-id}.md
(sk.implement → sk.implement_sub_codegen reads this path to enter REFINE mode.)

Format:
```
# Review: {story-id} — {Project}
Date: {YYYY-MM-DD}
Status: REJECTED | APPROVED
Diff: {base}...HEAD — {files reviewed}
Sources: constitution; ADR-{…}; .claude/rules/{stack}/{…}; packs {…}

## Blocking Findings
- {finding} ({file}:{line}) — breaks {source} → {required action}

## Non-Blocking Findings
- {finding} ({file}:{line}) — {source or "generic"}: {description}

## Contract Compatibility
| Operation | Declared class | Observed change | Verdict |

## Prior Findings (REFINE only)
- {finding} — resolved | still open
```

On REJECTED: write/overwrite the file with current findings.
On APPROVED: keep the review report at its path.
1. If any blocking findings were raised during this review cycle (i.e. an earlier review of this story was REJECTED):
   Append a `## Implementation Pitfalls` entry to the unit knowledge base:
     UNIT_DIR/knowledge-base.md
   Format:
   ```
   ## Implementation Pitfalls
   <!-- Lessons from review cycles — sk.implement reads this to avoid repeating issues -->
   - [{story-id}] {short description of what was wrong} → {what the correct pattern is} (source: {ADR / rule / constitution})
   ```
   If the section already exists, append to it rather than replacing it. A pitfall that is a checkable
   rule the project has not yet written down is marked `(candidate rule)`; promotion at ship moves it to
   `.claude/rules/{stack}/` (`governance/promotion.md`).
2. Keep the review report at its path — do NOT archive it on approval.
   Non-blocking findings remain available for the developer to act on via sk.implement.

## Quality Bar
- Every blocking finding cites the constitution clause, ADR, rule file, pack, or unit artifact it breaks —
  never a framework default
- No bounded context violations
- No operation or shape in the code that the canonical contract does not define; every compatibility
  class checked against `contracts.compat_rules`
- No violation of a routed ADR or a rule in the project's stack folders
- Review checks of loaded review packs applied
- In REFINE mode, every prior finding is marked resolved or still open

## Completion Signal
Last line of output must be exactly one of:
`SK_RESULT: PASS` — Status is APPROVED, no blocking findings
`SK_RESULT: FAIL` — Status is REJECTED, blocking findings present

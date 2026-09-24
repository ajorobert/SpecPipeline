# sk.adr
Creates an Architecture Decision Record and routes it from the ADR index.
Role: architect | Level: unit or intent

ADRs live at one fixed home (`.claude/skills/governance/profile.md` → The homes):
`specs/adr/NNNN-kebab-title.md`, routed by `specs/adr/adr-index.md` — a router of an ALWAYS block and
task-signal blocks, not a table. Every ADR file is routed from the index and every route resolves;
`check-adr-index.sh` guards both.

## Input Artifacts
.specify/state/session.yaml (active_intent_id, active_unit_id, active_story_id)
.specify/profile.yaml (`knowledge.adr.exemplar`, `knowledge.adr.guard`, `rules.stacks`, `knowledge.never_autoload`)
specs/adr/adr-index.md (and the ADRs it routes to this decision)
.specify/memory/constitution.md
The active unit's `02-design/architecture.md` and `knowledge-base.md`, when the decision comes from a unit

## Resolve paths
- `SCRIPTS_DIR` and `TEMPLATES_DIR` per `.claude/skills/governance/framework-paths.md`.
- Read `.specify/profile.yaml` once; absent keys take the defaults in `governance/profile.md`
  (`knowledge.adr.exemplar: null`, `knowledge.adr.guard: true`).
- Never read a path matched by `knowledge.never_autoload`, and never glob `specs/adr/`.

## Steps

### 1. Collect
Gather from the user (pre-fill from the unit's design when invoked from one):
- title (short, names the decision, not the problem)
- context — the forces and constraints that made a decision necessary
- decision — what was chosen, in one paragraph
- rules — what an implementer must or must not do, as short checkable lines
- alternatives rejected — **at least 2**, each with the reason it lost
- consequences — **at least one positive and one negative**, plus follow-ups
- whether it supersedes an existing ADR
- the signals it answers — the kinds of work that must load it (story tags, file areas, request words)
Do not proceed with fewer than 2 rejected alternatives or without a negative consequence; ask again.

### 2. Check against what is already decided
1. Read `specs/adr/adr-index.md` and follow its own loading rules: load the ALWAYS block's ADRs and
   the ADRs of every signal block that matches this decision's signals.
2. An ADR that already makes this decision → stop and offer to amend or supersede it instead of
   writing a duplicate.
3. A conflict with `.specify/memory/constitution.md` → STOP: the constitution outranks ADRs
   (`governance/profile.md` → Precedence). Report the principle; only the team changes it.
4. A conflict with a routed ADR that is not being superseded → report it and ask whether this ADR
   supersedes that one.

### 3. Reserve the file
Run `bash {SCRIPTS_DIR}/create-adr.sh "<title>"`. It prints the created path, e.g.
`specs/adr/0028-outbox-for-integration-events.md`; `NNNN` is the number in that file name. Never pick
the number or the file name yourself.

### 4. Write the ADR
- **Shape.** When `knowledge.adr.exemplar` is set, read that ADR and copy its headings, their order
  and its heading-line and status-line style — not its content. Otherwise use
  `{TEMPLATES_DIR}/artifacts/adr-template.md`: `# ADR-NNNN: Title`, then `## Status`, `## Rules`,
  `## Decision`, `## Context`, `## Consequences`, `## Alternatives rejected`, `## Provenance`.
- **Status.** `Proposed` until the user accepts the decision, then `Accepted` — with the date.
- **Rules** come first in the body when the shape has such a section: they are what gets loaded when
  the index routes here. Keep them checkable; leave rationale to Decision and Context.
- **Provenance.** Intent, unit and story IDs from session.yaml, and the ADR it supersedes (or none).

### 5. Route it from the index
- If `specs/adr/adr-index.md` is missing, create it from `{TEMPLATES_DIR}/artifacts/adr-index-template.md`,
  dropping the template's placeholder entries.
- Register the ADR by the index's **own** rules and line format (read its loading rules and copy the
  shape of an existing entry):
  - it binds every change → add a line to the ALWAYS block (keep that block short; ask before adding);
  - otherwise → add a line to each signal block whose signals it answers;
  - only when no block fits → add one new signal block, its heading a short list of lower-case signals
    (prefer words already used as story tags — the Signals column of `.claude/skills/README.md` →
    `## Registry`), placed with related blocks.
- Never append a flat row, a table row or an unsorted list at the end of the index.
- The line names the ADR, links its file name (`NNNN-kebab-title.md`) and says in one line what it constrains.

### 6. Supersede (only when this ADR replaces one)
1. In the old ADR, set Status to `Superseded by ADR-NNNN — {date}`. Change nothing else in it.
2. In the index, remove the old ADR's lines from the ALWAYS and signal blocks and route it only from
   under the successor's line (for example an indented `- supersedes [ADR-MMMM: …](MMMM-….md)`), so it
   stays routed but is loaded only through its successor.
3. Put the successor in every block the old ADR was in that still applies, plus any new ones.

### 7. Offer checkable rules
If the ADR's Rules include lines a reviewer would check file by file, offer to also write them to
`.claude/rules/{stack}/<topic>.md` for the stacks `rules.stacks` maps to the affected projects. On yes,
follow the rule-writing rules in `governance/profile.md`: from `{TEMPLATES_DIR}/artifacts/rule-template.md`
when creating a file, self-contained, under 200 lines, `paths:` frontmatter, `Source: ADR-NNNN` as
provenance only, no `@import`. Into an existing rule file, add only the lines, in its format. On no,
leave them in the ADR only.

### 8. Guard
When `knowledge.adr.guard` is true (the default), run `bash {SCRIPTS_DIR}/check-adr-index.sh`. On FAIL,
fix what it lists — route an `unrouted` ADR in its matching block; correct a `dangling` route to the
real file name — and run it again until it prints PASS. Never make it pass by removing a route to an
ADR file that exists.

### 9. Knowledge base
Append only the non-derivable essence — the decision in one line, why, and what was rejected, with a
pointer `ADR-NNNN` — at the most specific tier it concerns, into that file's existing section:
- system-wide decision → `specs/knowledge-base.md` → Evolution History
- one bounded context → `specs/domain/{module}.md` → its rationale / tried-and-rejected section
- one unit → the unit's `knowledge-base.md` → Key Decisions and Their Reasons
Never copy the ADR's Rules or full text into a knowledge base. Skip this step when the ADR adds
nothing a reader of the ADR would miss.

## Output Artifacts
specs/adr/NNNN-kebab-title.md
specs/adr/adr-index.md (routed in its matching blocks; created from the template only if absent)
specs/adr/MMMM-….md Status line (only when superseding)
.claude/rules/{stack}/<topic>.md (only when the user accepts step 7)
knowledge base at the relevant tier (essence and pointer only)

## Completion Report
```
sk.adr complete.
ADR: ADR-NNNN — {title} ({Proposed | Accepted})
File: specs/adr/NNNN-kebab-title.md
Routed from: {ALWAYS | block "signal, signal" | new block "signal, signal"}
Supersedes: {ADR-MMMM | none}
Rules written: {.claude/rules/{stack}/<topic>.md | none}
ADR guard: {PASS | skipped — knowledge.adr.guard is false}
```

## Quality Bar
- At least 2 rejected alternatives, each with a reason
- Consequences have both positive and negative entries
- Shape follows the exemplar when set, else the framework template
- Provenance names the intent, unit and stories
- Routed from the index's matching block(s) by the index's own rules — never a flat appended row
- A superseded ADR is routed only from its successor, and its Status says so
- ADR guard PASS (unless `knowledge.adr.guard` is false)

# sk.design_sub_datamodel
Defines data model for a unit.
Role: architect | Level: unit
ONE document per unit.

Internal sub-skill — invoked by sk.design. Do not invoke directly.

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `design`.

Resolve `TEMPLATES_DIR` per `.claude/skills/governance/framework-paths.md` before reading any template.

## Design Output Layout
This sub-skill writes `02-design/database-design.md`, the unit data model
(tree: `.claude/skills/governance/phase-layout.md`). Read the architecture from `02-design/architecture.md`.
Entities and schema live in the code; there is no central entity list. Domain invariants and rationale
that outlive the unit go into the owning `specs/domain/{module}.md` (`governance/profile.md`).

## Input Artifacts
specs/intents/{intent}/units/{unit}/02-design/architecture.md
specs/domain/bounded-contexts.md, then the `specs/domain/{module}.md` of each context the unit touches
The existing entity and schema code of those contexts (paths from bounded-contexts.md `Code` and the
project's `{CodeRoot}`)
specs/adr/adr-index.md, then the ADRs it routes for this work
.specify/memory/constitution.md
The schema-owning project's `.claude/rules/{stack}/` folder (`rules.stacks` in `.specify/profile.yaml`)
Design-phase packs loaded in Step 0 (if any)

## Steps
1. [REFINE MODE] if database-design.md exists, [CREATE MODE] if not
2. Conflict check before writing: read `specs/domain/bounded-contexts.md` (who owns what), the owning
   domain files, and the existing entity code. Flag any entity this unit would create or change that
   another context owns, or that already exists under another name.
3. Design entities for the unit. Judge them against the constitution, the routed ADRs, the stack's
   `.claude/rules/` and any loaded design-phase pack — the framework adds no data rules of its own.
4. If REFINE: preserve existing entities, mark removed ones as deprecated;
   never delete — append a revision note
5. Classify schema changes: additive | breaking
   breaking → flag to user, wait for confirmation
6. Write the data model to `02-design/database-design.md`
7. Domain knowledge: when the design establishes an invariant, business rule or rationale that holds
   for the whole bounded context (not only this unit), write it into the owning `specs/domain/{module}.md`,
   into its existing sections (for example Invariants, Rationale, Tried and rejected). Add the smallest
   heading that fits only when no section does. If the file does not exist (a context created by the
   architecture phase is already there), create it with the template named by `knowledge.domain.template`
   (`default` = `{TEMPLATES_DIR}/artifacts/domain-template.md`; `none` = headings only as needed; a
   path = that file) and register it in `bounded-contexts.md` in the same change. Write only the
   non-derivable essence — never entity field lists.

## Output Artifacts
specs/intents/{intent}/units/{unit}/02-design/database-design.md
specs/domain/{module}.md (invariants and rationale, when any arose)

## Quality Bar
- Data model written to `02-design/database-design.md`
- No entity conflicts with another context's ownership (bounded-contexts.md, domain files, code)
- No contradiction of the constitution, the routed ADRs, or the stack's `.claude/rules/`
- Migration strategy defined for breaking changes
- Revision note appended if REFINE MODE
- An access strategy defined for every query pattern in the Access Patterns section of architecture.md
- Transaction boundaries and isolation level declared for each write path
- Domain invariants written into the owning `specs/domain/{module}.md` in its own format; no entity lists copied there
- `[REQUIRED]` rules of any loaded design-phase pack satisfied

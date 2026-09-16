# sk.datamodel
Defines data model for a unit.
Role: architect | Level: unit
ONE document per unit.

Internal sub-skill — invoked by sk.design. Do not invoke directly.

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `design`.

## Design Output Layout
This sub-skill writes `02-design/database-design.md`, the unit data model
(tree: `.claude/skills/governance/phase-layout.md`). Read the architecture from `02-design/architecture.md`.

## Input Artifacts
specs/intents/{intent}/units/{unit}/02-design/architecture.md
.specify/memory/domain-model.md
.specify/memory/standards/data-standards.md
Design-phase packs loaded in Step 0 (if any)

## Steps
1. [REFINE MODE] if database-design.md exists, [CREATE MODE] if not
2. Check domain-model.md — flag conflicts before writing
3. Design entities following data-standards.md and any loaded design-phase pack
4. If REFINE: preserve existing entities, mark removed as deprecated
   never delete — append revision note
5. Classify schema changes: additive | breaking
   breaking → flag to user, wait for confirmation
6. Write the data model to `02-design/database-design.md`

## Output Artifacts
specs/intents/{intent}/units/{unit}/02-design/database-design.md
.specify/memory/domain-model.md (updated with new entities)

## Quality Bar
- Data model written to `02-design/database-design.md`
- No entity conflicts with existing domain-model.md
- All required fields per data-standards.md present
- Migration strategy defined for breaking changes
- Revision note appended if REFINE MODE
- Index strategy defined for every query pattern in Access Patterns section
- Transaction boundaries and isolation level declared for each write path
- `[REQUIRED]` rules of any loaded design-phase pack satisfied

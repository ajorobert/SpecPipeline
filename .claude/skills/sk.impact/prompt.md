# sk.impact
Assesses blast radius of proposed work before starting.
Role: architect | Level: intent

## Input Artifacts
Loaded per the loading rules in `.claude/skills/governance/profile.md`:
specs/knowledge-base.md  — system overview (already in context through CLAUDE.md)
.specify/memory/projects/index.md  — every project: Type, Code Root, Role
specs/domain/bounded-contexts.md, then the `specs/domain/{module}.md` of each context the work touches
specs/adr/adr-index.md  — the ADRs it routes for this work (ALWAYS block + matching signal blocks)
specs/openapi/ and specs/asyncapi/  — the contract files; list them, and read only the operations and
  channels the proposed work would touch (they are the service registry; consumers come from
  projects/index.md Role and the routed ADRs)
.claude/skills/governance/checkpoint-rules.md  — drives step 4 (recommended checkpoint_mode)

A home that does not exist is logged `{home} not present — skipped`. Never read a path matched by
`knowledge.never_autoload` in `.specify/profile.yaml`.

## Steps
1. Collect from user: proposed intent/unit description
2. Evaluate project impact (every project in projects/index.md), domain impact (bounded contexts and
   their invariants), contract impact (operations and channels touched, their consumers, likely
   compatibility class), and cross-cutting impact (routed ADRs the work would touch or contradict)
3. Classify risk: LOW | MEDIUM | HIGH
4. Determine recommended checkpoint_mode
5. Write impact report

## Output Artifacts
specs/intents/{intent}/impact-{date}-{NNN}.md
(NNN increments if multiple reports same date)

## Quality Bar
- All existing projects evaluated for impact
- Contract impact stated per canonical file, with consumers
- Domain conflicts explicitly identified
- ADR requirement stated clearly (new ADR needed, or which routed ADR the work must respect)
- Checkpoint recommendation justified

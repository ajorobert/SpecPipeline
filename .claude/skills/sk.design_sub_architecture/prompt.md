# sk.design_sub_architecture
Defines service boundaries and design for a unit.
Role: architect | Level: unit
ONE document per unit — covers the unit's story.

Internal sub-skill — invoked by sk.design. Do not invoke directly.

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `design`.

Resolve `TEMPLATES_DIR` per `.claude/skills/governance/framework-paths.md` before reading any template.

## Design Output Layout
This sub-skill writes `02-design/architecture.md` and `02-design/impact-analysis.md`
(tree: `.claude/skills/governance/phase-layout.md`). Create the `02-design/` folder if it does not exist.

## Input Artifacts
specs/intents/{intent}/units/{unit}/unit-brief.md
specs/intents/{intent}/units/{unit}/01-story/ (story.md, requirement.md, acceptance-criteria.md)
.specify/memory/domain-model.md
.specify/memory/service-registry.md
.specify/memory/architecture-decisions.md
Design-phase packs loaded in Step 0 (if any)

## Steps
1. [REFINE MODE] if architecture.md exists, [CREATE MODE] if not
2. If REFINE: read existing fully, preserve valid content, update changed sections
3. Read the unit's story (`01-story/`) — confirm the architecture covers it
4. Define: service responsibility, bounded context, communication
   patterns, internal components, data flow, security approach
5. Write architecture document to `02-design/architecture.md`
   (use `{TEMPLATES_DIR}/artifacts/architecture-template.md` as the structure)
6. Write the impact analysis to `02-design/impact-analysis.md`:
   - Read `unit-brief.md` → Impacted Projects table (canonical list of affected projects)
   - For each project, record change type (new | modified | config-only | none) and what the
     design changes in it; capture cross-project contracts and sequencing/dependencies
   - Use `{TEMPLATES_DIR}/artifacts/impact-analysis-template.md` as the structure
   - This is the design-phase, unit-scoped impact view; it does NOT replace sk.impact's
     blast-radius report. Every project in unit-brief.md must appear exactly once.
7. If validate checkpoint: pause for user approval before continuing
8. Suggest ADR for any cross-service decision made

## Engineering Review (mandatory — runs after steps 5–6)
Validate the written architecture against:
- `.specify/memory/service-registry.md` — no new service boundary violations
- `.specify/memory/domain-model.md` — no entity ownership conflicts with existing units
- `.specify/memory/architecture-decisions.md` — no contradiction of existing ADR decisions
- design-phase packs loaded in Step 0 (if any) — their `[REQUIRED]` rules raise MEDIUM findings,
  their `[Advisory]` rules raise ADVISORY findings

Flag findings as:
- BLOCKING: boundary violation, entity ownership conflict, or direct ADR contradiction
  → fix architecture before proceeding
- MEDIUM: consistency violation (undeclared or incorrect consistency level for a write path),
  missing index coverage for a query pattern, N+1 risk on a read path, undeclared
  transaction boundary on a write path, missing failure mode for an external dependency,
  or a violated `[REQUIRED]` rule from a loaded design-phase pack
  → must be resolved before proceeding; counts as a blocker in autopilot mode
- ADVISORY: new cross-service decision introduced
  → suggest creating an ADR via sk.adr before implementation begins

If all checks pass: report "Engineering review passed — no findings."
If only ADVISORY findings: report "Engineering review passed with advisories." and list them.
If any MEDIUM or BLOCKING findings exist: report "Engineering review FAILED." and list all findings.

## Output Artifacts
specs/intents/{intent}/units/{unit}/02-design/architecture.md
specs/intents/{intent}/units/{unit}/02-design/impact-analysis.md
specs/intents/{intent}/units/{unit}/knowledge-base.md
  (unit-tier KB stays at unit root — boundary section updated if architecture changes domain ownership)

## Steps (continued)
9. If architecture introduces or changes domain boundary:
   Update unit knowledge-base.md boundary rationale
   If boundary change is significant: suggest domain-level
   knowledge base update via sk.knowledge-base --tier domain

## Quality Bar
- Both `02-design/architecture.md` and `02-design/impact-analysis.md` written
- impact-analysis.md lists every project from unit-brief.md Impacted Projects exactly once, each with a change type
- The unit's story explicitly listed in stories-covered
- Bounded context clearly defined
- No conflicts with service-registry.md
- Security approach defined
- Open questions listed not hidden
- Consistency requirement declared for every write path (strong / eventual / causal)
- Failure mode documented for every external dependency (timeout, fallback, circuit breaker)
- Significant design decisions recorded in unit knowledge-base (why, not what)
- Rules of any loaded design-phase pack applied; packs loaded are listed in the log

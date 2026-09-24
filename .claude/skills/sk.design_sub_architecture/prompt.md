# sk.design_sub_architecture
Defines service boundaries and design for a unit.
Role: architect | Level: unit
ONE document per unit — covers the unit's story.

Internal sub-skill — invoked by sk.design. Do not invoke directly.

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `design`.

Resolve `TEMPLATES_DIR` and `SCRIPTS_DIR` per `.claude/skills/governance/framework-paths.md` before
reading any template.

## Design Output Layout
This sub-skill writes `02-design/architecture.md` and `02-design/impact-analysis.md`
(tree: `.claude/skills/governance/phase-layout.md`). Create the `02-design/` folder if it does not exist.
It writes the domain homes (`specs/domain/`) only when the unit introduces a new bounded context.

## Input Artifacts
Loaded per the loading rules in `.claude/skills/governance/profile.md`:
specs/intents/{intent}/units/{unit}/unit-brief.md
specs/intents/{intent}/units/{unit}/01-story/ (story.md, requirement.md, acceptance-criteria.md)
specs/domain/bounded-contexts.md, then the `specs/domain/{module}.md` of each context the unit touches
specs/adr/adr-index.md, then the ADRs it routes for this work (ALWAYS block + matching signal blocks)
.specify/memory/projects/index.md (Project · Type · Code Root · Role)
.specify/memory/constitution.md
Design-phase packs loaded in Step 0 (if any)

A home that does not exist is logged `{home} not present — skipped`; never create a placeholder.

## Steps
1. [REFINE MODE] if architecture.md exists, [CREATE MODE] if not
2. If REFINE: read existing fully, preserve valid content, update changed sections
3. Read the unit's story (`01-story/`) — confirm the architecture covers it
4. Define: service responsibility, bounded context, communication
   patterns, internal components, data flow, security approach.
   Name the bounded context from `specs/domain/bounded-contexts.md`; a context not listed there is new.
5. Write architecture document to `02-design/architecture.md`
   (use `{TEMPLATES_DIR}/artifacts/architecture-template.md` as the structure)
6. Write the impact analysis to `02-design/impact-analysis.md`:
   - Read `unit-brief.md` → Impacted Projects table (canonical list of affected projects)
   - For each project, record change type (new | modified | config-only | none) and what the
     design changes in it; capture cross-project contracts and sequencing/dependencies
   - Use `{TEMPLATES_DIR}/artifacts/impact-analysis-template.md` as the structure
   - This is the design-phase, unit-scoped impact view; it does NOT replace sk.impact's
     blast-radius report. Every project in unit-brief.md must appear exactly once.
7. **New bounded context** (only when step 4 found one):
   - Add its row to `specs/domain/bounded-contexts.md` (Context · File · Owns · Code) and its relations
     to the Context map, in that file's existing format. If the file does not exist, create it from
     `{TEMPLATES_DIR}/artifacts/bounded-contexts-template.md`.
   - Create `specs/domain/{module}.md` using the template named by `knowledge.domain.template` in
     `.specify/profile.yaml` (`default` = `{TEMPLATES_DIR}/artifacts/domain-template.md`; `none` = only the
     headings needed; a path = that file). Fill only what the architecture establishes (purpose,
     language, relations); the datamodel phase adds invariants.
   - Both changes are made in the same step and shown at Gate 1.
8. Never pause here. sk.design owns Gate 1 and runs it in the main context. This worker runs as an isolated subagent and cannot pause, ask, or invoke an interactive skill
   (`.claude/skills/governance/worker-dispatch.md`).
9. **Decisions with cross-module reach** (they bind other contexts, other units, or future work that
   must not silently undo them): mark each one "ADR required" in `architecture.md` → Open Questions or
   the relevant section, and report one `ADR required: {decision}` line per decision. Never invoke
   sk.adr yourself — sk.design raises it in the main context after Gate 1, where it can interact.
   Do not record decisions in any summary or index file yourself — sk.adr routes the ADR in
   `specs/adr/adr-index.md`.

## Engineering Review (mandatory — runs after steps 5–7)
Validate the written architecture against the project's own sources, never against framework defaults:
- `.specify/memory/constitution.md` — no violation of a fixed principle
- the ADRs routed by `specs/adr/adr-index.md` — no contradiction of an accepted decision
- `specs/domain/bounded-contexts.md` and the touched `specs/domain/{module}.md` — no ownership
  conflict with another context, no violated invariant
- the project's `.claude/rules/{stack}/` folders for the impacted projects (`rules.stacks` in the profile) —
  no design that forces code to break a rule
- `.specify/memory/projects/index.md` — every project named in the design exists with the Type used
- design-phase packs loaded in Step 0 (if any) — their `[REQUIRED]` rules raise MEDIUM findings,
  their `[Advisory]` rules raise ADVISORY findings

Flag findings as:
- BLOCKING: ownership conflict with another bounded context, violation of the constitution, or direct
  contradiction of a routed ADR
  → fix architecture before proceeding
- MEDIUM: undeclared consistency requirement for a write path, undeclared transaction boundary on a
  write path, missing failure mode for an external dependency, a design that breaks one of the
  project's `.claude/rules/`, or a violated `[REQUIRED]` rule from a loaded design-phase pack
  → must be resolved before proceeding; counts as a blocker in autopilot mode
- ADVISORY: a decision with cross-module reach ("ADR required") not yet recorded as an ADR
  → report it as an `ADR required:` line; sk.design raises it before implementation begins

If all checks pass: report "Engineering review passed — no findings."
If only ADVISORY findings: report "Engineering review passed with advisories." and list them.
If any MEDIUM or BLOCKING findings exist: report "Engineering review FAILED." and list all findings.
Flag every precedence conflict (constitution → ADRs → rules → packs → design → code) per
`governance/profile.md` → Precedence.

## Output Artifacts
specs/intents/{intent}/units/{unit}/02-design/architecture.md
specs/intents/{intent}/units/{unit}/02-design/impact-analysis.md
specs/intents/{intent}/units/{unit}/knowledge-base.md
  (unit-tier KB stays at unit root — boundary section updated if architecture changes domain ownership)
specs/domain/bounded-contexts.md and specs/domain/{module}.md (new bounded context only)

## Steps (continued)
10. If architecture introduces or changes a domain boundary:
    Update unit knowledge-base.md boundary rationale.
    If an existing context's rules or rationale change: list it as ADVISORY for
    sk.knowledge-base --tier domain (`specs/domain/{module}.md`) — do not rewrite an existing domain file here.

## Quality Bar
- Both `02-design/architecture.md` and `02-design/impact-analysis.md` written
- impact-analysis.md lists every project from unit-brief.md Impacted Projects exactly once, each with a change type
- The unit's story explicitly listed in stories-covered
- Bounded context clearly defined and named as in `specs/domain/bounded-contexts.md`
- A new bounded context has its row in bounded-contexts.md and its own `specs/domain/{module}.md`
- No conflict with the constitution, the routed ADRs, or another context's ownership
- Every decision with cross-module reach marked "ADR required" in architecture.md AND reported as an
  `ADR required:` line — never raised by this worker
- Security approach defined
- Open questions listed not hidden
- Consistency requirement declared for every write path (strong / eventual / causal)
- Failure mode documented for every external dependency
- Significant design decisions recorded in unit knowledge-base (why, not what)
- Rules of any loaded design-phase pack applied; packs loaded are listed in the log

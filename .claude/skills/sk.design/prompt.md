# sk.design — Full Design Pipeline (Orchestrator)
Runs the complete unit design pipeline — architecture, data model, and API contracts — in one invocation.
Role: architect (orchestrator) | Level: unit

This skill orchestrates sub-skills in strict sequence. Each sub-skill is invoked with the **Skill
tool** — `Skill(sk.design_sub_architecture)` and so on — never by reading its prompt.md, so that
`skill-start.sh` runs its preconditions and sets the active role (`governance/status-model.md`).
Each sub-skill runs with its own isolated context — state is passed via the file system
(`.specify/state/session.yaml`, the unit's artifacts, and the canonical contract files on the branch).
Orchestrators do not resolve capability packs; each sub-skill resolves its own (phase = design).

## Design Output Layout
All unit design artifacts live under `specs/intents/{intent}/units/{unit}/02-design/`
(full tree: `.claude/skills/governance/phase-layout.md`). Per-project page names come from
`unit-brief.md` → Impacted Projects. Unit-tier `knowledge-base.md` and `guide.yaml` stay at the unit root.
Contracts are edited in place in `specs/openapi/` and `specs/asyncapi/`; the unit holds only the change
list `02-design/contract-changes.md`. Domain knowledge lives in `specs/domain/`, decisions in
`specs/adr/` (`.claude/skills/governance/profile.md`).

## Invocation Forms
- `sk.design`                        — auto-detect mode, run all needed phases
- `sk.design --architecture`         — run Phase 1 only (TARGETED)
- `sk.design --datamodel`            — run Phase 2 only (TARGETED)
- `sk.design --contracts`            — run Phase 3 only (TARGETED)
- `sk.design "<change description>"` — REFRESH mode: update affected artifacts, record decision

## Pre-flight
Run the unit pre-flight in `.claude/skills/governance/preflight.md`. This gives UNIT_DIR, DESIGN_DIR,
the Impacted Projects, and `checkpoint_mode` from `01-story/story.md` frontmatter. If the unit-brief
exists but is not populated, STOP and run sk.story first.

## Mode Detection
Evaluate in this order — first match wins:

**TARGETED** — a phase flag was passed (`--architecture`, `--datamodel`, `--contracts`)
  → run exactly that one phase, skip all others, no need detection

**REFRESH** — a quoted change description was passed as argument
  → all three artifacts exist; user is applying a custom change
  → see REFRESH workflow below

**RESUME** — no flag, no description, some artifacts exist but pipeline is incomplete
  Incomplete means: 02-design/architecture.md exists but 02-design/database-design.md or
  02-design/contract-changes.md is missing
  → start from first missing artifact, skip completed phases

**FRESH** — no flag, no description, 02-design/architecture.md does not exist
  → run phase need detection, then run all needed phases

## Phase Need Detection (FRESH and RESUME modes only)
Read the unit's story (`01-story/`). Determine which phases are needed:

- Phase 1 (architecture): always needed in FRESH mode
- Phase 2 (data model): needed if the story mentions entities, tables, schema, data,
  storage, persistence, cache, search, or file upload
  If not needed: log "Phase 2 skipped — no data persistence signals in stories"
- Phase 3 (contracts): needed if unit exposes or consumes APIs, events, or commands
  If not needed: log "Phase 3 skipped — no API/contract signals in stories"

In RESUME mode: only run phases whose output artifacts are missing.

## REFRESH Workflow
Triggered when: `sk.design "<change description>"` is called.

1. Read the change description
2. Determine affected phases:
   - Mentions endpoints, routes, operations, channels, request/response, versioning → Phase 3 (contracts)
   - Mentions tables, columns, entities, schema, indexes, migrations → Phase 2 (data model)
   - Mentions services, boundaries, components, patterns, dependencies → Phase 1 (architecture)
   - Ambiguous: default to all three phases and log reasoning
3. Record the decision in unit knowledge-base.md BEFORE running any phase:
   ```
   ## Custom Design Decision — {date}
   **Change:** {change description}
   **Affected phases:** {list}
   **Rationale:** recorded by sk.design REFRESH — governs future regeneration of these artifacts
   ```
4. If the change has domain-wide implications (new entity type, new bounded context,
   cross-unit contract change): flag as ADVISORY after recording
   → "This change may warrant sk.knowledge-base --tier domain (specs/domain/{module}.md). Proceeding with unit-level recording."
5. Run only the affected phases in sequence (Phase 1 → 2 → 3 order enforced even if subset)
6. Gates apply per normal gate schedule for the active checkpoint_mode

## Gate Schedule
Gate behaviour (display, approved/cancel handling, autopilot hard stops) follows
`.claude/skills/governance/review-gate.md`. This skill's schedule:

| checkpoint_mode | Gate 1 (after architecture) | Gate 2 (after data model) | Gate 3 (after contracts) | Gate 4 (after UI design) |
|---|---|---|---|---|
| autopilot | skip | skip | skip | skip |
| confirm | skip | PAUSE | PAUSE | PAUSE |
| validate | PAUSE | PAUSE | PAUSE | PAUSE |

Gate override: if 02-design/architecture.md does not yet exist AND unit introduces a new bounded context,
treat as validate regardless of checkpoint_mode.
Log: "Gate override: new bounded context detected — validate required."

In TARGETED and REFRESH modes: gates apply only to phases that actually run.

## Orchestration

### Phase 1 — Architecture
Condition: run if FRESH, or RESUME with 02-design/architecture.md missing, or TARGETED --architecture,
           or REFRESH with architecture in affected phases
Invoke with the Skill tool: `Skill(sk.design_sub_architecture)`
- The sub-skill loads its own context: `specs/domain/bounded-contexts.md` and the relevant domain files,
  `specs/adr/adr-index.md` and the ADRs it routes, `.specify/memory/projects/index.md`, the constitution
  (design-phase capability packs are resolved inside the sub-skill)
- Waits for: 02-design/architecture.md and 02-design/impact-analysis.md written and engineering review passed

Autopilot hard stop: if the engineering review reports any BLOCKING or MEDIUM finding, STOP before
Phase 2 per review-gate.md ("Fix the architecture and re-run sk.design, or escalate checkpoint_mode to
'confirm'"). ADVISORY-only findings are logged and the pipeline proceeds.

GATE 1 — Architecture Review (validate only)
Review: 02-design/architecture.md, 02-design/impact-analysis.md, knowledge-base.md (if updated),
the diff of `specs/domain/` (if a bounded context was added), any ADR raised in this run
Check for:
  - Bounded context is correct and scoped to this unit only
  - A new bounded context has its row in `specs/domain/bounded-contexts.md` and its own `specs/domain/{module}.md`
  - impact-analysis.md covers every project in unit-brief.md with a change type
  - No unresolved BLOCKING or MEDIUM findings from the engineering review
  - Every decision marked "ADR required" was raised via sk.adr or is listed for the architect
  - Open questions are acceptable to carry into data model design
On cancel: remaining phases skipped.

### Phase 2 — Data Model
Condition: run if needed per phase need detection, or RESUME with 02-design/database-design.md missing,
           or TARGETED --datamodel, or REFRESH with datamodel in affected phases
Invoke with the Skill tool: `Skill(sk.design_sub_datamodel)`
- Reads from disk: 02-design/architecture.md, `specs/domain/bounded-contexts.md`, the owning
  `specs/domain/{module}.md` files, the existing entity code
- Waits for: 02-design/database-design.md written, and domain invariants/rationale (when any arose)
  written into the owning `specs/domain/{module}.md`

GATE 2 — Data Model Review (confirm, validate)
Review: 02-design/database-design.md, the diff of every `specs/domain/{module}.md` changed in this run
Check for:
  - No entity conflicts with another context's ownership (bounded-contexts.md, domain files, code)
  - Breaking schema changes are intentional and a migration strategy is defined
  - Every query pattern has an access strategy
  - Transaction boundaries are declared for every write path
  - Nothing contradicts the constitution or the routed ADRs
On cancel: contracts skipped.

### Phase 3 — API Contracts
Condition: run if needed per phase need detection, or RESUME with 02-design/contract-changes.md missing,
           or TARGETED --contracts, or REFRESH with contracts in affected phases
Invoke with the Skill tool: `Skill(sk.design_sub_contracts)`
- Reads from disk: 02-design/architecture.md, 02-design/database-design.md, unit-brief.md, and the
  canonical `specs/openapi/{audience}.yaml` / `specs/asyncapi/{module}.yaml` files it edits
- Waits for: the canonical spec files edited on the feature branch, 02-design/contract-changes.md and
  02-design/projects/{BackendProject}.md written, verification result recorded

GATE 3 — API Contract Review (confirm, validate)
Review: the diff (`git diff`) of every canonical `specs/openapi/*.yaml` / `specs/asyncapi/*.yaml` file named
in 02-design/contract-changes.md, the change list itself, and 02-design/projects/{BackendProject}.md.
Check for:
  - Every operation the story needs exists in the canonical spec; no operation was added that no story needs
  - The change list and the diff agree — every changed operation is a row, every row is in the diff
  - Every row carries a compatibility class per `contracts.compat_rules` in `.specify/profile.yaml`
    (default: additive | deprecating | breaking)
  - Every `breaking` row names a versioned replacement or an ADR that accepts the break
  - Consumers are listed for every row
  - Auth/authz is declared per operation in the spec
  - The verification result is recorded (`contracts.verify` output, or "none — provider contract tests by sk.test")
  - A new audience file, if any, was announced by the sub-skill and is intended
  - The test plan has a provider section plus one consumer section per impacted Frontend/Mobile project,
    each listing only the operations that consumer actually calls
On cancel: Phases 4-6 skipped; spec edits and the change list written so far are preserved.

### Phase 4 — Knowledge Base Assessment
Condition: always runs after any phase completes (FRESH, RESUME, REFRESH, TARGETED)

Evaluate whether this design run produced non-derivable content worth capturing:

**Triggers that warrant a KB update (any one is sufficient):**
- A non-obvious architectural decision was made (pattern chosen over alternatives, tradeoff accepted)
- An external constraint surfaced that will not be visible in code (regulatory, external system, SLA)
- A new invariant was identified that spans multiple files or services in this unit
- REFRESH mode recorded a custom design decision in unit knowledge-base.md
- An open question was resolved in a non-obvious way

**Triggers that do NOT warrant a KB update:**
- Standard CRUD unit with no unusual decisions
- All phases were skipped (nothing ran)
- TARGETED run produced no new decisions
- Content is fully derivable from reading the artifacts just written

**Decision:**
- If any trigger is met: invoke `Skill(sk.knowledge-base)` with `--tier unit`
  Log: "KB update triggered — {reason}"
- If no trigger: log "KB update skipped — no non-derivable content identified" and proceed to Phase 5.

**Domain-wide content** — an invariant, rule or rationale that holds for the whole bounded context, not
only this unit — belongs in `specs/domain/{module}.md`. Never write it there silently. List it as
ADVISORY: "Domain content for {module}: {one line} — run sk.knowledge-base --tier domain", and leave the
decision to the architect. Content the datamodel sub-skill already wrote into a domain file in this run
was shown at Gate 2 and needs no second write.

### Phase 5 — Guide Update
Condition: always runs after any phase completes (all modes).

Auto-generate the unit-level routing index. It is the only guide this skill writes: the system-wide map
of contexts is `specs/domain/bounded-contexts.md`, and there is no system or domain guide.
1. Read `unit-brief.md`, `02-design/architecture.md`, `02-design/impact-analysis.md`,
   `02-design/database-design.md` and `02-design/contract-changes.md` to understand unit components
   and impacted projects.
2. Read the actual directory structure under each impacted project's `{CodeRoot}` to identify where
   modules and files live.
3. Generate or overwrite `specs/intents/{intent}/units/{unit}/guide.yaml`. Use
   `{TEMPLATES_DIR}/artifacts/guide-template.yaml` as reference (`TEMPLATES_DIR` per
   `.claude/skills/governance/framework-paths.md`). It must contain the non-obvious cross-cutting
   constraints in the `also-check:` field.
4. Log: "Guide updated — {unit-id}".

### Phase 6 — Frontend UI Design
Condition: run ONLY if the unit has a user-facing surface. This phase is self-contained — it does its own
review, its own KB assessment, and registers its own artifact in the guide. It never alters the behaviour
of Phases 1–5; for a pure backend unit it skips cleanly and the pipeline output is unchanged.

**Frontend signal detection** — any of:
  - `unit-brief.md` → Impacted Projects has a row with Type = Frontend or Type = Mobile
    (the Type recorded for that project in `.specify/memory/projects/index.md`)
  - story `tags` or prose mention: page, screen, route, component, UI, frontend, portal, admin, mobile

If NO frontend signal is found:
  Log: "Phase 6 skipped — no frontend signals detected. Pipeline output unchanged."
  Proceed to the completion report.

If a frontend signal IS found:
  Invoke with the Skill tool: `Skill(sk.design_sub_ui-design)`
  - Reads from disk: 02-design/architecture.md, 02-design/contract-changes.md (operations and consumer
    test-plan sections) and the canonical spec operations it lists, 02-design/database-design.md
    (if present), unit-brief.md, 01-story/
  - Waits for: 02-design/ui-model.md and one 02-design/projects/{Project}.md per impacted
    Frontend/Mobile project written, and frontend engineering review passed

  Autopilot hard stop: BLOCKING or MEDIUM findings in the frontend engineering review STOP the phase
  per review-gate.md; ADVISORY-only findings are logged and the phase proceeds.

  GATE 4 — Frontend UI Review (confirm, validate)
  Review: 02-design/ui-model.md, 02-design/projects/ (one page per impacted Frontend/Mobile project)
  Check for:
    - Every story has a frontend surface (route/component) or is marked backend-only
    - State placement is correct — no server-owned data in the global client store
    - Every consumed field exists in the canonical spec operations — no invented operations
    - Loading, empty, and error states are defined for every async surface
    - Accessibility targets are present for interactive components

  After the gate, update the unit guide entry so the frontend artifacts are indexed:
  - Add `02-design/ui-model.md` and the `02-design/projects/{Project}.md` frontend pages to the unit
    `guide.yaml` artifact list and record any cross-cutting frontend constraint in its `also-check:` field.
  - Log: "Guide updated with ui-model — {unit-id}".

## Completion Report
After all phases complete, display:
```
sk.design complete.
Unit: {unit-id} — {unit name}
Intent: {intent-id}
Mode: {FRESH | RESUME | REFRESH | TARGETED}

Phases run:
  {list only phases that actually ran, with the sub-skill invoked}

Artifacts written:
  {list only artifacts actually written in this run}

Knowledge homes changed on this branch:
  {specs/openapi|asyncapi files, specs/domain files, ADRs — or "none"}

Phases skipped:
  {list skipped phases with reason: not needed | already complete | not targeted}

Knowledge base: {updated | skipped — {reason}}
Domain advisories: {list | none}
Guide: {updated | no changes}

Next step: /sk.plan
```

## Quality Bar
- Mode is detected and logged at the start — never ambiguous
- Every sub-skill is invoked with the Skill tool, never by reading its prompt.md
- REFRESH always records the decision in unit knowledge-base.md before touching any artifact
- Domain-wide implications are flagged as ADVISORY (sk.knowledge-base --tier domain), never silently
  written to `specs/knowledge-base.md` or `specs/domain/`
- Gate schedule is derived from checkpoint_mode (story frontmatter) — never overridden downward without logging
- New bounded context always triggers validate regardless of checkpoint_mode
- Active gates must receive explicit 'approved' before the next phase starts
- Skipped gates are logged inline so the user can see what was bypassed
- 'cancel' at any active gate preserves all artifacts written up to that point
- Each sub-skill invocation is self-contained — no state leaks between phases
- Only the unit `guide.yaml` is written — no system or domain guide
- Completion report lists only what actually ran and what was skipped, with reasons
- KB update is conditional — only invoked when non-derivable content was produced; reason always logged

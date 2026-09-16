# sk.design — Full Design Pipeline (Orchestrator)
Runs the complete unit design pipeline — architecture, data model, and API contracts — in one invocation.
Role: architect (orchestrator) | Level: unit

This skill orchestrates sub-skills in strict sequence. Each sub-skill runs with its own
isolated context — state is passed via the file system (session.yaml + spec artifacts).
Orchestrators do not resolve capability packs; each sub-skill resolves its own (phase = design).

## Design Output Layout
All design artifacts live under `specs/intents/{intent}/units/{unit}/02-design/`
(full tree: `.claude/skills/governance/phase-layout.md`). Per-project page names come from
`unit-brief.md` → Impacted Projects. Unit-tier `knowledge-base.md` and `guide.yaml` stay at the unit root.

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
  02-design/contracts/ are missing
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
   - Mentions endpoints, routes, request/response, versioning → Phase 3 (contracts)
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
4. If the change has domain-wide implications (new entity type, new service boundary,
   cross-unit contract change): flag as ADVISORY after recording
   → "This change may warrant sk.knowledge-base --tier domain. Proceeding with unit-level recording."
5. Run only the affected phases in sequence (Phase 1 → 2 → 3 order enforced even if subset)
6. Gates apply per normal gate schedule for the active checkpoint_mode

## Gate Schedule
Gate behaviour (display, approved/cancel handling, autopilot hard stops) follows
`.claude/skills/governance/review-gate.md`. This skill's schedule:

| checkpoint_mode | Gate 1 (after architecture) | Gate 2 (after data model) | Gate 3 (after UI design) |
|---|---|---|---|
| autopilot | skip | skip | skip |
| confirm | skip | PAUSE | PAUSE |
| validate | PAUSE | PAUSE | PAUSE |

Gate override: if 02-design/architecture.md does not yet exist AND unit introduces a new bounded context,
treat as validate regardless of checkpoint_mode.
Log: "Gate override: new bounded context detected — validate required."

In TARGETED and REFRESH modes: gates apply only to phases that actually run.

## Orchestration

### Phase 1 — Architecture
Condition: run if FRESH, or RESUME with 02-design/architecture.md missing, or TARGETED --architecture,
           or REFRESH with architecture in affected phases
Invoke skill: sk.architecture
- Context injected: session.yaml, domain-model.md, service-registry.md, architecture-decisions.md
  (design-phase capability packs are resolved inside the sub-skill)
- Waits for: 02-design/architecture.md and 02-design/impact-analysis.md written and engineering review passed

Autopilot hard stop: if the engineering review reports any BLOCKING or MEDIUM finding, STOP before
Phase 2 per review-gate.md ("Fix the architecture and re-run sk.design, or escalate checkpoint_mode to
'confirm'"). ADVISORY-only findings are logged and the pipeline proceeds.

GATE 1 — Architecture Review (validate only)
Review: 02-design/architecture.md, 02-design/impact-analysis.md, knowledge-base.md (if updated)
Check for:
  - Bounded context is correct and scoped to this unit only
  - impact-analysis.md covers every project in unit-brief.md with a change type
  - No unresolved BLOCKING or MEDIUM findings from the engineering review
  - Any ADVISORY findings (new cross-service decisions) have an ADR planned
  - Open questions are acceptable to carry into data model design
On cancel: remaining phases skipped.

### Phase 2 — Data Model
Condition: run if needed per phase need detection, or RESUME with 02-design/database-design.md missing,
           or TARGETED --datamodel, or REFRESH with datamodel in affected phases
Invoke skill: sk.datamodel
- Context injected: session.yaml, domain-model.md, data-standards.md
- Reads from disk: 02-design/architecture.md
- Waits for: 02-design/database-design.md written and domain-model.md updated

GATE 2 — Data Model Review (confirm, validate)
Review: 02-design/database-design.md, .specify/memory/domain-model.md (if updated)
Check for:
  - No entity conflicts with other units in domain-model.md
  - Breaking schema changes are intentional and migration strategy is defined
  - Index strategy covers all query patterns
  - Transaction boundaries are declared for every write path
On cancel: contracts skipped.

### Phase 3 — API Contracts
Condition: run if needed per phase need detection, or RESUME with 02-design/contracts/ missing,
           or TARGETED --contracts, or REFRESH with contracts in affected phases
Invoke skill: sk.contracts
- Context injected: session.yaml, service-registry.md, api-standards.md, tech-stack.md
- Reads from disk: 02-design/architecture.md, 02-design/database-design.md, unit-brief.md
- Waits for: 02-design/contracts/api-spec.json, 02-design/contracts/test-plan.md,
  02-design/api-contract.md, 02-design/projects/{BackendProject}.md, provider tests written,
  service-registry.md updated

### Phase 4 — Knowledge Base Assessment
Condition: always runs after any phase completes (FRESH, RESUME, REFRESH, TARGETED)

Evaluate whether this design run produced non-derivable content worth capturing:

**Triggers that warrant a KB update (any one is sufficient):**
- A non-obvious architectural decision was made (pattern chosen over alternatives, tradeoff accepted)
- An external constraint surfaced that will not be visible in code (regulatory, legacy system, SLA)
- A new invariant was identified that spans multiple files or services in this unit
- REFRESH mode recorded a custom design decision in unit knowledge-base.md
- An open question was resolved in a non-obvious way

**Triggers that do NOT warrant a KB update:**
- Standard CRUD unit with no unusual decisions
- All phases were skipped (nothing ran)
- TARGETED run produced no new decisions
- Content is fully derivable from reading the artifacts just written

**Decision:**
- If any trigger is met: invoke sk.knowledge-base --tier unit
  Log: "KB update triggered — {reason}"
- If no trigger: log "KB update skipped — no non-derivable content identified" and proceed to Phase 5.

### Phase 5 — Guide Update
Condition: always runs after any phase completes (all modes).

Auto-generate a unit-level routing index.
1. Read `unit-brief.md`, `02-design/architecture.md`, `02-design/impact-analysis.md`,
   `02-design/database-design.md`, `02-design/api-contract.md`, and `02-design/contracts/`
   to understand unit components and impacted projects.
2. Read the actual directory structure under each impacted project's `{CodeRoot}` to identify where
   modules and files live.
3. Generate or overwrite `specs/intents/{intent}/units/{unit}/guide.yaml`. Use `templates/artifacts/guide-template.yaml` as reference. It must contain the non-obvious cross-cutting constraints in the `also-check:` field.
4. If missing, create/update the domain-level guide entry for this unit in `specs/domains/{domain}/guide.yaml`.
5. If missing, create/update the system-level guide entry for this domain in `specs/guide.yaml`.
6. Log: "Guide updated — {unit-id}".

### Phase 6 — Frontend UI Design
Condition: run ONLY if the unit has a user-facing surface. This phase is self-contained — it does its own
review, its own KB assessment, and registers its own artifact in the guide. It never alters the behaviour
of Phases 1–5; for a pure backend unit it skips cleanly and the pipeline output is unchanged.

**Frontend signal detection** — any of:
  - `unit-brief.md` → Impacted Projects has a row with Type = Frontend or Type = Mobile
  - a surface or project listed in `.specify/memory/skill-routing.md` → `## Surfaces` is named in the story
  - story `tags` or prose mention: page, screen, route, component, UI, frontend, portal, admin, mobile

If NO frontend signal is found:
  Log: "Phase 6 skipped — no frontend signals detected. Pipeline output unchanged."
  Proceed to the completion report.

If a frontend signal IS found:
  Invoke skill: sk.ui-design
  - Context injected: coding-standards.md, domain-model.md
  - Reads from disk: 02-design/architecture.md, 02-design/contracts/api-spec.json,
    02-design/contracts/test-plan.md, 02-design/api-contract.md,
    02-design/database-design.md (if present), unit-brief.md, 01-story/
  - Waits for: 02-design/ui-model.md and one 02-design/projects/{Project}.md per impacted
    Frontend/Mobile project written, and frontend engineering review passed

  Autopilot hard stop: BLOCKING or MEDIUM findings in the frontend engineering review STOP the phase
  per review-gate.md; ADVISORY-only findings are logged and the phase proceeds.

  GATE 3 — Frontend UI Review (confirm, validate)
  Review: 02-design/ui-model.md, 02-design/projects/ (one page per impacted Frontend/Mobile project)
  Check for:
    - Every story has a frontend surface (route/component) or is marked backend-only
    - State placement is correct — no server-owned data in the global client store
    - Every consumed field exists in the API contract — no invented endpoints
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

Phases skipped:
  {list skipped phases with reason: not needed | already complete | not targeted}

Knowledge base: {updated | skipped — {reason}}
Guide: {updated | no changes}

Next step: /sk.plan
```

## Quality Bar
- Mode is detected and logged at the start — never ambiguous
- REFRESH always records the decision in unit knowledge-base.md before touching any artifact
- Domain-wide implications in REFRESH are flagged as ADVISORY, never silently written to tier 1/2
- Gate schedule is derived from checkpoint_mode (story frontmatter) — never overridden downward without logging
- New bounded context always triggers validate regardless of checkpoint_mode
- Active gates must receive explicit 'approved' before the next phase starts
- Skipped gates are logged inline so the user can see what was bypassed
- 'cancel' at any active gate preserves all artifacts written up to that point
- Each sub-skill invocation is self-contained — no state leaks between phases
- Completion report lists only what actually ran and what was skipped, with reasons
- KB update is conditional — only invoked when non-derivable content was produced; reason always logged

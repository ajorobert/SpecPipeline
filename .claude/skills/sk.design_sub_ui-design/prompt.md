# sk.design_sub_ui-design
Defines the frontend UI model for a unit.
Role: frontend | Level: unit
ONE document per unit — covers the frontend surface for all stories in the unit.

Internal sub-skill — invoked by sk.design Phase 6. Do not invoke directly.

Resolve `TEMPLATES_DIR` per `.claude/skills/governance/framework-paths.md` before reading any template.

## Design Output Layout
This sub-skill writes `02-design/ui-model.md` (the canonical frontend model) and one
per-surface design page under `02-design/projects/` for every impacted Frontend/Mobile
project named in `unit-brief.md` (tree: `.claude/skills/governance/phase-layout.md`).

## Boundary with sk.design_sub_contracts (read first)
The architect's `sk.design_sub_contracts` already edited the canonical `specs/openapi/{audience}.yaml` /
`specs/asyncapi/{module}.yaml` and listed in `02-design/contract-changes.md` WHICH operations changed and
which each frontend consumes (the Operations table and the consumer test-plan sections). This skill does
NOT redefine operations, URLs, or response field ownership. It defines HOW the frontend types, fetches,
and renders those responses. If a needed operation is missing from the canonical spec, do not invent it —
record it under Open Questions and flag it for the architect (sk.design --contracts).

## Step 0: Surfaces and Capability Packs
1. Resolve the target surfaces: every row of `unit-brief.md` → Impacted Projects with Type = Frontend or
   Type = Mobile (the Type recorded in `.specify/memory/projects/index.md`). For each, read its framework
   and **Platform** from the project's `.specify/memory/projects/{Project}/tech-stack.md`
   (`.claude/skills/governance/project-resolution.md`). Log: `UI surfaces: {Project} ({Framework}, {Platform})`.
   A surface whose tech-stack.md is missing or has Platform `none`: log it and continue from the
   projects/index.md row alone.
2. Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `design`,
   in-scope projects = the surfaces above. The loaded frontend packs, together with the project's
   `.claude/rules/{stack}/` folders (`rules.stacks` in `.specify/profile.yaml`), are the authority for
   framework-specific rules (render boundaries, data fetching, routing, styling, forms).

## Input Artifacts
specs/intents/{intent}/units/{unit}/unit-brief.md                         (Impacted Projects table — Frontend/Mobile rows)
specs/intents/{intent}/units/{unit}/01-story/                             (story.md, requirement.md, acceptance-criteria.md)
specs/intents/{intent}/units/{unit}/02-design/architecture.md            (route/page intent, data flow, security)
specs/intents/{intent}/units/{unit}/02-design/contract-changes.md        (operations this UI consumes + consumer test-plan section per surface — if it exists)
The canonical operations it lists, in specs/openapi/{audience}.yaml / specs/asyncapi/{module}.yaml (read only those operations)
specs/intents/{intent}/units/{unit}/02-design/database-design.md         (entity shapes, optional — read only if present)
specs/domain/bounded-contexts.md and the `specs/domain/{module}.md` of the contexts the unit touches (domain language)
.specify/memory/projects/index.md and each surface's tech-stack.md       (Type, Platform, framework)
The surface's `.claude/rules/{stack}/` folder                            (design system and UI conventions, if present)

## Steps
1. [REFINE MODE] if ui-model.md exists, [CREATE MODE] if not.
   - REFINE: read existing fully, preserve valid sections, update only changed surfaces. Append a revision note.
2. List every story in the unit. Confirm the UI model covers each one (each story maps to at least one
   route or component path). A story with no frontend surface is recorded as "no UI — backend only".
3. **Route & Page Tree** — define the navigation structure for each surface in its framework's terms
   (route segments, SPA routes, or native screens), including layouts/navigators and the loading, error and
   not-found boundaries the framework supports.
4. **Component Architecture** — decompose each page into components. For every component declare:
   - render boundary, using the categories the surface's framework and packs define
     (for example server | client, or container | presentational)
   - single responsibility (one visual concern or one interaction)
   - shared vs unit-local, per the project's rules and loaded packs
5. **State Architecture** — classify every piece of state into exactly one home and justify it:
   - server cache — server-owned data, held by the surface's data-fetching layer
   - global client store — cross-component UI state only
   - local component state — single-component concern
   - URL / navigation state — shareable, bookmarkable view state
   Rule: server-owned data never lives in the global client store.
6. **Data Consumption Contracts** — define the typed interfaces (in the surface's language) that map the
   consumed operations' responses (from the canonical spec, as listed in contract-changes.md) into frontend
   types. Reference the operation; never restate its ownership. Declare the fetch/rendering strategy per
   route using the rendering modes the surface's framework supports, with rationale.
7. **Design System Usage** — list the component-library primitives used, any custom components required
   (and why), and any feature-specific token decisions, per the project's design system as its rules and
   packs describe it. Reuse existing tokens; do not introduce a new visual style.
8. **Performance Strategy** — rendering mode per route, bundle/code split points for heavy components,
   image and asset strategy, and performance targets appropriate to the surface's Platform.
9. **Accessibility Requirements** — the accessibility target the project sets in its constitution, ADRs or
   rules (when it sets none, record the gap as an open question for the gate — never ask), keyboard/switch navigation paths, focus
   management, and accessibility-API decisions for any non-native interactive component.
10. **Error & Loading States** — for every async surface: loading UI, empty state, and error fallback.
11. Write the UI model document to `02-design/ui-model.md` using `{TEMPLATES_DIR}/artifacts/ui-model-template.md`
    as the structure. This is the canonical, multi-surface frontend model for the unit.
12. Write one per-surface design page per impacted Frontend/Mobile project:
    - For each Impacted Projects row with Type = Frontend or Type = Mobile, write
      `02-design/projects/{Project}.md` using `{TEMPLATES_DIR}/artifacts/project-design-template.md`.
    - File name = the exact project name from unit-brief.md (`{Project}.md`) — dynamic, not fixed.
    - The page is a VIEW that extracts this project's slice of ui-model.md (its routes/screens, components,
      state homes, consumed operations from contract-changes.md, fetch strategy, a11y, loading/empty/error
      states). It references ui-model.md and the canonical spec operations; it does not redefine them.
    - Backend project pages are NOT written here — sk.design_sub_contracts owns those. Do not overwrite them.

## Frontend Engineering Review (mandatory — runs after steps 11–12)
Validate the written UI model and per-surface project pages against:
- the design-phase packs loaded in Step 0 — including any design principles pack (UI consumes contracts, does not invent them)
- the surface's `.claude/rules/{stack}/` folder — no design that forces code to break a rule
- `02-design/architecture.md` — every route/page the architecture implies has a home; no surface is orphaned
- the canonical spec operations listed in `02-design/contract-changes.md` and its consumer sections —
  every consumed field exists in the spec; no invented operations
- `unit-brief.md` — one `02-design/projects/{Project}.md` exists for every impacted Frontend/Mobile project

Flag findings as:
- BLOCKING: consumes an operation or field absent from the canonical spec; server-owned data placed in global store;
  a story's UI surface is missing entirely; a render-boundary choice that breaks a rule of the surface's
  framework as stated in a loaded pack or the project's rules
  → fix the UI model before proceeding.
- MEDIUM: state placed in the wrong home without justification; missing loading/error/empty state for an
  async surface; missing accessibility target on an interactive component; heavy component not split
  → must be resolved before proceeding; counts as a blocker in autopilot mode.
- ADVISORY: a new shared component or cross-surface pattern is introduced
  → suggest recording it in the unit knowledge base before implementation begins.

If all checks pass: report "Frontend engineering review passed — no findings."
If only ADVISORY findings: report "Frontend engineering review passed with advisories." and list them.
If any MEDIUM or BLOCKING findings exist: report "Frontend engineering review FAILED." and list all findings.

## Output Artifacts
specs/intents/{intent}/units/{unit}/02-design/ui-model.md
specs/intents/{intent}/units/{unit}/02-design/projects/{FrontendOrMobileProject}.md (one per impacted Frontend/Mobile project)
specs/intents/{intent}/units/{unit}/knowledge-base.md
  (unit-tier KB stays at unit root — frontend section updated only if a non-derivable UI decision was made — see step below)

## Steps (continued)
13. If the UI model introduced a non-derivable decision (a shared component contract other units will depend on,
    a deliberate state-architecture tradeoff, an accessibility constraint driven by an external requirement):
    update the unit knowledge-base.md with the rationale (why, not what). Otherwise log
    "KB update skipped — no non-derivable UI content."

## Quality Bar
- Surfaces resolved from unit-brief.md, projects/index.md Type and each surface's tech-stack.md Platform, and logged
- ui-model.md written to `02-design/ui-model.md`
- One `02-design/projects/{Project}.md` written for every impacted Frontend/Mobile project, named from unit-brief.md
- Backend project pages under `02-design/projects/` are left untouched (owned by sk.design_sub_contracts)
- Every unit story is mapped to a route/component path, or explicitly marked "no UI — backend only"
- Every component declares its render boundary and single responsibility
- Every piece of state has exactly one declared home with a justification
- Server-owned data is never placed in the global client store
- Every consumed field traces to an operation in the canonical spec — no invented operations or fields
- Fetch/rendering strategy declared per route with rationale
- Every async surface has loading, empty, and error states defined
- Accessibility target declared for every interactive component
- No new visual style introduced — existing design tokens reused
- Open questions listed, not hidden; missing contract operations flagged to the architect
- Revision note appended if REFINE MODE

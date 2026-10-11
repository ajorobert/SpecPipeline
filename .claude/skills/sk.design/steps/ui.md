# Step 4 — UI model
Outputs: `02-design/ui-model.md`; `02-design/projects/{Project}.md` for each Frontend/Mobile project.

This step defines how each surface types, fetches and renders the operations contract-changes.md lists.
It never defines or changes an operation: one that is missing goes to Open Questions and back to
`--contracts`.

Surfaces: every Impacted Projects row of Type Frontend or Mobile, with the framework and Platform from its
tech-stack.md. Framework-specific judgement (render boundaries, data fetching, routing, styling, forms)
comes from the loaded packs and the project rules.

## ui-model.md
From `{templates_dir}/artifacts/ui-model-template.md`, for every surface:
1. **Coverage** — every story maps to a route, screen or component, or is marked "no UI — backend only".
2. **Routes / screens** — the navigation tree in the framework's terms, with layouts and the loading,
   error and not-found boundaries it supports.
3. **Components** — each with a render boundary (in the framework's categories), one responsibility, and
   shared vs unit-local.
4. **State** — each piece in exactly one home, justified: server cache, global client store (UI state
   only — never server-owned data), local component state, or URL/navigation state.
5. **Data consumption** — typed interfaces mapping each consumed operation's response, referencing the
   operation; the fetch/rendering strategy per route, with the reason.
6. **Design system** — primitives reused, custom components needed and why; existing tokens only.
7. **Performance** — rendering mode per route, split points, assets, targets fit for the Platform.
8. **Accessibility** — the target the project's ADRs or rules set (none set: ask, and record the
   answer), keyboard/switch paths, focus management, semantics of custom interactive components.
9. **Loading, empty and error states** for every async surface.

## Project pages
For each Frontend/Mobile row, `02-design/projects/{Project}.md` from
`{templates_dir}/artifacts/project-design-template.md`: that surface's slice of ui-model.md, referencing it
and the spec operations. Backend pages are the contracts step's; leave them untouched.

## Engineering review
- **BLOCKING** — a consumed operation or field absent from the spec; server-owned data in the global
  store; a story with no surface; a render boundary that breaks a rule of the framework's pack or rules.
- **MEDIUM** — state in the wrong home without justification; an async surface missing a state; an
  interactive component without an accessibility target; a heavy component not split.
- **ADVISORY** — a new shared component or cross-surface pattern (record it in the unit knowledge base).

## Gate 4 — UI
Show: ui-model.md and the Frontend/Mobile project pages. Check for: every story has a surface or is
backend-only; correct state placement; every consumed field exists in the spec; loading, empty and error
states for every async surface; accessibility targets on interactive components.

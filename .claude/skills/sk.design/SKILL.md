---
name: sk.design
description: "Design a unit: architecture and impact, data model, API contract changes (edited in place in specs/openapi|asyncapi) and, for user-facing projects, the UI model — with review gates and ADRs raised in-session."
role: architect
preconditions:
  - "file_contains: {unit_dir}/unit-brief.md :: ^[|][^|]+[|][[:space:]]*(Backend|Frontend|Mobile)[[:space:]]*[|]"
---

# sk.design
Designs one unit, in one session with the architect.
Outputs under `02-design/` (`.claude/skills/governance/phase-layout.md`), the canonical contract files
edited in place, `specs/domain/` for a new or changed bounded context, and ADRs through `/sk.adr`.

## Invocation
- `sk.design` — run the steps whose outputs are missing.
- `sk.design --architecture | --datamodel | --contracts | --ui` — run that one step.
- `sk.design --refresh "<change>"` — rerun the steps the change affects: endpoints, operations, channels,
  payloads → contracts; tables, entities, schema → data model; services, boundaries, dependencies →
  architecture (and every later step). Ambiguous → all. Record `## Design change — {date}` (change,
  steps rerun, why) in the unit's `knowledge-base.md` first.

## Pre-flight
Run `.claude/skills/governance/preflight.md` with command `design`.

## Steps and gates
Each step's file says how; read it when you reach it. Gates follow `.claude/skills/governance/review-gate.md`.

| # | Step | Runs when | Gate (confirm) | Gate (validate) |
|---|---|---|---|---|
| 1 | `steps/architecture.md` | always, first | skip | pause |
| 2 | `steps/datamodel.md` | the story persists, caches, searches or uploads data | pause | pause |
| 3 | `steps/contracts.md` | the unit exposes or consumes an API, event or command | pause | pause |
| 4 | `steps/ui.md` | a Frontend or Mobile project is impacted | pause | pause |

- Autopilot pauses at no gate, but a BLOCKING or MEDIUM engineering-review finding still stops the run.
- A new bounded context makes every gate pause, whatever the mode; say so when it happens.
- A skipped step is reported with its reason.
- **ADRs.** A decision with cross-module reach — it binds other contexts, other units, or future work
  that must not silently undo it — is raised with `Skill(sk.adr)` at the gate of the step that made it,
  once the human agrees with it; otherwise it is listed as `ADR required: {decision}` for the architect.
- **Unit knowledge.** When a step settles something non-derivable — a trade-off chosen over an
  alternative, an external constraint, an invariant spanning several files — add it to the unit's
  `knowledge-base.md` (why, not what). Domain-wide content goes into `specs/domain/{module}.md` only
  through the data-model step or promotion at ship; otherwise list it as a domain advisory.

## Completion report
```
sk.design complete — {unit-id}
Steps: {step: ran | skipped (reason) | kept (already present)}
Written: {artifacts}
Knowledge homes changed: {contract files, specs/domain files, ADR-NNNN | none}
ADR required, not raised: {list | none}
Domain advisories: {list | none}
Next: /sk.plan — in a fresh session
```

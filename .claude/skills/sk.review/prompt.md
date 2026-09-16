# sk.review
Spec-aware code review: validates against bounded context, contracts, and ADRs.
Role: backend, frontend | Level: project within the active unit
gstack: optional enhancement — if installed, invoke after Claude's own review for additional signal

## Invocation Forms
- `sk.review --projects {key}` — review one impacted project (resolved per `.claude/skills/governance/project-resolution.md`)
- `sk.review` — review the impacted project matching session.yaml `role` (backend → Backend, frontend → the
  Frontend/Mobile project); if more than one matches, STOP and list candidates

## Pre-flight
1. Run the story pre-flight in `.claude/skills/governance/preflight.md` (active story, UNIT_DIR, Impacted Projects).
2. Resolve the target `{Project}` / `{CodeRoot}` / `{ProjectType}`. Log the resolution.

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `review`,
in-scope project = `{Project}`, signals = story tags + `03-plan/{Project}/plan.md`.

## Context loading (cacheable — load first)
- UNIT_DIR/02-design/architecture.md — bounded context, module boundaries, owned entities (Tier B)
- UNIT_DIR/02-design/contracts/api-spec.json — endpoint signatures (Tier B)
- UNIT_DIR/02-design/projects/{Project}.md — the project's design slice (Tier B, if present)
- .specify/memory/architecture-decisions.md — ADR constraints (Tier A)
- .specify/memory/standards/coding-standards.md (or the project's own) — implementation rules (Tier A)
- .specify/memory/standards/observability-standards.md — logging/metrics/health requirements (Tier A)

## Story context (tail — load LAST)
Emit at end of user-input block, after all cacheable context:
```
<story id="{story-id}" project="{Project}">
  <story-md>…UNIT_DIR/01-story/story.md + acceptance-criteria.md…</story-md>
  <plan-md>…UNIT_DIR/03-plan/{Project}/plan.md (if present)…</plan-md>
  <implementation>…UNIT_DIR/04-implementation/{Project}/implementation.md (changed files)…</implementation>
  <prior-review>…UNIT_DIR/04-implementation/{Project}/review-{story-id}.md (if present)…</prior-review>
</story>
```

## Context surface
Before invoking gstack /review, surface to agent:

"Reviewing story: {story-id} — {story title} — project {Project} ({CodeRoot})
Bounded context: {unit name}. This unit owns: {entities/services from architecture.md}.
Must NOT cross into: {other units/services mentioned in architecture.md dependencies}
Contract: endpoints must match api-spec.json exactly — no undocumented changes.
ADR constraints: {applicable ADR summaries}
Loaded review packs: {from Step 0} — apply their review checks.

Pre-generation check: was existing code in the target area read before writing?
Flag if new abstractions were introduced that duplicate existing ones.

Module boundary checks (blocking):
- Method signatures changed from declared interface
- API response shape deviates from api-spec.json
- Untyped DTOs (any, raw maps, untyped dicts)
- Public method names don't describe intent (verb-noun)
- Direct access to another module's internal classes

Domain logic checks (findings):
- Business logic in a controller / endpoint
- State change / DB write / external call outside injected interface
- Direct DB query outside a repository
- Command modifies more than one aggregate without going through domain events
- Function > 30 lines or > 1 logical operation
- Function > 3 parameters without a parameter object

Error handling: does code match the project's declared error handling pattern?

Observability (for stories adding new service endpoints):
- Structured JSON logging with trace_id and span_id present
- RED metrics instrumented (rate, errors, duration per endpoint)
- GET /health endpoint present and returning correct shape"

## Invoke
Claude performs the review natively using the context surface above.
If gstack is installed (`command -v gstack`): also invoke `gstack /review` for additional signal and merge findings.

## Output Artifact
If any findings exist, write a review report to:
  UNIT_DIR/04-implementation/{Project}/review-{story-id}.md
(sk.implement → sk.codegen reads this path to enter REFINE mode.)

Format:
```
# Review: {story-id} — {Project}
Date: {YYYY-MM-DD}
Status: REJECTED | APPROVED

## Blocking Findings
- {finding}: {description} → {required action}

## Non-Blocking Findings
- {finding}: {description}
```

On REJECTED: write/overwrite the file with current findings.
On APPROVED: keep the review report at its path.
1. If any blocking findings were raised during this review cycle (i.e. the story was previously REJECTED):
   Append a `## Implementation Pitfalls` entry to the unit knowledge base:
     UNIT_DIR/knowledge-base.md
   Format:
   ```
   ## Implementation Pitfalls
   <!-- Lessons from review cycles — sk.implement reads this to avoid repeating issues -->
   - [{story-id}] {short description of what was wrong} → {what the correct pattern is}
   ```
   If the section already exists, append to it rather than replacing it.
2. Keep the review report at its path — do NOT archive it on approval.
   Non-blocking findings remain available for the developer to act on via sk.implement.

## Post-execution
Flag any finding that:
- Violates bounded context boundaries (accessing another unit's internals directly)
- Deviates from api-spec.json endpoint signatures
- Contradicts an ADR decision
- Violates a module boundary rule (blocking)

Bounded context, ADR, and module boundary violations must be resolved before story can proceed to sk.verify.
Domain logic findings and observability gaps reported with severity from gstack /review output.

## Quality Bar
- No bounded context violations
- No endpoint signature deviations from api-spec.json
- No ADR constraint violations
- No module boundary violations
- Review checks of loaded review packs applied
- All other findings reported with gstack /review output

## Completion Signal
Last line of output must be exactly one of:
`SK_RESULT: PASS` — Status is APPROVED, no blocking findings
`SK_RESULT: FAIL` — Status is REJECTED, blocking findings present

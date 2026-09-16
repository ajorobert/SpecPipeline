# sk.contracts
Defines API contracts and generates provider tests for a unit.
Role: architect | Level: unit

Internal sub-skill — invoked by sk.design. Do not invoke directly.

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `design`.

## Design Output Layout
This sub-skill writes the machine contract artifacts to `02-design/contracts/`
(`api-spec.json` stays the canonical OpenAPI source), the human-readable
`02-design/api-contract.md`, and one backend design page per impacted Backend project
under `02-design/projects/` (tree: `.claude/skills/governance/phase-layout.md`).

## Input Artifacts
specs/intents/{intent}/units/{unit}/unit-brief.md (Impacted Projects table)
specs/intents/{intent}/units/{unit}/02-design/architecture.md
specs/intents/{intent}/units/{unit}/02-design/database-design.md
.specify/memory/service-registry.md
.specify/memory/standards/api-standards.md
.specify/memory/skill-routing.md (`## Surfaces` — framework per consumer surface, if present)
Each Backend project's tech stack (test framework + Test Layout), resolved per `.claude/skills/governance/project-resolution.md`
Design-phase packs loaded in Step 0 (if any)

## Steps
1. [REFINE MODE] if contracts/ exists, [CREATE MODE] if not
2. Check service-registry.md — no breaking changes without confirmation
3. Design endpoints following api-standards.md
4. Write OpenAPI spec
5. Write test plan with the following structure:
   ```
   ## Provider Tests
   {endpoint-by-endpoint: happy path, validation error, auth rejection, not found, boundary values}

   ## Consumer Tests

   ### {Project} ({Framework from skill-routing.md ## Surfaces, if registered})
   {endpoints this consumer calls, response fields it depends on,
    pagination expectations, error handling expectations,
    platform-specific scenarios: offline/retry and payload size for native surfaces,
    bulk operations and role-based access for admin surfaces}
   ```
   Write one `### {Project}` heading per row of `unit-brief.md` → Impacted Projects with
   Type = Frontend or Type = Mobile, in table order, using the exact project name.
   For each consumer: only list endpoints that consumer actually calls.
   If the unit has no Frontend/Mobile project, write "None — no consumer projects in this unit".
6. Generate provider contract tests in each Backend project's test framework, at the location its
   tech stack's Test Layout declares for contract tests
7. If REFINE: never remove existing endpoints
   breaking change → add versioned endpoint, flag to user
8. Write the human-readable `02-design/api-contract.md` from `templates/artifacts/api-contract-template.md`.
   It is a companion to `contracts/api-spec.json` (the canonical OpenAPI source) — keep the two in sync;
   never document an endpoint here that is absent from api-spec.json.
9. Write one backend design page per impacted Backend project:
   - Read `unit-brief.md` → Impacted Projects; for each row with Type = Backend, write
     `02-design/projects/{Project}.md` using `templates/artifacts/project-design-template.md`.
   - File name = the exact project name from unit-brief.md (`{Project}.md`) — dynamic, not fixed.
   - The page is a VIEW that synthesises the project-relevant slice of architecture.md,
     database-design.md, and api-contract.md (endpoints owned, handlers, entities, security,
     consistency/outbox per write path). It references the canonical docs; it does not redefine them.
   - Frontend/Mobile project pages are NOT written here — sk.ui-design owns those.

## Output Artifacts
specs/intents/{intent}/units/{unit}/02-design/contracts/api-spec.json
specs/intents/{intent}/units/{unit}/02-design/contracts/test-plan.md
specs/intents/{intent}/units/{unit}/02-design/contracts/README.md
specs/intents/{intent}/units/{unit}/02-design/api-contract.md
specs/intents/{intent}/units/{unit}/02-design/projects/{BackendProject}.md (one per impacted Backend project)
Provider contract tests under each Backend project's {CodeRoot}, per its Test Layout
.specify/memory/service-registry.md (updated)

## Quality Bar
- Machine artifacts written under `02-design/contracts/`; `api-contract.md` written at `02-design/` root
- api-contract.md documents only endpoints present in contracts/api-spec.json (the two stay in sync)
- One `02-design/projects/{Project}.md` written for every impacted Backend project, named from unit-brief.md
- All endpoints follow api-standards.md URL and response format
- Test plan has a provider section and one consumer section per impacted Frontend/Mobile project
- Per-consumer sections list only the endpoints that consumer actually calls
- Provider tests cover happy path + error cases + auth rejection
- No undocumented breaking changes
- Idempotency-Key declared on all mutation endpoints (POST/PUT/PATCH/DELETE)
- Dedup Strategy declared for every consumed event with Idempotent Handler = yes
- Outbox column filled for every published event where handler also writes state
- commandId field present in command schema for any command dispatched async

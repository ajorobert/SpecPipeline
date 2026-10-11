# sk.design_sub_contracts
Edits the canonical API contracts for a unit and records what changed.
Role: architect | Level: unit

Internal sub-skill — invoked by sk.design. Do not invoke directly.

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `design`.

Resolve `TEMPLATES_DIR` per `.claude/skills/governance/framework-paths.md` before reading any template.

## Design Output Layout
The contracts have one home each (`.claude/skills/governance/profile.md`):
- HTTP: `specs/openapi/{audience}.yaml`
- Async: `specs/asyncapi/{module}.yaml`

This sub-skill edits those files **in place on the feature branch**. It never copies a contract into the
unit. In the unit it writes only `02-design/contract-changes.md` (the change list, compatibility classes,
verification result and provider/consumer test plan) and one backend design page per impacted Backend
project under `02-design/projects/` (tree: `.claude/skills/governance/phase-layout.md`).

## Input Artifacts
specs/intents/{intent}/units/{unit}/unit-brief.md (Impacted Projects table)
specs/intents/{intent}/units/{unit}/02-design/architecture.md
specs/intents/{intent}/units/{unit}/02-design/database-design.md
The canonical files the change touches: the audience files already present in `specs/openapi/`, and
`specs/asyncapi/{module}.yaml` for the modules involved — read only the operations in scope
.specify/profile.yaml → `contracts.verify`, `contracts.compat_rules`
.specify/memory/projects/index.md (Type and Role — who consumes which audience)
specs/adr/adr-index.md, then the ADRs it routes for this work (audience mapping, compatibility rules, API conventions)
.specify/memory/constitution.md
The project's `.claude/rules/{stack}/` folders for the backend (and any API stack mapped in `rules.stacks`)
Design-phase packs loaded in Step 0 (if any)

## Steps
1. [REFINE MODE] if `02-design/contract-changes.md` exists, [CREATE MODE] if not.
   REFINE: read it and the current branch diff of the files it lists; keep valid rows.
2. Choose the target file(s). HTTP operations go into the existing `specs/openapi/{audience}.yaml` whose
   audience matches the consumers (projects/index.md Role and the routed ADRs). Create a new audience
   file only when `architecture.md` calls for a new audience, and state it at the gate:
   "New audience file created: specs/openapi/{audience}.yaml — {reason}". Async channels go into
   `specs/asyncapi/{module}.yaml` for the owning module.
3. Design the operations the story needs. Follow the conventions of the file being edited and the
   constitution, routed ADRs and `.claude/rules/` — the framework imposes no API conventions of its own.
   Declare auth/authz on every operation in the spec's own mechanism.
4. Edit the canonical file(s) in place. Add or change only what the story needs.
   If REFINE or the operation already exists: never remove an operation silently — a removal or an
   incompatible change is a `breaking` row (step 5).
5. Classify every added, changed or removed operation with a compatibility class. The classes come from
   the file named by `contracts.compat_rules` in `.specify/profile.yaml` (often an ADR); when it is unset,
   use `additive | deprecating | breaking`. A `breaking` row must name its versioned replacement or the
   ADR that accepts the break — if neither exists, flag it to the user and raise it with `Skill(sk.adr)`
   or list it for the architect. Never proceed with an unaccepted break.
6. List the consumers of each row: the impacted Frontend/Mobile projects from `unit-brief.md`, plus any
   other project that consumes the audience or module (projects/index.md Role, routed ADRs).
7. Verification. If `contracts.verify` is set in `.specify/profile.yaml`, run it and record the command,
   the result (PASS | FAIL) and the date. A FAIL is reported to the user with its output; fix the spec
   edit or record why the failure is expected at this stage (for example, the code is not yet written).
   If it is unset, record: "none — provider contract tests by sk.test". This skill writes no tests.
8. Write `02-design/contract-changes.md` from `{TEMPLATES_DIR}/artifacts/contract-changes-template.md`:
   - Canonical files touched
   - Operations table: File · Operation · Change (added | changed | removed) · Compatibility · Consumers
   - Verification (command and result from step 7)
   - Test plan:
     - Provider ({BackendProject}): per operation — happy path, error cases, auth cases; edge cases,
       integration scenarios and test data
     - One `### Consumer ({Project})` section per row of `unit-brief.md` → Impacted Projects with
       Type = Frontend or Type = Mobile, in table order, using the exact project name. For each consumer,
       list only the operations it actually calls, the fields it uses and the error states it handles,
       plus platform scenarios from the project's tech-stack.md Platform (for example offline/retry and
       payload size for native surfaces). If the unit has no Frontend/Mobile project, write
       "None — no consumer projects in this unit".
9. Write one backend design page per impacted Backend project:
   - Read `unit-brief.md` → Impacted Projects; for each row with Type = Backend, write
     `02-design/projects/{Project}.md` using `{TEMPLATES_DIR}/artifacts/project-design-template.md`.
   - File name = the exact project name from unit-brief.md (`{Project}.md`) — dynamic, not fixed.
   - The page is a VIEW that synthesises the project-relevant slice of architecture.md,
     database-design.md and contract-changes.md (operations owned, handlers, entities, security,
     consistency per write path). It references the canonical spec operations; it does not restate them.
   - Frontend/Mobile project pages are NOT written here — sk.design_sub_ui-design owns those.

## Output Artifacts
specs/openapi/{audience}.yaml and/or specs/asyncapi/{module}.yaml (edited in place on the feature branch)
specs/intents/{intent}/units/{unit}/02-design/contract-changes.md
specs/intents/{intent}/units/{unit}/02-design/projects/{BackendProject}.md (one per impacted Backend project)

## Quality Bar
- Canonical spec files edited in place on the branch; no contract copied into the unit
- A new audience file only when the architecture calls for one, and announced at the gate
- `02-design/contract-changes.md` lists every added, changed or removed operation, and nothing else
- Every row has a compatibility class per `contracts.compat_rules` (default additive | deprecating | breaking)
- Every `breaking` row names a versioned replacement or an ADR accepting the break
- Consumers listed for every row
- Auth/authz declared per operation in the spec
- Verification recorded: `contracts.verify` result, or "none — provider contract tests by sk.test"
- Test plan has a provider section and one consumer section per impacted Frontend/Mobile project
- Per-consumer sections list only the operations that consumer actually calls
- One `02-design/projects/{Project}.md` written for every impacted Backend project, named from unit-brief.md
- No conflict with the constitution, the routed ADRs or the project's `.claude/rules/`; conflicts flagged

# sk.implement_sub_scaffolding
Structural scaffolding step for one project's implementation.
Role: backend | frontend | mobile | Level: project

Internal sub-skill — invoked by sk.implement_sub_implementproject (one project of a unit). Do not invoke directly.

## Project Context (passed by sk.implement_sub_implementproject)
The caller passes the target `{Project}`, `{CodeRoot}`, `{ProjectType}`, and the effective `--role`,
plus the project slice: `03-plan/{Project}/plan.md`, `03-plan/{Project}/tasks.md`, and the relevant
`02-design/` artifacts. ALL files are created inside `{CodeRoot}`, exactly as enumerated
in `03-plan/{Project}/plan.md` → Files Affected. Never write outside `{CodeRoot}`.

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `implement`,
in-scope project = `{Project}` (`{ProjectType}`), signals = story tags + `03-plan/{Project}/plan.md`.
If no project was passed, fall back to session.yaml `role`.

## Context Loading — cacheable (load first, in order)
Knowledge homes are loaded per the loading rules in `.claude/skills/governance/profile.md`.
1. .specify/memory/constitution.md, then the ADRs routed by specs/adr/adr-index.md for this work
   (the ALWAYS block + every signal block matching the story tags, the plan and the files in scope)
2. specs/domain/{module}.md of each bounded context the unit touches (from unit-brief.md /
   architecture.md; see specs/domain/bounded-contexts.md) — read-only here
3. specs/intents/{intent}/units/{unit}/knowledge-base.md (if exists)
4. specs/intents/{intent}/units/{unit}/02-design/contract-changes.md (if exists), then only the
   operations it lists in specs/openapi/{audience}.yaml / specs/asyncapi/{module}.yaml
5. specs/intents/{intent}/units/{unit}/02-design/architecture.md (if exists)
6. specs/intents/{intent}/units/{unit}/02-design/projects/{Project}.md (if exists)
7. specs/intents/{intent}/units/{unit}/02-design/database-design.md (if exists)
8. specs/intents/{intent}/units/{unit}/02-design/ui-model.md (if exists — Frontend/Mobile)
9. .specify/memory/projects/{Project}/tech-stack.md (`.claude/skills/governance/project-resolution.md`)
10. The project's coding rules: every `.claude/rules/{stack}/` folder mapped to `{Project}` (or its
    `{ProjectType}`) by `rules.stacks` in `.specify/profile.yaml`. These are the coding rules for this
    step; a missing folder is logged `{folder} not present — skipped`.

## Project context (tail — load LAST)
Emit at end of user-input block, after all cacheable context:
```
<project name="{Project}" code-root="{CodeRoot}" type="{ProjectType}">
  <plan-md>…03-plan/{Project}/plan.md…</plan-md>
  <tasks-md>…03-plan/{Project}/tasks.md…</tasks-md>
  <story>…UNIT_DIR/01-story/ story.md, requirement.md, acceptance-criteria.md…</story>
</project>
```

## Contract Codegen
Read `contracts.codegen` from `.specify/profile.yaml`.
- Set (a command): when contract-changes.md lists at least one operation this project produces or
  consumes, run the command from the repo root before generating the structure, and use its generated
  types/clients instead of hand-writing them. Log `contracts.codegen: ran "{command}" — exit {code}`.
  A non-zero exit: mark the dependent tasks `blocked` in progress.md with the output, and report.
  Never edit generated files by hand.
- `null`, absent or `none`: log `contracts.codegen: none — skipped; request/response types written by hand`.
- No contract change for this project: log `contracts.codegen: skipped — no contract change for {Project}`.

## Pre-generation Protocol
Before writing any code in an existing module:
1. Read the existing code in the target area. Match the established patterns.
2. Search the codebase before introducing a new abstraction (interface, utility, base class) — if an equivalent exists, use it.

## Execution Rules: Structural Scaffolding
This phase is a **pure mechanical translation** of the contracts, data models, and plan into code shape.
- **DO NOT** write business logic, implement rules, conditions, or transformations.
- **Inspect before creating**: where the target file or module already exists, read it first and extend
  additively — do not rewrite or alter existing functionality.
- **Task Tracking**: For every task where you successfully generate the structural scaffolding (stubs,
  classes, DTOs, etc.), set its status to `scaffolded` in `04-implementation/{Project}/progress.md`. This
  signals to `sk.implement_sub_codegen` that the boilerplate is ready for logic implementation.

### Generate the structure:
Read `03-plan/{Project}/tasks.md` to understand *what* needs to be built (build order + Files Affected),
and use the canonical operations listed in `contract-changes.md`, `database-design.md`, and
`ui-model.md` to know *how* it should be shaped. All
output goes inside `{CodeRoot}`.
1. Create directories and empty files.
2. Create the project's structural units (types, entities, enums, endpoints/routes, services, components)
   as stubbed boundaries.
3. Wire up dependencies using the project's composition mechanism (per the project's
   `.claude/rules/{stack}/` and the loaded packs).
4. Implement request/response types to match the canonical operations exactly (or use the types
   produced by Contract Codegen).
5. Create test files at the project's Test Layout (tech-stack.md) with empty, named test cases matching
   the acceptance criteria, in the project's test framework.

**Success Criteria:**
- The file structure exactly matches the plan and architecture, and follows the project's `.claude/rules/{stack}/`.
- Everything compiles / type-checks.
- Nothing has logic yet.

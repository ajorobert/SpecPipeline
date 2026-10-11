# sk.migrate
Database migration lifecycle — expand/contract pattern.
Role: backend | Level: unit

## Mode detection
- `sk.migrate --expand`   → [EXPAND] add-only changes (new columns, tables, indexes)
- `sk.migrate --contract` → [CONTRACT] remove old columns/tables after all consumers migrated
- `sk.migrate --rollback` → [ROLLBACK PLAN] generate rollback script for a named migration
- `sk.migrate` (no flag)  → prompt user to select mode
Declare mode at start of execution.

## Pre-flight
1. Run the unit pre-flight in `.claude/skills/governance/preflight.md`.
2. Verify `UNIT_DIR/02-design/database-design.md` exists.
   MISSING → STOP: run sk.design first (sk.design orchestrates architecture + data model + contracts)
3. Resolve the schema-owning project: the row(s) of the Impacted Projects table whose
   `.specify/memory/projects/{Project}/tech-stack.md` has a `## Migrations` section
   (`.claude/skills/governance/project-resolution.md`). More than one → ask which. Record `{Project}`,
   `{CodeRoot}` and, from that section: **Tool**, **Location** (the migration layout), **Rollback**
   (the rollback policy) and **Tests** (`required` or `none`). When Tests is `required`, the migration
   test location comes from the same file's `## Test Layout`.
   No `## Migrations` section in any impacted project → ask the user for the tool, location, rollback
   policy and test requirement, use them for this run, and advise recording them in that project's
   tech-stack.md → `## Migrations`. Never assume a default for any of the four.
4. List existing migration files at the Location under `{CodeRoot}`.
5. In [CONTRACT] mode: verify corresponding expand migration is present and deployed
   UNVERIFIED → warn user; require explicit confirmation before generating contract migration

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `implement`,
in-scope project = `{Project}`, signals = `migration, schema, db` + the database-design.md diff.

## Context loading
1. UNIT_DIR/02-design/database-design.md — canonical entity definitions
2. UNIT_DIR/02-design/architecture.md (if exists)
3. `.specify/memory/constitution.md` and the ADRs routed by `specs/adr/adr-index.md` for this work
   (loading rules: `.claude/skills/governance/profile.md`), plus the project's `.claude/rules/{stack}/`
   folders mapped by `rules.stacks` — the data and migration rules, if the project has any
4. Packs loaded in Step 0

## [EXPAND] steps
1. Identify new entities, columns, indexes, constraints from the database-design.md diff
2. Generate the migration at the Location, in the declared Tool's format and naming convention
   (when the tool has none, use `{timestamp}_{story-id}_{descriptive-name}`):
   - Content: add-only — no DROP, no ALTER with data loss risk
   - Include any guard the tool, ADRs or rules call for (for example an existence check)
3. Annotate each change with its database-design.md source entity
4. Rollback, per the declared Rollback policy:
   - a policy with reverse migrations (for example down migrations) → generate the reverse of each add
     in the tool's format;
   - a forward-only policy → generate no reverse script; the rollback is a compensating forward
     migration, described step by step in rollback-plan.md;
   - any other declared policy → follow it as written and record how in rollback-plan.md.
5. Write rollback-plan.md (see Output Artifacts)

## [CONTRACT] steps
1. Confirm all consumers have been migrated off deprecated columns/tables
   Ask: "Confirm all services consuming {deprecated columns} have been updated? (y/n)"
   On n → STOP: contract migration is unsafe until all consumers are migrated
2. Generate migration file: DROP deprecated objects
3. Include tombstone comment: `Expanded in migration {expand-migration-name}`
4. Rollback note: "Contract migrations cannot be auto-rolled back — restore from expand migration + data backup"
   (plus the steps the declared Rollback policy prescribes)

## [ROLLBACK PLAN] steps
1. Ask: which migration to target?
2. Read the target migration
3. Generate reverse operations in dependency order (FKs before tables, indexes before columns), in the
   form the declared Rollback policy allows (reverse migration, or compensating forward migration)
4. Annotate data-loss risk for each step (SAFE / DATA LOSS: {what is lost})
5. Write rollback-plan.md

## Migration test generation
Only when the declared **Tests** is `required`. When it is `none`, log
`SKIP — Migrations Tests: none ({Project})` and write no migration test.
Otherwise, after any migration file, generate a migration test at the project's Test Layout, in the
project's test framework:
- Test: migration applies cleanly from prior state
- Test: the declared rollback restores prior state (expand only; reverse migration or compensating migration)
- Test: re-applying has no effect, where the tool supports re-application

## Output Artifacts
{CodeRoot}/{Location}                         — the migration
{CodeRoot}/{Test Layout}                      — the migration test (Tests: required only)
specs/intents/{intent}/units/{unit}/rollback-plan.md

## Quality Bar
- Expand migrations: zero DROP or destructive ALTER statements
- Contract migrations: explicit consumer-migrated confirmation recorded
- Every migration has the rollback the declared policy requires, or a documented data-loss caveat
- When Tests is `required`: migration tests cover apply, rollback (expand) and re-application; when
  `none`: the skip is logged
- Rollback plan documents DATA LOSS risk per step
- Files written only at the declared (or user-confirmed) locations

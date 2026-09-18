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
3. Resolve the schema-owning project: the Backend row(s) of the Impacted Projects table that appear in
   `.specify/memory/skill-routing.md` → `## Migrations`. More than one → ask which. Record `{Project}`,
   `{CodeRoot}`, **Tool**, **Migration layout**, **Migration test layout**.
   No `## Migrations` row → ask the user for the tool and both layouts, use them for this run, and advise
   registering them in skill-routing.md.
4. List existing migration files at the Migration layout under `{CodeRoot}`.
5. In [CONTRACT] mode: verify corresponding expand migration is present and deployed
   UNVERIFIED → warn user; require explicit confirmation before generating contract migration

## Step 0: Capability Packs
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `implement`,
in-scope project = `{Project}`, signals = `migration, schema, db` + the database-design.md diff.

## Context loading
1. UNIT_DIR/02-design/database-design.md — canonical entity definitions
2. UNIT_DIR/02-design/architecture.md (if exists)
3. .specify/memory/standards/data-standards.md
4. Packs loaded in Step 0

## [EXPAND] steps
1. Identify new entities, columns, indexes, constraints from the database-design.md diff
2. Generate the migration at the Migration layout, in the registered Tool's format:
   - Name: {timestamp}_{story-id}_{descriptive-name}
   - Content: add-only — no DROP, no ALTER with data loss risk
   - Include: forward migration + idempotency guard (IF NOT EXISTS where applicable)
3. Annotate each change with its database-design.md source entity
4. Generate rollback script: reverse of each add (DROP the added objects)
5. Write rollback-plan.md (see Output Artifacts)

## [CONTRACT] steps
1. Confirm all consumers have been migrated off deprecated columns/tables
   Ask: "Confirm all services consuming {deprecated columns} have been updated? (y/n)"
   On n → STOP: contract migration is unsafe until all consumers are migrated
2. Generate migration file: DROP deprecated objects
3. Include tombstone comment: `Expanded in migration {expand-migration-name}`
4. Rollback note: "Contract migrations cannot be auto-rolled back — restore from expand migration + data backup"

## [ROLLBACK PLAN] steps
1. Ask: which migration to target?
2. Read the target migration
3. Generate reverse operations in dependency order (FKs before tables, indexes before columns)
4. Annotate data-loss risk for each step (SAFE / DATA LOSS: {what is lost})
5. Write rollback-plan.md

## Migration test generation
After any migration file, generate a migration test at the Migration test layout, in the project's test framework:
- Test: migration applies cleanly from prior state
- Test: rollback script restores prior state (expand only)
- Test: idempotency — applying twice has no effect

## Output Artifacts
{CodeRoot}/{Migration layout}                 — the migration
{CodeRoot}/{Migration test layout}            — the migration test
specs/intents/{intent}/units/{unit}/rollback-plan.md

## Quality Bar
- Expand migrations: zero DROP or destructive ALTER statements
- Contract migrations: explicit consumer-migrated confirmation recorded
- Every migration has a corresponding rollback script or documented data-loss caveat
- Migration tests cover apply, rollback (expand), and idempotency
- Rollback plan documents DATA LOSS risk per step
- Files written only at the registered (or user-confirmed) layouts

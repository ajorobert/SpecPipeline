---
name: sk.migrate
description: "Invoke when: database migration lifecycle — expand/contract, rollback plan, migration test. Role: backend. Reads: session.yaml, 02-design/database-design.md, 02-design/architecture.md, skill-routing.md (## Migrations, packs). Writes: migrations at the project's migration layout, rollback-plan.md."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .specify/memory/standards/data-standards.md
preconditions:
  - "file_exists: specs/intents/*/units/*/02-design/database-design.md"
---

Database migration lifecycle using expand/contract pattern.
Requires 02-design/database-design.md. Produces migration files, rollback plan, and migration tests at the
layout the project registers in `.specify/memory/skill-routing.md` → `## Migrations`.

Read and execute the full workflow in `prompt.md` in this directory.

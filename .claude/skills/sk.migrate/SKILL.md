---
name: sk.migrate
description: "Invoke when: database migration lifecycle — expand/contract, rollback plan, migration test. Role: backend. Reads: .specify/state/session.yaml, 02-design/database-design.md, 02-design/architecture.md, the schema-owning project's .specify/memory/projects/{Project}/tech-stack.md (## Migrations: tool, location, rollback policy, tests), specs/adr/adr-index.md → routed ADRs, .specify/memory/constitution.md, .claude/skills/README.md (packs). Writes: migrations at the declared location, migration tests (when Tests: required), rollback-plan.md."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .specify/memory/constitution.md
  - specs/adr/adr-index.md
preconditions:
  - "file_exists: specs/intents/*/units/*/02-design/database-design.md"
---

Database migration lifecycle using the expand/contract pattern.
Requires 02-design/database-design.md. Produces migration files, the rollback plan, and — when the
project requires them — migration tests, following the tool, location, rollback policy and test
requirement declared in the schema-owning project's `.specify/memory/projects/{Project}/tech-stack.md`
→ `## Migrations`.

Read and execute the full workflow in `prompt.md` in this directory.

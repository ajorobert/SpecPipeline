---
name: sk.plan_sub_analyze
description: "INTERNAL sub-skill of sk.plan. Never invoke directly or in response to a user request — only when sk.plan's prompt.md directs it. Runs a cross-artifact consistency check for the active unit. Role: lead. READ-ONLY — no files written. Reads: 02-design/architecture.md, 02-design/impact-analysis.md, 01-story/, 02-design/contract-changes.md, the branch diff of the canonical specs/openapi|asyncapi files it lists, 02-design/database-design.md, 03-plan/{Project}/plan.md, specs/domain/bounded-contexts.md + the relevant specs/domain/{module}.md, specs/adr/adr-index.md → routed ADRs, .specify/memory/constitution.md."
subagent_type: SpecKit Lead Agent
inject_files:
  - .specify/memory/constitution.md
  - specs/adr/adr-index.md
  - specs/domain/bounded-contexts.md
---

Cross-artifact consistency check. READ-ONLY — no files written.
Runs as the final phase of sk.plan. CRITICAL findings block implementation.

Internal sub-skill — invoked by sk.plan orchestrator. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.

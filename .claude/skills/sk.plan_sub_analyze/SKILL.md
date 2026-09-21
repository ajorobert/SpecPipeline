---
name: sk.plan_sub_analyze
description: "INTERNAL sub-skill of sk.plan. Never invoke directly or in response to a user request — only when sk.plan's prompt.md directs it. Runs a cross-artifact consistency check for the active unit. Role: lead. READ-ONLY — no files written. Reads: 02-design/architecture.md, 02-design/impact-analysis.md, all stories, 02-design/contracts/api-spec.json, 02-design/database-design.md, 03-plan/{Project}/plan.md, service-registry.md, domain-model.md, architecture-decisions.md."
subagent_type: SpecKit Lead Agent
inject_files:
  - .specify/memory/architecture-decisions.md
  - .specify/memory/domain-model.md
  - .specify/memory/service-registry.md
---

Cross-artifact consistency check. READ-ONLY — no files written.
Runs as the final phase of sk.plan. CRITICAL findings block implementation.

Internal sub-skill — invoked by sk.plan orchestrator. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.

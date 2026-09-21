---
name: sk.design_sub_contracts
description: "INTERNAL sub-skill of sk.design. Never invoke directly or in response to a user request — only when sk.design's prompt.md directs it. Defines API contracts, OpenAPI specs, and provider/consumer test plans for a unit. Role: architect. Reads: 02-design/architecture.md, 02-design/database-design.md, unit-brief.md, service-registry.md, api-standards.md, skill-routing.md (design packs, surfaces). Writes: 02-design/contracts/ (api-spec.json, test-plan.md, README.md), 02-design/api-contract.md, 02-design/projects/{BackendProject}.md, provider tests."
subagent_type: SpecKit Architect Agent
inject_files:
  - .specify/memory/standards/tech-stack.md
  - .specify/memory/standards/api-standards.md
  - .specify/memory/service-registry.md
---

Defines API contracts and generates provider tests for a unit.
Requires 02-design/architecture.md and 02-design/database-design.md to exist.

Internal sub-skill — invoked by sk.design. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.

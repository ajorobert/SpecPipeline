---
name: sk.impact
description: "Invoke when: assessing blast radius of proposed work before starting, determining risk level and checkpoint mode. Role: architect. Reads: specs/knowledge-base.md, .specify/memory/projects/index.md, specs/domain/bounded-contexts.md + the relevant specs/domain/{module}.md, specs/adr/adr-index.md, specs/openapi/, specs/asyncapi/. Writes: impact-{date}-{NNN}.md."
subagent_type: SpecKit Architect Agent
inject_files:
  - .claude/skills/governance/checkpoint-rules.md
  - .specify/memory/projects/index.md
  - specs/domain/bounded-contexts.md
  - specs/adr/adr-index.md
---

Assesses blast radius of proposed work before starting. Run before sk.story_sub_specify for high-risk changes.

Read and execute the full workflow in `prompt.md` in this directory.

---
name: sk.impact
description: "Invoke when: assessing blast radius of proposed work before starting, determining risk level and checkpoint mode. Role: architect. Reads: system-context.md, service-registry.md, domain-model.md. Writes: impact-{date}-{NNN}.md."
subagent_type: SpecKit Architect Agent
inject_files:
  - .claude/skills/governance/checkpoint-rules.md
  - .specify/memory/system-context.md
  - .specify/memory/domain-model.md
  - .specify/memory/service-registry.md
---

Assesses blast radius of proposed work before starting. Run before sk.story_sub_specify for high-risk changes.

Read and execute the full workflow in `prompt.md` in this directory.

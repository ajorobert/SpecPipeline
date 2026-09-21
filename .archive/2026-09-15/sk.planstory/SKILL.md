---
name: sk.planstory
description: "Internal sub-skill of sk.plan. Invoke via sk.plan, not directly. Creates a technical implementation plan for a single story. Role: lead."
subagent_type: SpecKit Lead Agent
inject_files:
  - .specify/memory/standards/tech-stack.md
---

Creates technical implementation plan for a story.
Internal sub-skill — invoked by sk.plan orchestrator. Do not invoke directly.

Read and execute the full workflow in `prompt.md` in this directory.

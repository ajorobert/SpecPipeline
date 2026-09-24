---
name: sk.story_sub_specify
description: "INTERNAL sub-skill of sk.story. Never invoke directly or in response to a user request — only when sk.story's prompt.md directs it. Captures user intent, decomposes to units, and creates feature stories or bug reports. Role: po. Reads: .specify/state/session.yaml, specs/knowledge-base.md, .specify/memory/projects/index.md, specs/adr/adr-index.md, specs/domain/bounded-contexts.md, .claude/skills/README.md ## Registry (tag vocabulary). Writes: intent.md, unit-brief.md, 01-story/{story.md, requirement.md, acceptance-criteria.md}, .specify/state/session.yaml (focus)."
subagent_type: SpecKit PO Agent
inject_files:
  - .specify/memory/projects/index.md
  - specs/adr/adr-index.md
  - specs/domain/bounded-contexts.md
---

Captures intent, decomposes to units and stories.
Mode: `sk.story_sub_specify --bug` for bug reports, `sk.story_sub_specify` for features.

Read and execute the full workflow in `prompt.md` in this directory.

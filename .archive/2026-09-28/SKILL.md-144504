---
name: sk.story_sub_architect-probe
description: "INTERNAL sub-skill of sk.story. Never invoke directly or in response to a user request — only when sk.story's prompt.md directs it. Extracts and clarifies non-functional requirements, security boundaries, and technical constraints from the PO. Role: architect. Reads: .specify/state/session.yaml, 01-story/, .specify/memory/projects/index.md (+ projects/{Project}/tech-stack.md), specs/adr/adr-index.md → routed ADRs, .specify/memory/constitution.md, specs/domain/bounded-contexts.md. Writes: 01-story/requirement.md, unit-brief.md (Impacted Projects: Project · Type · Code Root · Role)."
subagent_type: SpecKit Architect Agent
inject_files:
  - .specify/memory/projects/index.md
  - specs/adr/adr-index.md
  - .specify/memory/constitution.md
  - specs/domain/bounded-contexts.md
---

Resolves technical ambiguities (NFRs, scale, security, observability) in the active story using a structured loop.
Requires active_story_id in .specify/state/session.yaml.

Read and execute the full workflow in `prompt.md` in this directory.

---
name: sk.architect-probe
description: "Invoke when: extracting and clarifying non-functional requirements, security boundaries, and technical constraints from the PO. Role: architect. Reads: session.yaml, architecture-decisions.md, projects/index.md, 01-story/. Writes: 01-story/requirement.md, unit-brief.md (impacted projects)."
subagent_type: SpecKit Architect Agent
inject_files:
  - .specify/memory/architecture-decisions.md
  - .specify/memory/projects/index.md
---

Resolves technical ambiguities (NFRs, scale, security, observability) in the active story using a structured loop.
Requires active_story_id in session.yaml.

Read and execute the full workflow in `prompt.md` in this directory.

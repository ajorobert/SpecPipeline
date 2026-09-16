---
name: sk.review
description: "Invoke when: performing spec-aware code review after implementation. Role: backend or frontend. Reads: 01-story/story.md, 02-design/architecture.md, 02-design/contracts/api-spec.json, 03-plan/{Project}/plan.md, architecture-decisions.md, coding-standards.md, skill-routing.md (review packs). Writes: 04-implementation/{Project}/review-{story-id}.md."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .specify/memory/standards/coding-standards.md
  - .specify/memory/standards/observability-standards.md
  - .specify/memory/architecture-decisions.md
---

Spec-aware code review: validates against bounded context, contracts, and ADRs.
Reviews one impacted project at a time. Project type determines agent: Backend → SpecKit Backend Engineer Agent, Frontend/Mobile → SpecKit Frontend Engineer Agent.

Read and execute the full workflow in `prompt.md` in this directory.

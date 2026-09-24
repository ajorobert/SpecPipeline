---
name: sk.review
description: "Invoke when: performing spec-aware code review after implementation. Role: backend or frontend. Reviews one impacted project's branch diff against the project's own constitution, ADRs, .claude/rules/{stack}/ and the unit's story, design and plan. Reads: 01-story/story.md, 02-design/architecture.md, 02-design/contract-changes.md + the canonical specs/openapi|asyncapi diff, 03-plan/{Project}/plan.md, .specify/memory/constitution.md, specs/adr/adr-index.md → routed ADRs, the project's .claude/rules/{stack}/, .specify/profile.yaml (contracts.compat_rules, rules.stacks, vcs.base_branch), .claude/skills/README.md (review packs). Writes: 04-implementation/{Project}/review-{story-id}.md, knowledge-base.md (Implementation Pitfalls)."
subagent_type: SpecKit Backend Engineer Agent
inject_files:
  - .specify/memory/constitution.md
  - specs/adr/adr-index.md
  - .specify/memory/projects/index.md
---

Spec-aware code review: judges the diff against the project's constitution, the ADRs routed by
`specs/adr/adr-index.md`, the project's `.claude/rules/{stack}/`, and the unit's story, design and plan.
It is the framework's own review; the rules it applies are always the project's, never the framework's.
Reviews one impacted project at a time. Project type determines agent: Backend → SpecKit Backend Engineer Agent, Frontend/Mobile → SpecKit Frontend Engineer Agent.

Read and execute the full workflow in `prompt.md` in this directory.

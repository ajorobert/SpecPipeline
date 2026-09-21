---
name: sk.story
description: "Invoke when: driving the complete story capture and clarification pipeline. Role: po (orchestrator). Invokes: sk.story_sub_specify → loops sk.story_sub_clarify (business) → loops sk.story_sub_architect-probe (technical) → validation gate → finalize single story folder (story.md, requirement.md, acceptance-criteria.md, optional jira.md)."
subagent_type: SpecKit PO Agent
inject_files:
  - .specify/memory/system-context.md
  - .specify/memory/architecture-decisions.md
  - .specify/memory/domain-model.md
  - .specify/memory/projects/index.md
rubric:
  name: story-completeness
  checks:
    - every acceptance criterion is independently testable
    - every acceptance criterion uses Given/When/Then or equivalent observable form
    - user story follows "As a {role} I want {action} so that {benefit}"
    - out-of-scope list is present and non-empty
    - minimum 3 acceptance criteria
    - no undefined external dependencies
---

Orchestrator skill — Full Story Capture Pipeline.
Invokes sk.story_sub_specify -> loops sk.story_sub_clarify (business) -> loops sk.story_sub_architect-probe (technical) -> validates completeness -> finalizes a single story folder (story.md, requirement.md, acceptance-criteria.md, optional jira.md). The story is NOT split per project; impacted projects are recorded in unit-brief.md.
This is the primary way Product Owners should capture and refine stories.

Read and execute the full workflow in `prompt.md` in this directory.

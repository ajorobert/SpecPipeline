---
name: sk.verify
description: "Invoke when: running the final PASS/FAIL quality gate before sk.ship. Role: architect. Reads: 01-story/story.md, all unit phase artifacts (02-design … 07-security-audit), architecture-decisions.md, all standards files, governance quality-gates.md, skill-routing.md. Writes: story status (if PASS)."
subagent_type: SpecKit Architect Agent
inject_files:
  - .claude/skills/governance/quality-gates.md
  - .specify/memory/standards/tech-stack.md
  - .specify/memory/standards/coding-standards.md
  - .specify/memory/standards/api-standards.md
  - .specify/memory/standards/data-standards.md
  - .specify/memory/standards/observability-standards.md
  - .specify/memory/architecture-decisions.md
---

PASS/FAIL quality gate for the active story. Run after sk.test passes, before sk.ship.
Not a mid-implementation check. If you need to verify spec consistency before writing code, use sk.plan --analyze-only.

Read and execute the full workflow in `prompt.md` in this directory.

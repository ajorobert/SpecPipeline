---
name: sk.verify
description: "Invoke when: running the final PASS/FAIL quality gate before sk.ship. Role: architect. Reads: 01-story/story.md, all unit phase artifacts (02-design … 07-security-audit, promotion.md), .specify/profile.yaml (contracts.verify, knowledge.adr.guard), .specify/memory/constitution.md, specs/adr/adr-index.md → routed ADRs, each impacted project's tech-stack.md and .claude/rules/{stack}/, governance quality-gates.md, .claude/skills/README.md (review packs). Runs: check-adr-index.sh, contracts.verify. Writes: nothing — status.current and verify-status come from the Stop hook via SK_RESULT."
subagent_type: SpecKit Architect Agent
inject_files:
  - .claude/skills/governance/quality-gates.md
  - .specify/memory/constitution.md
  - specs/adr/adr-index.md
  - .specify/memory/projects/index.md
---

PASS/FAIL quality gate for the active story. Run after sk.test passes, before sk.ship.
Not a mid-implementation check. If you need to verify spec consistency before writing code, use sk.plan --analyze-only.

Read and execute the full workflow in `prompt.md` in this directory.

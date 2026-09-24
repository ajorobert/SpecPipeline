---
name: sk.adr
description: "Invoke when: creating an Architecture Decision Record for a cross-module or significant unit-level decision, or superseding one. Role: architect. Reads: .specify/state/session.yaml, .specify/profile.yaml (knowledge.adr.*), specs/adr/adr-index.md → routed ADRs, .specify/memory/constitution.md, the exemplar ADR when set. Runs: create-adr.sh, check-adr-index.sh. Writes: specs/adr/NNNN-kebab-title.md, specs/adr/adr-index.md (routed in its matching blocks), the superseded ADR's Status, the right-tier knowledge base (essence only); .claude/rules/{stack}/ only when the user accepts the offer."
subagent_type: SpecKit Architect Agent
inject_files:
  - specs/adr/adr-index.md
  - .specify/memory/constitution.md
---

Creates an Architecture Decision Record in `specs/adr/` and routes it from `specs/adr/adr-index.md` by the index's own rules.
Requires at least 2 rejected alternatives and both positive and negative consequences.

Read and execute the full workflow in `prompt.md` in this directory.
